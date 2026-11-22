#!/usr/bin/env bash
# Validação estrutural da ISO NOVA GAMER OS.
# Não substitui o boot em hardware real nem a instalação em VM.
set -euo pipefail
ISO="${1:?uso: $0 arquivo.iso}"
FAIL=0
ok(){ echo "[OK]   $*"; }
bad(){ echo "[FALHA] $*" >&2; FAIL=1; }
extract_iso(){
  local source="$1" destination="$2"
  rm -f "$destination"
  xorriso -osirrox on -indev "$ISO" -extract "$source" "$destination" >/dev/null 2>&1
}

[[ -s "$ISO" ]] || { echo "[FALHA] ISO ausente ou vazia: $ISO" >&2; exit 1; }
ok "ISO existe ($(stat -c %s "$ISO") bytes)"
file "$ISO"
sha256sum "$ISO"

REPORT="$(xorriso -indev "$ISO" -report_el_torito plain -report_system_area plain 2>&1)"
printf '%s\n' "$REPORT" | sed -n '1,60p'
if grep -qi 'BIOS' <<<"$REPORT"; then ok "entrada El Torito BIOS"; else bad "sem entrada El Torito BIOS"; fi
if grep -qi 'UEFI' <<<"$REPORT"; then ok "entrada El Torito UEFI"; else bad "sem entrada El Torito UEFI"; fi
if grep -Eqi 'GPT|MBR' <<<"$REPORT"; then ok "ISO híbrida (GPT/MBR)"; else bad "sem estrutura híbrida GPT/MBR"; fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
for path in /live/filesystem.squashfs /live/vmlinuz /live/initrd.img \
            /boot/grub/fonts/unicode.pf2; do
  dest="$WORK/$(basename "$path")"
  if extract_iso "$path" "$dest" && [[ -s "$dest" ]]; then
    ok "$path extraído e não vazio"
  else
    bad "$path ausente ou ilegível"
  fi
done

KERNEL="$WORK/vmlinuz"
INITRD="$WORK/initrd.img"
if [[ -s "$KERNEL" ]]; then
  file "$KERNEL"
  if python3 - "$KERNEL" <<'PY'
import pathlib, sys
data = pathlib.Path(sys.argv[1]).read_bytes()
if len(data) < 0x208:
    raise SystemExit("kernel pequeno demais para setup header x86")
if data[0x202:0x206] != b"HdrS":
    raise SystemExit("assinatura HdrS ausente")
if data[0x1fe:0x200] != b"\x55\xaa":
    raise SystemExit("boot flag 0xAA55 ausente")
print(f"[OK] kernel x86 válido: {len(data)} bytes; HdrS e boot flag encontrados")
PY
  then ok "cabeçalho de kernel Linux x86 válido"; else bad "cabeçalho do kernel inválido"; fi
fi
if [[ -s "$INITRD" ]]; then
  if (( $(stat -c %s "$INITRD") > 102400 )); then ok "initrd tem tamanho plausível"; else bad "initrd muito pequeno"; fi
fi

KERNEL_INFO="$(file "$KERNEL" 2>/dev/null || true)"
KERNEL_VERSION="$(printf '%s\n' "$KERNEL_INFO" | sed -n 's/.*version \([^ ]*\) (.*/\1/p' | head -n1)"
if [[ -n "$KERNEL_VERSION" ]]; then
  for path in "/live/vmlinuz-$KERNEL_VERSION" "/live/initrd.img-$KERNEL_VERSION"; do
    dest="$WORK/versioned-$(basename "$path")"
    if extract_iso "$path" "$dest" && [[ -s "$dest" ]]; then ok "$path presente"; else bad "$path ausente"; fi
  done
else
  bad "não foi possível identificar versão do kernel para conferir aliases do GRUB"
fi

LIST="$(xorriso -indev "$ISO" -find / -type f 2>/dev/null || true)"
# Com "--debian-installer live" o live-build coloca o instalador em /d-i/; nos demais modos, em /install/.
if grep -Eqi "'/(install|d-i)/" <<<"$LIST"; then ok "arquivos do Debian Installer presentes (/install ou /d-i)"; else bad "arquivos do Debian Installer (/install ou /d-i) ausentes"; fi

# ---- Menus do bootloader: mostra a configuracao e confere se kernel/initrd citados existem na ISO ----
BL="$WORK/bootloader"
mkdir -p "$BL"
for d in /boot/grub /isolinux /syslinux; do
  # Keep these extracted directories INSIDE $BL. The previous missing slash
  # sent them to sibling paths, so find "$BL" never inspected the real GRUB menu.
  dest="$BL/$(printf '%s' "$d" | tr / _)"
  mkdir -p "$(dirname "$dest")"
  xorriso -osirrox on -indev "$ISO" -extract "$d" "$dest" >/dev/null 2>&1 || true
done
# A configuração UEFI pode estar dentro da imagem FAT EFI, não no diretório ISO.
EFIIMG="$WORK/efi.img"
if extract_iso /boot/grub/efi.img "$EFIIMG" && [[ -s "$EFIIMG" ]]; then
  mkdir -p "$BL/efi-image"
  # EFI FAT image contains only a small GRUB hand-off config and EFI binaries.
  # Copying its files is diagnostic; the actual Live menu is on the ISO filesystem.
  mdir -i "$EFIIMG" ::/boot/grub > "$BL/efi-directory.txt" 2>&1 || true
  mcopy -s -i "$EFIIMG" :: "$BL/efi-image/" >/dev/null 2>&1 || true
else
  bad "imagem FAT /boot/grub/efi.img ausente ou ilegível"
fi
chmod -R u+rwX "$BL" 2>/dev/null || true

EFI_CFG="$BL/efi-image/boot/grub/grub.cfg"
if [[ -s "$EFI_CFG" ]]; then
  if grep -Fq -- '--file /live/vmlinuz' "$EFI_CFG"; then
    ok "GRUB EFI procura a mídia que contém /live/vmlinuz"
  else
    bad "GRUB EFI não procura /live/vmlinuz na mídia Live"
  fi
  if grep -Eq 'configfile[[:space:]].*/boot/grub/grub\\.cfg' "$EFI_CFG"; then
    ok "GRUB EFI encaminha para /boot/grub/grub.cfg da mídia"
  else
    bad "GRUB EFI não encaminha para o menu GRUB principal da mídia"
  fi
else
  bad "grub.cfg de encaminhamento não foi extraído da imagem EFI"
fi

ISO_GRUB_CFG="$BL/boot_grub/grub.cfg"
if [[ -s "$ISO_GRUB_CFG" ]]; then
  ok "menu GRUB principal /boot/grub/grub.cfg extraído da ISO"
else
  bad "menu GRUB principal /boot/grub/grub.cfg ausente ou ilegível na ISO"
fi
echo "---- configuracao dos menus de boot (ISO + EFI) ----"
find "$BL" -type f \( -name '*.cfg' \) | sort | while read -r cfg; do
  echo "## ${cfg#"$BL"/}"
  grep -nEi '^[[:space:]]*(set[[:space:]]+(default|timeout)|timeout|default|menuentry|label|linux|linuxefi|kernel|initrd|append)' "$cfg" || true
done
echo "----------------------------------------------------"
BOOTREFS="$(find "$BL" -type f -name '*.cfg' -exec cat {} + 2>/dev/null \
  | grep -oE '(^|[[:space:]=])/(live|d-i|install)/[A-Za-z0-9._/+-]+' | sed -E 's/^[[:space:]=]+//' | sort -u || true)"
if [[ -z "$BOOTREFS" ]]; then
  bad "nenhum caminho de kernel/initrd encontrado nos menus de boot (grub.cfg/isolinux)"
else
  while read -r ref; do
    [[ -n "$ref" ]] || continue
    if grep -Fq "'$ref'" <<<"$LIST"; then ok "menu de boot referencia $ref (existe na ISO)"; else bad "menu de boot referencia $ref, que NAO existe na ISO"; fi
  done <<<"$BOOTREFS"
fi

SQ="$WORK/filesystem.squashfs"
if [[ -s "$SQ" ]]; then
  command -v unsquashfs >/dev/null || { bad "unsquashfs não instalado"; exit 1; }
  command -v mcopy >/dev/null || { bad "mtools não instalado (necessário para inspecionar a partição EFI)"; exit 1; }
  SQROOT="$WORK/squashfs-root"
  mkdir -p "$SQROOT"
  if unsquashfs -d "$SQROOT" "$SQ" >/dev/null; then
    for f in \
      usr/share/nova-ui/index.html \
      usr/local/bin/nova-ui \
      usr/local/bin/nova-game-mode \
      usr/local/bin/nova-status \
      usr/local/sbin/nova-qemu-ready \
      etc/systemd/system/nova-qemu-ready.service \
      usr/share/applications/nova-control-center.desktop \
      etc/skel/Desktop/NOVA-Control-Center.desktop; do
      if [[ -s "$SQROOT/$f" ]]; then ok "squashfs contém /$f"; else bad "squashfs NÃO contém /$f"; fi
    done
    for f in usr/local/bin/nova-ui usr/local/bin/nova-game-mode usr/local/bin/nova-status usr/local/sbin/nova-qemu-ready; do
      if [[ -x "$SQROOT/$f" ]]; then ok "/$f executável"; else bad "/$f sem bit de execução"; fi
    done
    if [[ -e "$SQROOT/etc/systemd/system/graphical.target.wants/nova-qemu-ready.service" ]]; then
      ok "serviço de confirmação gráfica habilitado"
    else
      bad "serviço de confirmação gráfica não habilitado"
    fi
  else
    bad "não foi possível extrair filesystem.squashfs"
  fi
else
  bad "filesystem.squashfs não foi extraído"
fi

if (( FAIL != 0 )); then
  echo "[FALHA] validação da ISO reprovada."
  exit 1
fi
echo "[OK] validação estrutural concluída."
