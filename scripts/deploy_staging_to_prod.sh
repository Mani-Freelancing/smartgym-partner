#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

# Safely promotes tested code from `staging` -> `main`, deploys Firestore rules
# to LIVE Production (`smartgym-os`), builds the Production binary, and returns
# you to `staging` for ongoing work.
# Usage:
#   ./scripts/deploy_staging_to_prod.sh            (builds Partner APK)
#   ./scripts/deploy_staging_to_prod.sh partner aab
APP="${1:-partner}"
FORMAT="${2:-apk}"
shift $(( $# >= 2 ? 2 : $# )) || true

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: You have uncommitted changes. Commit or stash them before deploying to prod." >&2
  exit 1
fi

if ! git show-ref --verify --quiet refs/heads/staging; then
  echo "Error: Local branch 'staging' does not exist." >&2
  exit 1
fi

echo ""
echo "This will:"
echo "  1. Merge 'staging' -> 'main'"
echo "  2. Run flutter analyze & flutter test"
echo "  3. Deploy firestore.rules to LIVE PROD (smartgym-os)"
echo "  4. Build LIVE PROD $FORMAT ($APP)"
echo ""
read -r -p "Continue? [y/N] " REPLY
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

git checkout main
git merge staging

echo "==> Deploying Firestore rules to LIVE PROD (smartgym-os)..."
npx -y firebase-tools@latest deploy --only firestore:rules -P prod

build_prod_binary "$APP" "$FORMAT" "$@"

git checkout staging
echo ""
echo "Done! Live prod build & rules updated, and switched back to 'staging' branch."
echo "Don't forget to run 'git push origin main staging' when ready."
