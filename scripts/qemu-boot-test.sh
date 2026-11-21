#!/usr/bin/env bash
# Teste de boot em VM (QEMU) - BIOS e UEFI. Gera capturas de tela em build/qemu/.
# Requer: qemu-system-x86 ovmf python3. Uso: ./scripts/qemu-boot-test.sh build/NOVA-GAMER-OS-amd64.iso
set -uo pipefail
ISO="${1:?uso: $0 arquivo.iso}"
OUT="build/qemu"; mkdir -p "$OUT"
ACCEL=""; [[ -w /dev/kvm ]] && ACCEL="-enable-kvm -cpu host" || ACCEL="-cpu max"
WAIT="${BOOT_WAIT:-150}"
result=0

run_vm() {  # $1=nome  $2..=args extras
  local name="$1"; shift
  local sock="$OUT/$name.mon"
  rm -f "$sock"
  qemu-system-x86_64 -m 3072 -smp 2 $ACCEL -cdrom "$ISO" -boot d \
    -display none -vga std -monitor unix:"$sock",server,nowait "$@" &
  local pid=$!
  sleep "$WAIT"
  echo "screendump $OUT/$name.ppm" | socat - UNIX-CONNECT:"$sock" >/dev/null 2>&1
  sleep 2
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  if [[ -s "$OUT/$name.ppm" ]]; then
    python3 - "$OUT/$name.ppm" "$name" <<'PY'
import sys
data=open(sys.argv[1],'rb').read()
body=data.split(b'\n',3)[3] if data.startswith(b'P6') else data
distinct=len(set(body[i:i+3] for i in range(0,min(len(body),3_000_000),3)))
print(f"[{sys.argv[2]}] cores distintas na captura: {distinct}")
sys.exit(0 if distinct>8 else 1)
PY
    if [[ $? -eq 0 ]]; then echo "[OK]   $name: tela com conteúdo (menu de boot ou desktop)"; else echo "[FALHA] $name: tela em branco"; result=1; fi
  else
    echo "[FALHA] $name: sem captura de tela"; result=1
  fi
}

echo "== Boot BIOS (SeaBIOS) =="; run_vm bios
OVMF="$(ls /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd 2>/dev/null | head -1)"
if [[ -n "$OVMF" ]]; then
  echo "== Boot UEFI (OVMF) =="; run_vm uefi -drive if=pflash,format=raw,readonly=on,file="$OVMF"
else
  echo "[FALHA] OVMF não encontrado; UEFI não testado"; result=1
fi
exit $result
