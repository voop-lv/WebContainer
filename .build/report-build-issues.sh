#!/usr/bin/env bash
# Usage: report-build-issues.sh <build.log>
# Turns the "[ERROR] ..." / "[WARN] ..." lines of an image build log into GitHub annotations, a job summary
# section and build-comment.md (PR comment body). Env: ARCH, BUILD_OUTCOME, RUN_URL (all optional).
set -euo pipefail

LOG="$1"
ARCH="${ARCH:-unknown}"
BUILD_OUTCOME="${BUILD_OUTCOME:-unknown}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"

# BuildKit prefixes lines ("#17 44.39 ") and repeats the failing lines in its error block; keep each message once.
issues="$(grep -oE '\[(ERROR|WARN|WARNING)\] .*' "$LOG" 2>/dev/null | awk '!seen[$0]++' || true)"

if [[ -z "$issues" && "$BUILD_OUTCOME" != "failure" ]]; then
    echo "No build errors or warnings."
    exit 0
fi

{
    echo "### Image build (${ARCH}): ${BUILD_OUTCOME}"
    echo
} > build-comment.md

while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    msg="${line#*] }"
    annotation="${msg//%/%25}"
    if [[ "$line" == "[ERROR]"* ]]; then
        echo "::error title=Image build (${ARCH})::${annotation}"
        echo "- :x: ${msg}" >> build-comment.md
    else
        echo "::warning title=Image build (${ARCH})::${annotation}"
        echo "- :warning: ${msg}" >> build-comment.md
    fi
done <<< "$issues"

if [[ "$BUILD_OUTCOME" == "failure" && "$issues" != *"[ERROR]"* ]]; then
    echo "::error title=Image build (${ARCH})::Build failed without an [ERROR] line; see the build step log"
    echo "- :x: Build failed without an \`[ERROR]\` line; see the build step log" >> build-comment.md
fi

if [[ "$issues" == *"security floor"* ]]; then
    {
        echo
        echo "A security floor (\`PHP_MIN\` in \`install/install.sh\`, \`NGINX_MIN\` in \`nginx-build/install.sh\`) is newer than what the package repo ships."
        echo "Re-run once the patched packages are published; don't lower the floor to get a green build."
    } >> build-comment.md
fi

[[ -n "${RUN_URL:-}" ]] && printf '\n[Build log](%s)\n' "$RUN_URL" >> build-comment.md
cat build-comment.md >> "$SUMMARY"
