# Source-of-truth Homebrew cask for Leap Widget. scripts/release.sh seeds this
# into antavik/homebrew-apps (Casks/leap-widget.rb) on first publish and
# rewrites the version + sha256 lines on every release. Later edits to anything
# else here have to be copied to the tap by hand.
cask "leap-widget" do
  version "0.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/antavik/Leap-widget/releases/download/v#{version}/Leap-Widget-#{version}.dmg"
  name "Leap Widget"
  desc "Calendar month widget for the Desktop and Notification Center"
  homepage "https://github.com/antavik/Leap-widget"

  depends_on macos: :sonoma

  app "Leap Widget.app"

  # Strip Homebrew's quarantine so the first launch skips the "downloaded from
  # the internet" confirmation; the app is notarized and stapled either way.
  # Runs on the staged copy, before the move. A failure only costs that prompt.
  preflight_steps do
    run "/bin/sh",
        args: [
          "-c",
          'err=$(/usr/bin/xattr -dr com.apple.quarantine "$1" 2>&1 >/dev/null) || ' \
          'echo "Warning: could not remove quarantine from $1 ($(printf "%s\n" "$err" | head -n 1)); ' \
          'macOS may ask to confirm the first launch" >&2',
          "sh",
          "{{staged_path}}/Leap Widget.app",
        ]
  end

  uninstall quit: "com.antavik.leapwidget"

  zap trash: [
    "~/Library/Application Scripts/com.antavik.leapwidget",
    "~/Library/Application Scripts/com.antavik.leapwidget.widget",
    "~/Library/Caches/com.antavik.leapwidget",
    "~/Library/Containers/com.antavik.leapwidget",
    "~/Library/Containers/com.antavik.leapwidget.widget",
    "~/Library/Preferences/com.antavik.leapwidget.plist",
    "~/Library/Saved Application State/com.antavik.leapwidget.savedState",
  ]
end
