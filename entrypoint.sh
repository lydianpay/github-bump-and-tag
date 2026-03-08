#!/bin/bash

# Uncomment for debugging
#set -x

setOutput() {
  echo "${1}=${2}" >> "${GITHUB_OUTPUT}"
}

# https://nvd.nist.gov/vuln/detail/cve-2022-24765
git config --global --add safe.directory /github/workspace
git config --global url."https://x-access-token:${INPUT_TOKEN}@github.com/".insteadOf "https://github.com/"

echo "Fetching Tags"
git fetch --tags --recurse-submodules=no

# Find the current version
echo "Finding current version"
versionFmt="^v?[0-9]+\.[0-9]+\.[0-9]+$"
version="$(git for-each-ref --sort=-v:refname --format '%(refname:lstrip=2)' | grep -E "$versionFmt" | head -n 1)"
echo "Found Version: ${version}"

# Set default tag if none is found
version="${version:="v0.0.0"}"
setOutput "currentVersion" "$version"
echo "Current Version: ${version}"

# Bump the patch version
newVersion=$(echo "${version}" | awk -F. -v OFS=. '{$NF += 1 ; print}')
echo "New Version: ${newVersion}"
setOutput "newVersion" "$newVersion"

# Set and push the new version tag
echo "Tagging Version: ${newVersion}"
git tag -f "$newVersion"

echo "Pushing Tag: ${newVersion}"
git push -f origin "$newVersion"
