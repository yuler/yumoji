#!/usr/bin/env bash
# Generate ios/Yumoji.xcodeproj from ios/project.yml using the resolved version
# (YUMOJI_VERSION env override or latest vX.Y.Z Git tag).

set -euo pipefail

source "$(dirname "$0")/lib.sh"
generate_xcode_project
