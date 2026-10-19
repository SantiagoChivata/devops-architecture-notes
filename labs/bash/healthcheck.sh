#!/usr/bin/env bash
# healthcheck.sh — Verifica que una lista de URLs responda 2xx.
#
# Uso:    ./healthcheck.sh <url> [url...]
# Env:    TIMEOUT  segundos por request, entero o decimal (default: 5)
# Exit:   0 = todas UP | 1 = al menos una DOWN | 2 = uso o config incorrecta
set -euo pipefail

TIMEOUT="${TIMEOUT:-5}"

log() {
  local level="$1"; shift
  printf '[%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$level" "$*" >&2
}

if [[ ! "$TIMEOUT" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  log ERROR "TIMEOUT debe ser numérico (actual: '$TIMEOUT')"
  exit 2
fi

if [[ $# -eq 0 ]]; then
  log ERROR "uso: $0 <url> [url...]"
  exit 2
fi

failed=0

for url in "$@"; do
  code=$(curl -sSL -g -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT" -- "$url") || code="000"

  if [[ "$code" == 2* ]]; then
    log INFO "UP   $url ($code)"
  else
    log ERROR "DOWN $url ($code)"
    failed=$((failed + 1))
  fi
done

if [[ $failed -gt 0 ]]; then
  log ERROR "$failed de $# servicio(s) caído(s)"
  exit 1
fi

log INFO "Todo OK ($# servicio(s))"
exit 0