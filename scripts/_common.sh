#!/usr/bin/env bash
set -euo pipefail

# Shared helper used by SmartGym run/build/deploy scripts.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

resolve_entrypoint() {
  local app="${1:-partner}"
  case "$app" in
    partner|owner|trainer)
      echo "lib/main_partner.dart"
      ;;
    customer|member|club)
      echo "lib/main_customer.dart"
      ;;
    *)
      echo "Unknown app '$app'. Use 'partner' or 'customer'." >&2
      return 1
      ;;
  esac
}

run_flavor() {
  local env_name="$1"
  shift
  local app="partner"
  if [[ $# -gt 0 ]] && [[ "$1" != -* ]]; then
    app="$1"
    shift
  fi
  local entrypoint
  entrypoint="$(resolve_entrypoint "$app")"

  echo ""
  echo "========================================"
  if [[ "$env_name" == "staging" ]]; then
    echo " Starting SmartGym ($app) -> STAGING"
    echo " Firebase DB : smartgym-os-staging"
  else
    echo " Starting SmartGym ($app) -> LIVE PROD"
    echo " Firebase DB : smartgym-os"
  fi
  echo " Entrypoint  : $entrypoint"
  echo "========================================"
  echo ""

  exec flutter run --flavor "$env_name" --dart-define="ENV=$env_name" -t "$entrypoint" "$@"
}

build_prod_binary() {
  local app="partner"
  local format="apk"
  if [[ $# -gt 0 ]] && [[ "$1" != -* ]]; then
    app="$1"
    shift
  fi
  if [[ $# -gt 0 ]] && [[ "$1" != -* ]]; then
    format="$1"
    shift
  fi
  local entrypoint
  entrypoint="$(resolve_entrypoint "$app")"

  local build_cmd="apk"
  case "$format" in
    apk)
      build_cmd="apk"
      ;;
    aab|appbundle|bundle)
      build_cmd="appbundle"
      ;;
    *)
      echo "Unknown format '$format'. Use 'apk' or 'aab'." >&2
      return 1
      ;;
  esac

  echo "==> Checking code quality (flutter analyze)..."
  flutter analyze
  echo "==> Running automated tests (flutter test)..."
  flutter test
  echo "==> Building LIVE PROD $build_cmd ($app -> $entrypoint)..."
  flutter build "$build_cmd" --flavor prod --dart-define="ENV=prod" -t "$entrypoint" "$@"
}
