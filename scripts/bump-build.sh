#!/bin/bash
# Bumps CURRENT_PROJECT_VERSION to the next build number.
#
# App Store Connect rejects an upload whose (MARKETING_VERSION, build number) pair it has
# already seen, so every upload needs a fresh build number even when the marketing version is
# unchanged. The number is a plain incrementing integer that never resets.
#
# All build configurations of all targets share one value, so this bumps them together and
# fails if they had drifted apart.
#
# Usage:
#   scripts/bump-build.sh            # next build number
#   scripts/bump-build.sh --dry-run
set -euo pipefail

PBXPROJ="$(dirname "$0")/../SilentShout.xcodeproj/project.pbxproj"

VALUES=$(sed -n 's/^[[:space:]]*CURRENT_PROJECT_VERSION = \([^;]*\);/\1/p' "$PBXPROJ" | sort -u)
if [ "$(printf '%s\n' "$VALUES" | wc -l | tr -d ' ')" -ne 1 ]; then
    echo "CURRENT_PROJECT_VERSION values are inconsistent:" >&2
    printf '  %s\n' $VALUES >&2
    exit 1
fi

CURRENT="$VALUES"
case "$CURRENT" in
    ''|*[!0-9]*)
        echo "CURRENT_PROJECT_VERSION '$CURRENT' is not a plain integer" >&2
        exit 1
        ;;
esac

NEXT=$(( CURRENT + 1 ))

if [ "${1:-}" = "--dry-run" ]; then
    echo "$CURRENT -> $NEXT (dry run, nothing written)"
    exit 0
fi

sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT;/CURRENT_PROJECT_VERSION = $NEXT;/g" "$PBXPROJ"
COUNT=$(grep -c "CURRENT_PROJECT_VERSION = $NEXT;" "$PBXPROJ")
echo "$CURRENT -> $NEXT ($COUNT build configurations updated)"
