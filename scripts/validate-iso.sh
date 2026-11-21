#!/usr/bin/env bash
# Validação ESTRUTURAL da ISO (não substitui teste em hardware real).
# Uso: ./scripts/validate-iso.sh build/NOVA-GAMER-OS-amd64.iso
set -uo pipefail
ISO="${1:?uso: $0 arquivo.iso}"
fail=0
ok(){ echo "[OK]   $*"; }
bad(){ echo "[FALHA] $*"; fail=1; }

[[ -s "$ISO" ]] && ok "arquivo existe e não está vazio ($(stat -c %s "$ISO") bytes)" || { bad "ISO ausente ou vazia"; exit 1; }
file "$ISO"
sha256sum "$ISO"

REPORT="$(xorriso -indev "$ISO" -report_el_torito plain -report_system_area plain 2>&1)"
echo "$REPORT" | sed -n '1,40p'
echo "$REPORT" | grep -qi 'BIOS'  && ok "entrada de boot El Torito BIOS" || bad "sem boot BIOS El Torito"
echo "$REPORT" | grep -qi 'UEFI'  && ok "entrada de boot El Torito UEFI" || bad "sem boot UEFI El Torito"
echo "$REPORT" | grep -qi 'GPT\|MBR' && ok "ISO híbrida (tabela de partição para pendrive)" || bad "sem MBR/GPT híbrido"

LIST="$(xorriso -indev "$ISO" -find / -type f 2>/dev/null)"
for f in /live/filesystem.squashfs /live/vmlinuz /live/initrd.img; do
  echo "$LIST" | grep -q "'$f\|'${f}'" && ok "$f presente" || { echo "$LIST" | grep -q "$(basename $f)" && ok "$(basename $f) presente" || bad "$f ausente"; }
done
echo "$LIST" | grep -qi '/install/' && ok "arquivos do Debian Installer (/install) presentes" || bad "Debian Installer ausente na mídia"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
SQ="$(xorriso -indev "$ISO" -find /live -name 'filesystem.squashfs' 2>/dev/null | head -1 | tr -d "'")"
xorriso -osirrox on -indev "$ISO" -extract "${SQ:-/live/filesystem.squashfs}" "$WORK/fs.squashfs" >/dev/null 2>&1
if [[ -s "$WORK/fs.squashfs" ]]; then
  SQLIST="$(unsquashfs -l "$WORK/fs.squashfs" 2>/dev/null)"
  for f in usr/share/nova-ui/index.html usr/local/bin/nova-ui usr/local/bin/nova-game-mode usr/local/bin/nova-status \
           usr/share/applications/nova-control-center.desktop etc/skel/Desktop/NOVA-Control-Center.desktop \
           usr/bin/chromium usr/bin/sensors usr/bin/intel_gpu_top usr/bin/gamemoderun; do
    echo "$SQLIST" | grep -q "squashfs-root/$f\$" && ok "squashfs contém /$f" || bad "squashfs NÃO contém /$f"
  done
  unsquashfs -ll "$WORK/fs.squashfs" 2>/dev/null | grep -E 'usr/local/bin/nova-(ui|game-mode|status)$' | grep -q '^-rwxr-xr-x' \
    && ok "scripts nova-* executáveis" || bad "scripts nova-* sem bit de execução"
  unsquashfs -cat "$WORK/fs.squashfs" usr/share/nova-ui/index.html >/dev/null 2>&1 && ok "index.html legível"
  ARCH="$(unsquashfs -cat "$WORK/fs.squashfs" var/lib/dpkg/arch 2>/dev/null | head -1)"; echo "dpkg arch: ${ARCH:-?}"
else
  bad "não foi possível extrair filesystem.squashfs"
fi
exit $fail
