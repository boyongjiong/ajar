#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h:h}"
test_dir="$(mktemp -d /private/tmp/ajar-diagnostics-ui.XXXXXX)"
app="$test_dir/AjarDiagnosticsTest.app"
mkdir -p "$app/Contents/MacOS"
swiftc -emit-library -emit-module -module-name AjarCore Sources/AjarCore/FailureDiagnostics.swift \
  -o "$test_dir/libAjarCore.dylib" -emit-module-path "$test_dir/AjarCore.swiftmodule"
swiftc -I "$test_dir" -L "$test_dir" -lAjarCore -Xlinker -rpath -Xlinker "$test_dir" \
  Sources/AjarApp/ErrorDiagnosticsView.swift Tests/DiagnosticsUITests/main.swift \
  -o "$app/Contents/MacOS/AjarDiagnosticsTest"
plutil -create xml1 "$app/Contents/Info.plist"
plutil -insert CFBundleExecutable -string AjarDiagnosticsTest "$app/Contents/Info.plist"
plutil -insert CFBundleIdentifier -string io.github.boyongjiong.ajar.diagnostics-test "$app/Contents/Info.plist"
plutil -insert CFBundleName -string AjarDiagnosticsTest "$app/Contents/Info.plist"
print "UI fixture: $app"
"$app/Contents/MacOS/AjarDiagnosticsTest"
