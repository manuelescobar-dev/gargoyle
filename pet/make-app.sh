#!/bin/sh
# Assembles Gargoyle.app.
#
# No Xcode project: a .app is a directory with a plist in it, and generating an
# .xcodeproj to produce one would be more machinery than the thing it builds.
#
# The bundle isn't cosmetic. It gets us LSUIElement instead of a runtime call, a bundle
# identifier for macOS to attribute permissions to, and a home for personas that doesn't
# depend on sitting inside the repo.
set -eu

cd "$(dirname "$0")"
CONFIG=${1:-release}
APP="$PWD/Gargoyle.app"

echo "building ($CONFIG)…"
swift build -c "$CONFIG" >/dev/null

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/$CONFIG/Gargoyle" "$APP/Contents/MacOS/Gargoyle"

# Personas travel with the app rather than being hunted for on disk.
cp -R ../creatures "$APP/Contents/Resources/creatures"
rm -rf "$APP/Contents/Resources/creatures"/*/previews

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>              <string>Gargoyle</string>
  <key>CFBundleDisplayName</key>       <string>Gargoyle</string>
  <key>CFBundleIdentifier</key>        <string>dev.gargoyle.pet</string>
  <key>CFBundleExecutable</key>        <string>Gargoyle</string>
  <key>CFBundlePackageType</key>       <string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key>           <string>1</string>
  <key>LSMinimumSystemVersion</key>    <string>14.0</string>
  <!-- No Dock icon, no Cmd-Tab entry. It's a creature, not an application you switch to. -->
  <key>LSUIElement</key>               <true/>
  <!-- Asked for on first use of push-to-talk, never at launch. -->
  <key>NSMicrophoneUsageDescription</key>
  <string>So you can answer the creature by holding a key and speaking, instead of typing.</string>
  <key>NSUserNotificationAlertStyle</key>       <string>banner</string>
  <key>NSSpeechRecognitionUsageDescription</key>
  <string>To turn what you say into an answer. Recognition happens on this Mac where supported.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature: enough for macOS to give the bundle a stable identity, which is what
# TCC attributes Automation permission to. Not distribution signing.
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "  (unsigned — Automation prompts may repeat)"

echo "✓ $APP"
