#!/usr/bin/env bash
# NOVA GAMER OS - build completo DENTRO do WSL (chamado por BUILD-ISO-WINDOWS.bat).
# Copia o projeto para o disco Linux (ext4), instala TODAS as ferramentas,
# compila, valida, testa o boot em QEMU e devolve ISO + logs para a pasta do Windows.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$HOME/nova-build"
FILES=(NOVA-GAMER-OS-amd64.iso SHA256SUMS.txt BUILD-LOG.txt VALIDATE-LOG.txt QEMU-LOG.txt)

collect() {
  local rc=$?
  mkdir -p "$SRC/build" 2>/dev/null || true
  for f in "${FILES[@]}"; do
    [[ -s "$WORK/build/$f" ]] && cp -f "$WORK/build/$f" "$SRC/build/" 2>/dev/null || true
  done
  [[ -d "$WORK/build/qemu" ]] && cp -rf "$WORK/build/qemu" "$SRC/build/" 2>/dev/null || true
  if (( rc != 0 )); then
    echo
    echo "[FALHA] Build interrompido (codigo $rc). Logs copiados para: $SRC/build"
    echo "        Envie BUILD-LOG.txt / VALIDATE-LOG.txt / QEMU-LOG.txt para diagnostico."
  fi
}
trap collect EXIT

echo "== Projeto no Windows : $SRC"
echo "== Copia de trabalho  : $WORK"
echo "== Espaco livre em \$HOME:"
df -h "$HOME" | tail -n 1

echo "== Instalando ferramentas (pode pedir a senha do usuario Debian) =="
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  live-build debootstrap xorriso squashfs-tools rsync file python3 socat \
  syslinux syslinux-utils isolinux grub-pc-bin grub-efi-amd64-bin grub-common \
  mtools dosfstools ca-certificates gnupg debian-archive-keyring \
  qemu-system-x86 ovmf

if [[ ! -e /usr/share/debootstrap/scripts/trixie ]]; then
  echo "[FALHA] Este Debian do WSL tem um debootstrap antigo que nao conhece 'trixie'." >&2
  echo "        Atualize o Debian do WSL (sudo apt full-upgrade) ou use o GitHub Actions (README.md)." >&2
  exit 10
fi

rm -rf "$WORK"
mkdir -p "$WORK"
rsync -a --exclude build --exclude chroot --exclude binary --exclude cache --exclude .git "$SRC/" "$WORK/"
cd "$WORK"

# Arquivos vindos do Windows podem ter CRLF, o que quebra scripts, hooks e units systemd.
find scripts config .github -type f -exec sed -i 's/\r$//' {} +
chmod +x scripts/*.sh config/hooks/live/*.hook.chroot

sudo ./scripts/build-iso.sh
sudo ./scripts/validate-iso.sh build/NOVA-GAMER-OS-amd64.iso | sudo tee build/VALIDATE-LOG.txt
sudo env BOOT_WAIT="${BOOT_WAIT:-600}" ./scripts/qemu-boot-test.sh build/NOVA-GAMER-OS-amd64.iso | sudo tee build/QEMU-LOG.txt

echo "[OK] Build, validacao e teste de boot concluidos."
