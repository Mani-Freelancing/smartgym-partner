#!/usr/bin/env bash
set -euo pipefail

# Shared helper used by SmartGym ./gym CLI, scripts/*.sh, and Makefile.
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
      echo "Unknown app '$app'. Use 'partner' (owner) or 'customer'." >&2
      return 1
      ;;
  esac
}

is_ios_device_requested() {
  local prev=""
  for arg in "$@"; do
    if [[ "$prev" == "-d" || "$prev" == "--device-id" ]]; then
      local lower
      lower="$(echo "$arg" | tr '[:upper:]' '[:lower:]')"
      if [[ "$lower" == *iphone* || "$lower" == *ipad* || "$lower" == *ios* ]]; then
        return 0
      fi
    fi
    prev="$arg"
  done
  return 1
}

run_app() {
  local env_name="$1"
  local app="$2"
  local platform="$3"
  shift 3
  local entrypoint
  entrypoint="$(resolve_entrypoint "$app")"

  if [[ "$platform" == "auto" ]]; then
    if is_ios_device_requested "$@"; then
      platform="ios"
    else
      platform="android"
    fi
  fi

  local args=()
  if [[ "$platform" != "ios" ]]; then
    args+=(--flavor "$env_name")
  fi
  args+=(--dart-define="ENV=$env_name" -t "$entrypoint" "$@")

  echo ""
  echo "========================================"
  echo " App         : $app ($platform)"
  if [[ "$env_name" == "staging" ]]; then
    echo " Environment : STAGING (smartgym-os-staging)"
  else
    echo " Environment : LIVE PROD (smartgym-os)"
  fi
  echo " Entrypoint  : $entrypoint"
  echo "========================================"
  echo ""

  if [[ "${SMARTGYM_DRY_RUN:-0}" == "1" ]]; then
    echo "DRY_RUN: flutter run ${args[*]}"
    return 0
  fi

  exec flutter run "${args[@]}"
}

build_app() {
  local env_name="$1"
  local app="$2"
  local format="$3"
  shift 3
  local entrypoint
  entrypoint="$(resolve_entrypoint "$app")"

  local build_cmd=""
  local needs_flavor="1"
  case "$format" in
    apk)
      build_cmd="apk"
      ;;
    aab|appbundle|bundle)
      build_cmd="appbundle"
      ;;
    ipa)
      build_cmd="ipa"
      needs_flavor="0"
      ;;
    ios)
      build_cmd="ios"
      needs_flavor="0"
      ;;
    *)
      echo "Unknown format '$format'. Use 'apk', 'aab', 'ios', or 'ipa'." >&2
      return 1
      ;;
  esac

  local args=("$build_cmd")
  if [[ "$needs_flavor" == "1" ]]; then
    args+=(--flavor "$env_name")
  fi
  args+=(--dart-define="ENV=$env_name" -t "$entrypoint" "$@")

  if [[ "${SMARTGYM_DRY_RUN:-0}" == "1" ]]; then
    if [[ "$env_name" == "prod" ]]; then
      echo "DRY_RUN: flutter analyze && flutter test"
    fi
    echo "DRY_RUN: flutter build ${args[*]}"
    return 0
  fi

  if [[ "$env_name" == "prod" ]]; then
    echo "==> Checking code quality (flutter analyze)..."
    flutter analyze
    echo "==> Running automated tests (flutter test)..."
    flutter test
  fi

  local env_upper
  env_upper="$(echo "$env_name" | tr '[:lower:]' '[:upper:]')"
  echo "==> Building $env_upper $build_cmd ($app -> $entrypoint)..."
  flutter build "${args[@]}"
}

deploy_rules() {
  local env_name="$1"
  if [[ "${SMARTGYM_DRY_RUN:-0}" == "1" ]]; then
    echo "DRY_RUN: npx -y firebase-tools@latest deploy --only firestore:rules -P $env_name"
    return 0
  fi
  echo "==> Deploying firestore.rules to $env_name..."
  npx -y firebase-tools@latest deploy --only firestore:rules -P "$env_name"
}

push_branch() {
  local msg="${1:-}"
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"

  if [[ "$branch" == "main" ]]; then
    echo "Warning: You are on 'main' (LIVE production branch)."
    if [[ "${SMARTGYM_DRY_RUN:-0}" != "1" ]]; then
      read -r -p "Are you sure you want to push directly to 'main'? [y/N] " REPLY
      if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        echo "Cancelled. Tip: work on 'staging' and run './gym ship' when ready."
        return 0
      fi
    fi
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    echo "==> Changes to commit on '$branch':"
    git status -s
    if [[ -z "$msg" && "${SMARTGYM_DRY_RUN:-0}" != "1" ]]; then
      read -r -p "Commit message (e.g. Added new trainer filter): " msg
    fi
    if [[ -z "$msg" ]]; then
      msg="Update $branch"
    fi
    if [[ "${SMARTGYM_DRY_RUN:-0}" == "1" ]]; then
      echo "DRY_RUN: git add -A && git commit -m \"$msg\""
    else
      git add -A
      git commit -m "$msg"
    fi
  else
    echo "==> Working tree clean on '$branch'."
  fi

  if [[ "${SMARTGYM_DRY_RUN:-0}" == "1" ]]; then
    echo "DRY_RUN: git push -u origin $branch"
    return 0
  fi

  echo "==> Pushing '$branch' to origin..."
  git push -u origin "$branch"
}

ship_to_prod() {
  local app="${1:-partner}"
  local format="${2:-apk}"
  shift $(( $# >= 2 ? 2 : $# )) || true

  if [[ "${SMARTGYM_DRY_RUN:-0}" != "1" ]]; then
    if [[ -n "$(git status --porcelain)" ]]; then
      echo "Error: You have uncommitted changes. Run './gym push' on 'staging' first." >&2
      return 1
    fi
    if ! git show-ref --verify --quiet refs/heads/staging; then
      echo "Error: Local branch 'staging' does not exist." >&2
      return 1
    fi

    echo ""
    echo "This will:"
    echo "  1. Merge 'staging' -> 'main'"
    echo "  2. Run flutter analyze & flutter test"
    echo "  3. Deploy firestore.rules to LIVE PROD (smartgym-os)"
    echo "  4. Build LIVE PROD $format ($app)"
    echo ""
    read -r -p "Continue? [y/N] " REPLY
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
      echo "Cancelled."
      return 0
    fi

    git checkout main
    git merge staging
  else
    echo "DRY_RUN: git checkout main && git merge staging"
  fi

  deploy_rules prod
  build_app prod "$app" "$format" "$@"

  if [[ "${SMARTGYM_DRY_RUN:-0}" == "1" ]]; then
    echo "DRY_RUN: git push origin main staging && git checkout staging"
    return 0
  fi

  read -r -p "Push updated 'main' and 'staging' to GitHub now? [Y/n] " PUSH_REPLY
  if [[ -z "$PUSH_REPLY" || "$PUSH_REPLY" =~ ^[Yy]$ ]]; then
    git push -u origin main staging
  fi

  git checkout staging
  echo ""
  echo "Done! Prod rules deployed, build created, and switched back to 'staging'."
}

# Backwards-compatible aliases used by scripts/run_*.sh and scripts/build_prod.sh
run_flavor() {
  local env_name="$1"
  shift
  local app="partner"
  local platform="auto"
  local passthrough=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ios|ios)
        platform="ios"
        ;;
      --android|android)
        platform="android"
        ;;
      --customer|customer)
        app="customer"
        ;;
      --partner|--owner|partner|owner)
        app="partner"
        ;;
      *)
        passthrough+=("$1")
        ;;
    esac
    shift
  done
  run_app "$env_name" "$app" "$platform" "${passthrough[@]+"${passthrough[@]}"}"
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
  build_app prod "$app" "$format" "$@"
}
