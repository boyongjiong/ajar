#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
output_dir="${AJAR_OUTPUT_DIR:-${project_dir}/dist}"
app_path="${output_dir}/Ajar.app"
zip_path="${output_dir}/Ajar-notarization.zip"
release_zip="${output_dir}/Ajar-release.zip"

if [[ -z "${AJAR_APP_IDENTITY:-}" || -z "${AJAR_NOTARY_PROFILE:-}" || -z "${AJAR_BUNDLE_ID:-}" ]]; then
  print -u2 "Set AJAR_APP_IDENTITY, AJAR_NOTARY_PROFILE, and AJAR_BUNDLE_ID explicitly."
  exit 1
fi
if [[ ! -d "$app_path" ]]; then
  print -u2 "Build the app first: $app_path"
  exit 1
fi
if [[ -e "$zip_path" || -e "$release_zip" ]]; then
  print -u2 "Refusing to overwrite an existing zip in $output_dir. Use a new AJAR_OUTPUT_DIR."
  exit 1
fi
actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${app_path}/Contents/Info.plist")"
if [[ "$actual_bundle_id" != "$AJAR_BUNDLE_ID" ]]; then
  print -u2 "Bundle ID mismatch: built $actual_bundle_id, requested $AJAR_BUNDLE_ID."
  exit 1
fi

"${project_dir}/Scripts/verify-universal-app.sh" "$app_path"

# Sign every nested executable first, using architecture-specific V8 permissions.
zsh "${project_dir}/Scripts/sign-portless-runtime.sh" "${app_path}/Contents/Resources/Portless" "$AJAR_APP_IDENTITY"
# The CLI is nested code; signing the bundle also signs AjarApp.
codesign --force --options runtime --timestamp --sign "$AJAR_APP_IDENTITY" "${app_path}/Contents/MacOS/ajar"
codesign --force --options runtime --timestamp --sign "$AJAR_APP_IDENTITY" "$app_path"
codesign --verify --deep --strict --all-architectures --verbose=2 "$app_path"
python3 "${project_dir}/Scripts/verify-portless-runtime.py" "${app_path}/Contents/Resources/Portless"
ditto -c -k --keepParent "$app_path" "$zip_path"
notary_args=(--keychain-profile "$AJAR_NOTARY_PROFILE")
if [[ -n "${AJAR_NOTARY_KEYCHAIN:-}" ]]; then
  notary_args+=(--keychain "$AJAR_NOTARY_KEYCHAIN")
fi
xcrun notarytool submit "$zip_path" "${notary_args[@]}" --wait
xcrun stapler staple "$app_path"
xcrun stapler validate "$app_path"
spctl --assess --type execute --verbose=2 "$app_path"
ditto -c -k --keepParent "$app_path" "$release_zip"
print "Notarized release: $release_zip"
