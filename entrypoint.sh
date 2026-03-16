#!/bin/bash
set -euo pipefail

# Uncomment for debugging
#set -x

setOutput() {
  echo "${1}=${2}" >> "${GITHUB_OUTPUT}"
}

# https://nvd.nist.gov/vuln/detail/cve-2022-24765
git config --global --add safe.directory /github/workspace

if [[ -z "${INPUT_TOKEN}" ]]; then
  echo "::error::Missing required input: token"
  exit 1
fi

(
  set +x
  git config --global url."https://x-access-token:${INPUT_TOKEN}@github.com/".insteadOf "https://github.com/"
)

echo "Fetching Tags"
git fetch --tags

# Find the current version
echo "Finding current version"
versionFmt="^v?[0-9]+\.[0-9]+\.[0-9]+$"
version="$(git for-each-ref --sort=-v:refname --format '%(refname:lstrip=2)' refs/tags/ | grep -E "$versionFmt" | head -n 1 || true)"
echo "Found Version: ${version}"

# Set default tag if none is found
version="${version:="v0.0.1"}"
setOutput "currentVersion" "$version"
echo "Current Version: ${version}"

# Bump the version
bump="${INPUT_BUMP:-patch}"
case "$bump" in
  major) newVersion=$(echo "${version}" | awk -F. -v OFS=. '{
    prefix=""; if ($1 ~ /^v/) { prefix="v"; $1=substr($1,2) }
    $1 += 1; $2 = 0; $3 = 0; print prefix $0}') ;;
  minor) newVersion=$(echo "${version}" | awk -F. -v OFS=. '{$2 += 1; $3 = 0; print}') ;;
  patch) newVersion=$(echo "${version}" | awk -F. -v OFS=. '{$3 += 1; print}') ;;
  *) echo "::error::Invalid bump type: ${bump}. Must be major, minor, or patch"; exit 1 ;;
esac
echo "New Version: ${newVersion}"
setOutput "newVersion" "$newVersion"

# Set and push the new version tag
echo "Tagging Version: ${newVersion}"
git tag "$newVersion"

echo "Pushing Tag: ${newVersion}"
git push origin "$newVersion"
