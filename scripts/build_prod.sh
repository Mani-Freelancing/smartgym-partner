#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

# Usage:
#   ./scripts/build_prod.sh             (Partner APK)
#   ./scripts/build_prod.sh partner aab (Partner Play Store AppBundle)
#   ./scripts/build_prod.sh customer    (Customer APK)
build_prod_binary "$@"
