#!/usr/bin/env bash
# Corrige os nomes versionados esperados pelo menu de boot Debian e inclui
# a fonte GRUB usada pelo carregador UEFI. Mantém o catálogo El Torito/híbrido.
set -euo pipefail
ISO="${1:?uso: $0 arquivo.iso}"
ROOT="${2:-binary}"
[[ -s "$ISO" ]] || { echo "[FALHA] ISO ausente: $ISO" >&2; exit 2; }
[[ -s "$ROOT/live/vmlinuz" && -s "$ROOT/live/initrd.img" ]] || {
  echo "[FALHA] live-build não forneceu binary/live/vmlinuz e initrd.img" >&2; exit 2;
}
command -v xorriso >/dev/null
command -v file >/dev/null

KERNEL_INFO="$(file "$ROOT/live/vmlinuz")"
KERNEL_VERSION="$(printf '%s\n' "$KERNEL_INFO" | sed -n 's/.*version \([^ ]*\) (.*/\1/p' | head -n1)"
if [[ -z "$KERNEL_VERSION" ]]; then
  echo "[FALHA] não foi possível identificar a versão do kernel: $KERNEL_INFO" >&2
  exit 3
fi
echo "[INFO] Kernel detectado: $KERNEL_VERSION"

FONT="$(find /usr/share/grub /usr/lib/grub -type f -name unicode.pf2 -print -quit 2>/dev/null || true)"
[[ -s "$FONT" ]] || { echo "[FALHA] fonte unicode.pf2 não encontrada no ambiente de build" >&2; exit 4; }

WORK="$(mktemp -d)"
TMP_ISO="${ISO%.iso}.repaired.iso"
cleanup(){ rm -rf "$WORK"; rm -f "$TMP_ISO"; }
trap cleanup EXIT

mkdir -p "$WORK/live" "$WORK/boot/grub/fonts"
cp "$ROOT/live/vmlinuz" "$WORK/live/vmlinuz-$KERNEL_VERSION"
cp "$ROOT/live/initrd.img" "$WORK/live/initrd.img-$KERNEL_VERSION"
cp "$FONT" "$WORK/boot/grub/fonts/unicode.pf2"

xorriso -indev "$ISO" -outdev "$TMP_ISO" \
  -boot_image any replay \
  -map "$WORK/live/vmlinuz-$KERNEL_VERSION" "/live/vmlinuz-$KERNEL_VERSION" \
  -map "$WORK/live/initrd.img-$KERNEL_VERSION" "/live/initrd.img-$KERNEL_VERSION" \
  -map "$WORK/boot/grub/fonts/unicode.pf2" "/boot/grub/fonts/unicode.pf2" \
  -commit

[[ -s "$TMP_ISO" ]] || { echo "[FALHA] xorriso não criou a ISO reparada" >&2; exit 5; }
mv -f "$TMP_ISO" "$ISO"

for target in "/live/vmlinuz-$KERNEL_VERSION" "/live/initrd.img-$KERNEL_VERSION" "/boot/grub/fonts/unicode.pf2"; do
  verify="$WORK/verify"
  rm -f "$verify"
  xorriso -osirrox on -indev "$ISO" -extract "$target" "$verify" >/dev/null 2>&1
  [[ -s "$verify" ]] || { echo "[FALHA] arquivo ausente após reparo: $target" >&2; exit 6; }
  echo "[OK] ISO contém $target ($(stat -c %s "$verify") bytes)"
done
echo "[OK] aliases versionados do kernel/initrd e fonte GRUB incluídos."
