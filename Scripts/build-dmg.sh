#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
repo_dir=${script_dir:h}
version=${1:-development}
app_path="$repo_dir/dist/OPPOPods.app"
output_path="$repo_dir/dist/OPPO-Pods-for-macOS-$version.dmg"
staging_dir=$(mktemp -d "${TMPDIR:-/tmp}/oppopods-dmg.XXXXXX")

cleanup() {
    rm -rf "$staging_dir"
}
trap cleanup EXIT

if [[ ! -d "$app_path" ]]; then
    "$repo_dir/Scripts/build-app.sh" >&2
fi

cp -R "$app_path" "$staging_dir/OPPOPods.app"
ln -s /Applications "$staging_dir/Applications"

rm -f "$output_path"
hdiutil create \
    -volname "OPPO Pods for macOS" \
    -srcfolder "$staging_dir" \
    -format UDZO \
    -ov \
    "$output_path" >&2

hdiutil verify "$output_path" >&2
echo "$output_path"
