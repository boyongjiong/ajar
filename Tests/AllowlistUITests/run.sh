#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h:h}"
test_dir="$(mktemp -d /private/tmp/ajar-allowlist-ui.XXXXXX)"
app="$test_dir/AjarAllowlistTest.app"
mkdir -p "$app/Contents/MacOS"
swiftc -swift-version 6 -emit-library -emit-module -module-name AjarCore Sources/AjarCore/Localization.swift \
  -o "$test_dir/libAjarCore.dylib" -emit-module-path "$test_dir/AjarCore.swiftmodule"
swiftc -swift-version 6 -I "$test_dir" -L "$test_dir" -lAjarCore -Xlinker -rpath -Xlinker "$test_dir" \
  Sources/AjarApp/AppSettings.swift Sources/AjarApp/AppAppearance.swift \
  Sources/AjarApp/PortAllowlistInput.swift Tests/AllowlistUITests/main.swift \
  -o "$app/Contents/MacOS/AjarAllowlistTest"
plutil -create xml1 "$app/Contents/Info.plist"
plutil -insert CFBundleExecutable -string AjarAllowlistTest "$app/Contents/Info.plist"
plutil -insert CFBundleIdentifier -string io.github.boyongjiong.ajar.allowlist-test "$app/Contents/Info.plist"
plutil -insert CFBundleName -string AjarAllowlistTest "$app/Contents/Info.plist"
print "UI fixture: $app"
"$app/Contents/MacOS/AjarAllowlistTest"
