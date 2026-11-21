#!/usr/bin/env bash
# Repara referências de kernel/initrd geradas pelo live-build quando o GRUB
# aponta para nomes versionados, mas a ISO contém somente /live/vmlinuz e
# /live/initrd.img. Preserva o catálogo de boot El Torito/UEFI com xorriso.
set -euo pipefail

ISO="${1:?uso: $0 arquivo.iso}"
ROOT="${2:-binary}"
[[ -s "$ISO" ]] || { echo "[FALHA] ISO ausente: $ISO" >&2; exit 2; }
[[ -d "$ROOT/live" ]] || { echo "[FALHA] diretório $ROOT/live não existe" >&2; exit 2; }
command -v xorriso >/dev/null || { echo "[FALHA] xorriso não instalado" >&2; exit 2; }

WORK="$(mktemp -d)"
TMP_ISO="${ISO%.iso}.repaired.iso"
cleanup(){ rm -rf "$WORK"; rm -f "$TMP_ISO"; }
trap cleanup EXIT

python3 - "$ROOT" "$WORK" <<'PY'
import pathlib, re, shutil, sys
root = pathlib.Path(sys.argv[1]).resolve()
work = pathlib.Path(sys.argv[2]).resolve()
configs = list(root.rglob("grub.cfg"))
if not configs:
    raise SystemExit("[FALHA] nenhum grub.cfg encontrado na árvore binary")
aliases = {}
for cfg in configs:
    try:
        text = cfg.read_text(errors="replace")
    except OSError:
        continue
    for line in text.splitlines():
        m = re.match(r"\s*(?:linux|linuxefi|initrd|initrdefi)\s+(\S+)", line)
        if not m:
            continue
        target = m.group(1).split("=", 1)[0]
        if not target.startswith("/live/"):
            continue
        target_path = root / target.lstrip("/")
        if target_path.is_file() and target_path.stat().st_size:
            continue
        base = pathlib.PurePosixPath(target).name
        if base.startswith("vmlinuz"):
            source = root / "live/vmlinuz"
        elif base.startswith("initrd"):
            source = root / "live/initrd.img"
        else:
            continue
        if not source.is_file() or not source.stat().st_size:
            raise SystemExit(f"[FALHA] GRUB referencia {target}, mas {source} não existe")
        aliases[target] = source

if not aliases:
    print("[OK] nenhuma referência quebrada de kernel/initrd encontrada nos grub.cfg.")
else:
    for target, source in sorted(aliases.items()):
        out = work / target.lstrip("/")
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, out)
        print(f"[REPARO] {target} <- /{source.relative_to(root).as_posix()}")
    (work / "aliases.txt").write_text("\n".join(sorted(aliases)) + "\n")
PY

if [[ -s "$WORK/aliases.txt" ]]; then
  map_args=()
  while IFS= read -r target; do
    [[ -n "$target" ]] || continue
    map_args+=( -map "$WORK/${target#/}" "$target" )
  done < "$WORK/aliases.txt"

  xorriso -indev "$ISO" -outdev "$TMP_ISO" \
    -boot_image any replay "${map_args[@]}" -commit
  [[ -s "$TMP_ISO" ]] || { echo "[FALHA] xorriso não criou a ISO reparada" >&2; exit 3; }
  mv -f "$TMP_ISO" "$ISO"

  while IFS= read -r target; do
    [[ -n "$target" ]] || continue
    verify="$WORK/verify"
    rm -f "$verify"
    xorriso -osirrox on -indev "$ISO" -extract "$target" "$verify" >/dev/null 2>&1
    [[ -s "$verify" ]] || { echo "[FALHA] alias não foi gravado na ISO: $target" >&2; exit 4; }
    echo "[OK] ISO contém $target ($(stat -c %s "$verify") bytes)"
  done < "$WORK/aliases.txt"
fi

echo "[OK] reparo de caminhos de boot concluído."
