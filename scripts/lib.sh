#!/usr/bin/env bash
# Shared helpers for Yumoji iOS build and release scripts.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_PROJECT="$ROOT/ios/Yumoji.xcodeproj"
IOS_SCHEME="Yumoji"
IOS_DERIVED="$ROOT/.build/ios"

export ROOT IOS_PROJECT IOS_SCHEME IOS_DERIVED

load_app_version() {
  APP_VERSION="$("$ROOT/scripts/resolve-version.sh")"
  if [[ ! "$APP_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    echo "Invalid resolved version: $APP_VERSION (expected X.Y.Z)" >&2
    return 1
  fi
  local major="${BASH_REMATCH[1]}"
  local minor="${BASH_REMATCH[2]}"
  local patch="${BASH_REMATCH[3]}"
  APP_BUILD=$(( 10#$major * 10000 + 10#$minor * 100 + 10#$patch ))
  [[ "$APP_BUILD" -lt 1 ]] && APP_BUILD=1
  export APP_VERSION APP_BUILD
}

generate_xcode_project() {
  load_app_version
  xcodegen generate --spec "$ROOT/ios/project.yml" --project "$ROOT/ios/"
}
