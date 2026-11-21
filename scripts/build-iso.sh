#!/usr/bin/env bash
# NOVA GAMER OS - compila a ISO com live-build (Debian 13 "trixie", amd64).
# Rodar como root em Debian/Ubuntu Linux com internet e >= 20 GB livres:
#   sudo ./scripts/build-iso.sh
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

mkdir -p build
exec > >(tee -a build/BUILD-LOG.txt) 2>&1
echo "== NOVA GAMER OS build iniciado em $(date -u +%FT%TZ) =="
echo "== live-build: $(dpkg-query -W -f='${Version}' live-build 2>/dev/null || echo desconhecida) =="

# Limpa apenas artefatos de build anteriores (sem --purge, para não tocar em config/)
lb clean --all || true

lb config \
  --distribution trixie \
  --architectures amd64 \
  --binary-images iso-hybrid \
  --debian-installer live \
  --debian-installer-gui true \
  --archive-areas "main contrib non-free non-free-firmware" \
  --iso-volume "NOVA_GAMER_OS" \
  --iso-application "NOVA GAMER OS" \
  --image-name "NOVA-GAMER-OS" \
  --bootappend-live "boot=live components username=nova hostname=nova-gamer-os locales=pt_BR.UTF-8 keyboard-layouts=br"

lb build

ISO="$(find . -maxdepth 1 -type f -name '*.iso' -printf '%T@ %p\n' | sort -nr | head -n1 | cut -d' ' -f2-)"
if [[ -z "$ISO" ]]; then
  echo "Nenhuma ISO encontrada após a construção." >&2
  exit 2
fi
cp -- "$ISO" build/NOVA-GAMER-OS-amd64.iso
(cd build && sha256sum NOVA-GAMER-OS-amd64.iso > SHA256SUMS.txt)
SIZE="$(du -h build/NOVA-GAMER-OS-amd64.iso | cut -f1)"
echo "ISO criada: build/NOVA-GAMER-OS-amd64.iso ($SIZE)"
echo "SHA-256: build/SHA256SUMS.txt"
echo "A meta de 1 GB não é garantida."
