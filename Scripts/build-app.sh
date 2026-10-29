#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
# No explicit destination means a managed local test build. CI/releases set their own.
if [[ -z "${AJAR_OUTPUT_DIR:-}" ]]; then
  exec python3 "${project_dir}/Scripts/dev-app.py" build
fi
output_dir="${AJAR_OUTPUT_DIR}"
app_path="${output_dir}/Ajar.app"
bundle_id="${AJAR_BUNDLE_ID:-io.github.boyongjiong.ajar.mac}"

if [[ -e "$app_path" ]]; then
  print -u2 "Refusing to overwrite existing app: $app_path"
  print -u2 "Set AJAR_OUTPUT_DIR to a new directory for another build."
  exit 1
fi

cd "$project_dir"
python3 "${project_dir}/Scripts/prepare-portless-runtime.py"
# Build both slices even when packaging on an Apple Silicon or Intel host.
build_args=(-c release -debug-info-format none --disable-sandbox --arch arm64 --arch x86_64)
swift build "${build_args[@]}"
binary_dir="$(swift build "${build_args[@]}" --show-bin-path)"
for executable in AjarApp ajar; do
  if [[ ! -x "${binary_dir}/${executable}" ]]; then
    print -u2 "Missing release executable: ${binary_dir}/${executable}"
    exit 1
  fi
done

mkdir -p "${app_path}/Contents/MacOS"
for executable in AjarApp ajar; do
  cp "${binary_dir}/${executable}" "${app_path}/Contents/MacOS/${executable}"
  chmod 755 "${app_path}/Contents/MacOS/${executable}"
done
"${project_dir}/Scripts/verify-universal-app.sh" "$app_path"
cp "${project_dir}/Resources/Info.plist" "${app_path}/Contents/Info.plist"
mkdir -p "${app_path}/Contents/Resources"
swift "${project_dir}/Scripts/legacy-app-icon.swift" generate \
  "${project_dir}/Resources/AppIcon.icns" "${app_path}/Contents/Resources/AppIcon.icns"
resource_bundle="${binary_dir}/Ajar_AjarApp.bundle"
if [[ -d "$resource_bundle" ]]; then
  mkdir -p "${app_path}/Contents/Resources"
  cp -R "$resource_bundle" "${app_path}/Contents/Resources/Ajar_AjarApp.bundle"
else
  print -u2 "Missing generated resource bundle: ${resource_bundle}"
  exit 1
fi
# MIT asks for the copyright and permission notice in every copy, including the built app.
cp "${project_dir}/LICENSE" "${app_path}/Contents/Resources/LICENSE.txt"
mkdir -p "${app_path}/Contents/Resources/Portless"
cp -R "${project_dir}/.build/portless-runtime/." "${app_path}/Contents/Resources/Portless/"
zsh "${project_dir}/Scripts/sign-portless-runtime.sh" "${app_path}/Contents/Resources/Portless"
plutil -replace CFBundleIdentifier -string "$bundle_id" "${app_path}/Contents/Info.plist"
if [[ -n "${AJAR_APP_DISPLAY_NAME:-}" ]]; then
  plutil -replace CFBundleDisplayName -string "$AJAR_APP_DISPLAY_NAME" "${app_path}/Contents/Info.plist"
  plutil -replace CFBundleName -string "$AJAR_APP_DISPLAY_NAME" "${app_path}/Contents/Info.plist"
fi
# Local test builds describe their commit; releases stamp the source with prepare-release.py.
if [[ -n "${AJAR_VERSION:-}" ]]; then
  plutil -replace CFBundleShortVersionString -string "$AJAR_VERSION" "${app_path}/Contents/Info.plist"
fi
swift "${project_dir}/Scripts/legacy-app-icon.swift" verify "${project_dir}/Resources/AppIcon.icns" "$app_path"
# Sign nested code before the bundle, which signs the main executable too.
codesign --force --sign - "${app_path}/Contents/MacOS/ajar"
codesign --force --sign - "$app_path"
codesign --verify --deep --strict --all-architectures "$app_path"
python3 "${project_dir}/Scripts/verify-portless-runtime.py" "${app_path}/Contents/Resources/Portless"
print "Built ad-hoc signed app: $app_path"
