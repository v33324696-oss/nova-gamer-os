#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 1 || ! -f "$1" ]]; then
  echo "Uso: $0 /caminho/arquivo.exe"
  exit 1
fi
if ! command -v wine >/dev/null 2>&1; then
  echo "Wine não está instalado nesta imagem-base."
  echo "A compatibilidade com executáveis Windows não é garantida."
  exit 2
fi
wine "$1"
