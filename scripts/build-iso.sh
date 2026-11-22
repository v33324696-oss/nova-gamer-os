#!/usr/bin/env bash
# NOVA GAMER OS - compila a ISO com live-build (Debian 13 "trixie", amd64).
# Rodar como root em Debian/Ubuntu Linux com internet e >= 25 GB livres.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

if [[ $EUID -ne 0 ]]; then
  echo "Execute: sudo ./scripts/build-iso.sh"
  exit 1
fi
command -v lb >/dev/null 2>&1 || {
  echo "Instale: sudo apt install live-build debootstrap xorriso squashfs-tools"
  exit 1
}

export DEBIAN_FRONTEND=noninteractive

# Arquivos editados/baixados no Windows podem ter CRLF, o que quebra hooks, scripts e units systemd.
find scripts config -type f -exec sed -i 's/\r$//' {} +
chmod +x scripts/*.sh config/hooks/live/*.hook.chroot 2>/dev/null || true
# Só o que este script e o repair-iso-boot-paths.sh realmente usam (python3/unsquashfs são do validate-iso.sh).
for tool in file xorriso; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Ferramenta ausente: $tool (instale: sudo apt install file xorriso)"; exit 1; }
done

mkdir -p build
exec > >(tee -a build/BUILD-LOG.txt) 2>&1
BUILD_STARTED="$(date +%s)"
echo "== NOVA GAMER OS build iniciado em $(date -u +%FT%TZ) =="
echo "== live-build: $(dpkg-query -W -f='${Version}' live-build 2>/dev/null || echo desconhecida) =="

# Não ignore falhas de limpeza: um cache/chroot antigo pode contaminar a ISO nova.
lb clean --all

lb config \
  --distribution trixie \
  --architectures amd64 \
  --binary-images iso-hybrid \
  --debian-installer live \
  --debian-installer-gui true \
  --uefi-secure-boot disable \
  --archive-areas "main contrib non-free non-free-firmware" \
  --iso-volume "NOVA_GAMER_OS" \
  --iso-application "NOVA GAMER OS" \
  --image-name "NOVA-GAMER-OS" \
  --bootappend-live "boot=live components username=nova hostname=nova-gamer-os locales=pt_BR.UTF-8 keyboard-layouts=br console=tty0 console=ttyS0,115200n8 systemd.show_status=1"

lb build

# Só aceite uma ISO efetivamente criada nesta execução.
ISO="$(find . -maxdepth 1 -type f -name '*.iso' -newermt "@$((BUILD_STARTED - 1))" -printf '%T@ %p\n' \
  | sort -nr | head -n1 | cut -d' ' -f2-)"
if [[ -z "$ISO" || ! -s "$ISO" ]]; then
  echo "Nenhuma ISO nova foi criada após lb build." >&2
  exit 2
fi

# Corrige divergência entre nomes versionados no GRUB e nomes genéricos
# realmente fornecidos pelo live-build. Não altera kernel nem initrd.
chmod +x scripts/repair-iso-boot-paths.sh
./scripts/repair-iso-boot-paths.sh "$ISO" binary

cp -- "$ISO" build/NOVA-GAMER-OS-amd64.iso
(cd build && sha256sum NOVA-GAMER-OS-amd64.iso > SHA256SUMS.txt)
SIZE="$(du -h build/NOVA-GAMER-OS-amd64.iso | cut -f1)"
echo "ISO criada: build/NOVA-GAMER-OS-amd64.iso ($SIZE)"
echo "SHA-256: build/SHA256SUMS.txt"
echo "IMPORTANTE: só instale depois de VALIDATE-LOG e QEMU-LOG terminarem sem falhas."
