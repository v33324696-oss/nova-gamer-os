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
      -cdrom "$ISO" -boot order=d \
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
        sleep 2
        elapsed=$((elapsed + 2))
    done

    # Salva a tela do firmware/GRUB/kernel para diagnosticar falhas sem saída serial.
    if [[ -S "$monitor" ]] && command -v socat >/dev/null 2>&1; then
        printf 'screendump %s\n' "$screenshot" | socat - "UNIX-CONNECT:$monitor" >/dev/null 2>&1 || true
    fi

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
        echo "[INFO] Captura da tela salva em $screenshot"
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
