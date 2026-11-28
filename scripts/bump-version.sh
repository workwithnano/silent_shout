#!/bin/bash
# Bumps MARKETING_VERSION to the next release version, Corduroying style (as Up There and
# Spud Bud do).
#
# Scheme: YYYY.MM.PATCH — calendar year and zero-padded month of the release, plus a patch that
# starts at 0 and increments for each release within the same month. Examples: 2026.11.0,
# 2026.11.1, 2026.12.0. App Store Connect compares components numerically, so the zero padding
# is cosmetic. Every target and configuration carries the same value, so this bumps them
# together and fails if they had drifted apart.
#
# Usage:
#   scripts/bump-version.sh          # next version for this month
#   scripts/bump-version.sh --dry-run
set -euo pipefail

PBXPROJ="$(dirname "$0")/../SilentShout.xcodeproj/project.pbxproj"

VALUES=$(sed -n 's/^[[:space:]]*MARKETING_VERSION = \([^;]*\);/\1/p' "$PBXPROJ" | sort -u)
if [ "$(printf '%s\n' "$VALUES" | wc -l | tr -d ' ')" -ne 1 ]; then
    echo "MARKETING_VERSION values are inconsistent:" >&2
    printf '  %s\n' $VALUES >&2
    exit 1
fi

CURRENT="$VALUES"
YM=$(date +%Y.%m)

if [[ "$CURRENT" == "$YM".* ]]; then
    PATCH=$(( ${CURRENT##*.} + 1 ))
else
    PATCH=0
fi
NEXT="$YM.$PATCH"

if [[ "${1:-}" == "--dry-run" ]]; then
    echo "$CURRENT -> $NEXT (dry run, nothing written)"
    exit 0
fi

sed -i '' "s/MARKETING_VERSION = $CURRENT;/MARKETING_VERSION = $NEXT;/g" "$PBXPROJ"
COUNT=$(grep -c "MARKETING_VERSION = $NEXT;" "$PBXPROJ")
echo "$CURRENT -> $NEXT ($COUNT build configurations updated)"
