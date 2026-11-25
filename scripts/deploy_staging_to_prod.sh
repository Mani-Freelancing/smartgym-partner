#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

# Usage:
#   ./scripts/deploy_staging_to_prod.sh              (builds Partner APK)
#   ./scripts/deploy_staging_to_prod.sh partner aab
#   ./scripts/deploy_staging_to_prod.sh customer apk
APP="partner"
FORMAT="apk"
if [[ $# -gt 0 ]] && [[ "$1" != -* ]]; then
  APP="$1"
  shift
fi
if [[ $# -gt 0 ]] && [[ "$1" != -* ]]; then
  FORMAT="$1"
  shift
fi

ship_to_prod "$APP" "$FORMAT" "$@"
