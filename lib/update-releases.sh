#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-Cairnstew/uup-dump-build-and-get-windows-iso}"
LOCKFILE="${2:-$(dirname "$0")/../releases.lock}"

if ! command -v gh &>/dev/null; then
  echo "ERROR: 'gh' (GitHub CLI) is required. Install it from https://cli.github.com/" >&2
  exit 1
fi

gh auth status &>/dev/null || {
  echo "ERROR: Not authenticated with GitHub CLI. Run 'gh auth login' first." >&2
  exit 1
}

echo "Fetching releases for $REPO ..."

# Get all releases with their assets
releases=$(gh release list \
  --repo "$REPO" \
  --limit 50 \
  --json tagName,isLatest,isPrerelease,createdAt \
  2>/dev/null)

if [ -z "$releases" ] || [ "$releases" = "[]" ]; then
  echo "No releases found." >&2
  exit 1
fi

echo "Found $(echo "$releases" | jq length) releases. Fetching asset details..."

# For each release, fetch full asset info including digests
full_releases=$(echo "$releases" | jq -c '.[]' | while read -r rel; do
  tag=$(echo "$rel" | jq -r '.tagName')
  assets=$(gh release view "$tag" \
    --repo "$REPO" \
    --json assets \
    --jq '.assets' \
    2>/dev/null)
  echo "$rel" | jq --argjson assets "$assets" '. + {assets: $assets}'
done | jq -s '.')

LOCKFILE_DIR=$(dirname "$LOCKFILE")
mkdir -p "$LOCKFILE_DIR"

echo "$full_releases" > "$LOCKFILE"
echo "Wrote releases.lock ($(wc -c < "$LOCKFILE") bytes)"
echo "Done."
