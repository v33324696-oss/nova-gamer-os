#!/usr/bin/env bash
# Teste de boot em QEMU (BIOS e UEFI), com captura de tela e encerramento limitado.
set -euo pipefail

ISO="${1:?uso: $0 arquivo.iso}"
[[ -s "$ISO" ]] || { echo "[FALHA] ISO ausente ou vazia: $ISO"; exit 2; }
command -v qemu-system-x86_64 >/dev/null || { echo "[FALHA] qemu-system-x86_64 não instalado"; exit 2; }

OUT="build/qemu"
mkdir -p "$OUT"
WAIT="${BOOT_WAIT:-240}"
MARKER="NOVA_GAMER_OS_GRAPHICAL_READY"
RESULT=0

if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    ACCEL_ARGS=(-enable-kvm -cpu host)
    echo "Acelerador QEMU: KVM"
else
    ACCEL_ARGS=(-accel tcg,thread=multi -cpu max)
    echo "Acelerador QEMU: TCG (software)"
fi

# Converte captura PPM (QEMU) em PNG para poder abrir no Windows/navegador.
ppm2png() {
    [[ -s "$1" ]] || return 0
    python3 - "$1" "${1%.ppm}.png" <<'PY' 2>/dev/null || true
import sys, zlib, struct
src, dst = sys.argv[1:3]
d = open(src, 'rb').read()
parts, i = [], 0
while len(parts) < 4:
    while d[i:i+1].isspace(): i += 1
    if d[i:i+1] == b'#':
        while d[i:i+1] != b'\n': i += 1
        continue
    j = i
    while not d[j:j+1].isspace(): j += 1
    parts.append(d[i:j]); i = j
i += 1
w, h = int(parts[1]), int(parts[2])
px = d[i:i + w * h * 3]
raw = b''.join(b'\x00' + px[y*w*3:(y+1)*w*3] for y in range(h))
def chunk(t, b):
    return struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b) & 0xffffffff)
open(dst, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
                      + chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b''))
PY
}

snap() { # snap <monitor> <arquivo.ppm>
    [[ -S "$1" ]] && command -v socat >/dev/null 2>&1 || return 0
    printf 'screendump %s\n' "$2" | timeout 5 socat - "UNIX-CONNECT:$1" >/dev/null 2>&1 || true
    sleep 1
    ppm2png "$2"
}

run_vm() {
    local name="$1"; shift
    local serial="$OUT/$name-serial.log"
    local debug="$OUT/$name-qemu-debug.log"
    local monitor="$OUT/$name-monitor.sock"
    local screenshot="$OUT/$name-screen.ppm"
    local pid=""
    local elapsed=0
    local -a extra=("$@")

    rm -f "$serial" "$debug" "$monitor" "$screenshot"
    echo "== Teste $name: aguardando kernel, sistema Live e LightDM (limite ${WAIT}s) =="

    qemu-system-x86_64 \
      -machine q35 -m 3072 -smp 2 \
      "${ACCEL_ARGS[@]}" \
      -vga std \
      -drive if=none,id=usbstick,format=raw,media=disk,file="$ISO" \
      -device qemu-xhci,id=xhci \
      -device usb-storage,bus=xhci.0,drive=usbstick,bootindex=1 \
      -boot menu=on \
      -display none \
      -monitor "unix:$monitor,server=on,wait=off" \
      -serial "file:$serial" \
      -d guest_errors -D "$debug" \
      -no-reboot \
      "${extra[@]}" &
    pid=$!

    while (( elapsed < WAIT )); do
        if [[ -f "$serial" ]] && grep -Fq "$MARKER" "$serial"; then
            break
        fi
        if ! kill -0 "$pid" 2>/dev/null; then
            break
        fi
        # O menu do bootloader (SYSLINUX/GRUB) espera uma tecla: aperta Enter a cada 6s nos
        # primeiros 150s para escolher a entrada padrao "Live system".
        if (( elapsed < 150 && elapsed % 6 == 0 )) && [[ -S "$monitor" ]] && command -v socat >/dev/null 2>&1; then
            printf 'sendkey ret\n' | timeout 3 socat - "UNIX-CONNECT:$monitor" >/dev/null 2>&1 || true
        fi
        # Captura intermediaria para diagnostico (menu/kernel em andamento).
        if (( elapsed == 0 )); then echo "[INFO] $name: enviando Enter ao menu do bootloader (se houver)"; fi
        if (( elapsed == 30 || elapsed == 90 || elapsed == 180 )); then
            snap "$monitor" "$OUT/$name-screen-${elapsed}s.ppm"
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    # Salva a tela do firmware/GRUB/kernel para diagnosticar falhas sem saída serial.
    snap "$monitor" "$screenshot"

    # Nunca deixa o teste preso esperando indefinidamente pelo QEMU.
    kill -TERM "$pid" 2>/dev/null || true
    sleep 2
    kill -KILL "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true

    if [[ -f "$serial" ]] && grep -Fq "$MARKER" "$serial"; then
        echo "[OK] $name: Linux iniciou o sistema Live e o LightDM confirmou inicialização."
        return 0
    fi

    echo "[FALHA] $name: o LightDM não confirmou inicialização após ${elapsed}s."
    if [[ -s "$screenshot" ]]; then
        echo "[INFO] Captura da tela salva em ${screenshot%.ppm}.png"
    else
        echo "[AVISO] QEMU não gerou captura de tela."
    fi
    if [[ -s "$serial" ]]; then
        echo "---- Últimas linhas do console serial ($name) ----"
        tail -n 80 "$serial" || true
        echo "--------------------------------------------------"
    else
        echo "[FALHA] QEMU não produziu saída serial."
    fi
    if [[ -s "$debug" ]]; then
        echo "---- Últimas linhas do diagnóstico QEMU ($name) ----"
        tail -n 80 "$debug" || true
        echo "----------------------------------------------------"
    fi
    return 1
}

echo "== Boot BIOS (SeaBIOS) =="
if ! run_vm bios; then RESULT=1; fi

OVMF_CODE=""
OVMF_VARS=""
for pair in \
  "/usr/share/OVMF/OVMF_CODE_4M.fd:/usr/share/OVMF/OVMF_VARS_4M.fd" \
  "/usr/share/OVMF/OVMF_CODE.fd:/usr/share/OVMF/OVMF_VARS.fd"; do
    code="${pair%%:*}"
    vars="${pair#*:}"
    if [[ -r "$code" && -r "$vars" ]]; then
        OVMF_CODE="$code"
        OVMF_VARS="$vars"
        break
    fi
done

if [[ -n "$OVMF_CODE" && -n "$OVMF_VARS" ]]; then
    echo "== Boot UEFI (OVMF) =="
    VARS_COPY="$OUT/OVMF_VARS-test.fd"
    cp "$OVMF_VARS" "$VARS_COPY"
    chmod u+w "$VARS_COPY"
    if ! run_vm uefi \
      -drive "if=pflash,format=raw,unit=0,readonly=on,file=$OVMF_CODE" \
      -drive "if=pflash,format=raw,unit=1,file=$VARS_COPY"; then
        RESULT=1
    fi
else
    echo "[FALHA] OVMF CODE/VARS não encontrados; UEFI não foi testado."
    RESULT=1
fi

exit "$RESULT"
