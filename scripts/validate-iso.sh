#!/usr/bin/env bash
# Validação estrutural e de integridade dos componentes de boot da ISO.
# Não substitui o boot em QEMU nem a instalação em hardware real.
# Uso: scripts/validate-iso.sh arquivo.iso
set -uo pipefail
ISO="${1:?uso: $0 arquivo.iso}"
FAIL=0
ok(){ echo "[OK]   $*"; }
bad(){ echo "[FALHA] $*"; FAIL=1; }

[[ -s "$ISO" ]] && ok "ISO existe ($(stat -c %s "$ISO") bytes)" || { bad "ISO ausente ou vazia"; exit 1; }
file "$ISO"
sha256sum "$ISO"

REPORT="$(xorriso -indev "$ISO" -report_el_torito plain -report_system_area plain 2>&1)"
echo "$REPORT" | sed -n '1,60p'
echo "$REPORT" | grep -qi 'BIOS' && ok "entrada El Torito BIOS" || bad "sem entrada El Torito BIOS"
echo "$REPORT" | grep -qi 'UEFI' && ok "entrada El Torito UEFI" || bad "sem entrada El Torito UEFI"
echo "$REPORT" | grep -Eqi 'GPT|MBR' && ok "ISO híbrida (GPT/MBR)" || bad "sem estrutura híbrida GPT/MBR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
extract_iso() {
  local source="$1" destination="$2"
  xorriso -osirrox on -indev "$ISO" -extract "$source" "$destination" >/dev/null 2>&1
}

for f in /live/filesystem.squashfs /live/vmlinuz /live/initrd.img; do
  if extract_iso "$f" "$WORK/$(basename "$f")" && [[ -s "$WORK/$(basename "$f")" ]]; then
    ok "$f extraído e não vazio"
  else
    bad "$f ausente ou ilegível"
  fi
done

KERNEL="$WORK/vmlinuz"
INITRD="$WORK/initrd.img"
if [[ -s "$KERNEL" ]]; then
  file "$KERNEL"
  # Protocolo de boot x86: assinatura HdrS no setup header e boot flag 0xAA55.
  python3 - "$KERNEL" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
data = p.read_bytes()
if len(data) < 0x208:
    raise SystemExit("kernel pequeno demais para conter o setup header x86")
if data[0x202:0x206] != b"HdrS":
    raise SystemExit("assinatura HdrS ausente no kernel (imagem não reconhecida como Linux x86 boot protocol)")
if data[0x1fe:0x200] != b"\x55\xaa":
    raise SystemExit("boot flag 0xAA55 ausente no kernel")
print(f"[OK] kernel x86 válido: {len(data)} bytes; HdrS e boot flag encontrados")
PY
  [[ $? -eq 0 ]] && ok "cabeçalho de kernel Linux x86 válido" || bad "cabeçalho do kernel inválido"
fi
if [[ -s "$INITRD" ]]; then
  [[ $(stat -c %s "$INITRD") -gt 102400 ]] && ok "initrd tem tamanho plausível" || bad "initrd muito pequeno"
fi

LIST="$(xorriso -indev "$ISO" -find / -type f 2>/dev/null)"
echo "$LIST" | grep -qi '/install/' && ok "arquivos do Debian Installer presentes" || bad "arquivos do Debian Installer (/install) ausentes"
echo "$LIST" | grep -qi 'grub.cfg' && ok "configuração GRUB presente" || bad "grub.cfg ausente"

SQ="$WORK/filesystem.squashfs"
if [[ -s "$SQ" ]]; then
  command -v unsquashfs >/dev/null || { bad "unsquashfs não instalado"; exit 1; }
  SQLIST="$(unsquashfs -l "$SQ" 2>/dev/null)"
  for f in \
    usr/share/nova-ui/index.html \
    usr/local/bin/nova-ui \
    usr/local/bin/nova-game-mode \
    usr/local/bin/nova-status \
    usr/local/sbin/nova-qemu-ready \
    etc/systemd/system/nova-qemu-ready.service \
    usr/share/applications/nova-control-center.desktop \
    etc/skel/Desktop/NOVA-Control-Center.desktop \
    usr/bin/chromium \
    usr/bin/sensors \
    usr/bin/intel_gpu_top \
    usr/bin/gamemoderun \
    usr/sbin/debian-installer-launcher; do
    echo "$SQLIST" | grep -q "squashfs-root/$f\$" && ok "squashfs contém /$f" || bad "squashfs NÃO contém /$f"
  done
  unsquashfs -ll "$SQ" 2>/dev/null | grep -E 'usr/local/(bin/nova-(ui|game-mode|status)|sbin/nova-qemu-ready)$' | grep -q '^-rwxr-xr-x' \
    && ok "scripts NOVA executáveis" || bad "scripts NOVA sem bit de execução"
else
  bad "não foi possível extrair filesystem.squashfs"
fi

exit "$FAIL"
