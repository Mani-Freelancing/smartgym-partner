#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

# Usage:
#   ./scripts/run_prod.sh               (Partner app: Owner + Trainer)
#   ./scripts/run_prod.sh customer      (Customer app)
run_flavor prod "$@"
