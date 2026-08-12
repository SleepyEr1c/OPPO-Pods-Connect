#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
repo_dir=${script_dir:h}
app_dir="$repo_dir/dist/OPPOPods.app"
legacy_app_dir="$repo_dir/dist/OppoPods.app"
contents_dir="$app_dir/Contents"

cd "$repo_dir"
swift build -c release

rm -rf "$app_dir" "$legacy_app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$repo_dir/.build/release/OppoPodsMac" "$contents_dir/MacOS/OppoPodsMac"
cp "$repo_dir/AppBundle/Info.plist" "$contents_dir/Info.plist"
cp "$repo_dir/AppBundle/Assets/AppIcon.icns" "$contents_dir/Resources/AppIcon.icns"
cp "$repo_dir/Resources/device_models.json" "$contents_dir/Resources/device_models.json"
cp "$repo_dir/Resources/eq_mode_names.json" "$contents_dir/Resources/eq_mode_names.json"
cp "$repo_dir/Resources/eq_mode_names.en.json" "$contents_dir/Resources/eq_mode_names.en.json"

codesign --force --sign - \
    --entitlements "$repo_dir/AppBundle/OppoPodsMac.entitlements" \
    "$app_dir"

echo "$app_dir"
