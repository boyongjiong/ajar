cask "ajar" do
  version "0.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/boyongjiong/ajar/releases/download/v#{version}/Ajar-release.zip"
  name "Ajar"
  desc "Menu bar port manager showing which project owns each localhost port"
  homepage "https://github.com/boyongjiong/ajar"

  depends_on macos: :sonoma

  app "Ajar.app"
  binary "#{appdir}/Ajar.app/Contents/MacOS/ajar"

  caveats <<~EOS
    For complete removal, use Ajar > Settings > About > Uninstall Ajar.
    brew uninstall only removes the app and CLI; background services, certificates
    and settings may remain. If already removed, reinstall Ajar to run its uninstaller.
  EOS

  zap trash: [
    "~/Library/Saved Application State/io.github.boyongjiong.ajar.mac.savedState",
  ]
end
