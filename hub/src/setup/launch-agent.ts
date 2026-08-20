/**
 * The LaunchAgent that keeps the hub running.
 *
 * Every path is resolved at install time from wherever the user cloned the repo —
 * nothing here is specific to any one machine.
 */

export const AGENT_LABEL = "dev.gargoyle.hub";

/** An unescaped `&` in a path produces a plist macOS silently refuses to load. */
const xml = (value: string) =>
  value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

export function plistFor({
  node,
  script,
  logDir,
}: { node: string; script: string; logDir: string }): string {
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${xml(AGENT_LABEL)}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${xml(node)}</string>
    <string>${xml(script)}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${xml(`${logDir}/hub.log`)}</string>
  <key>StandardErrorPath</key>
  <string>${xml(`${logDir}/hub.error.log`)}</string>
</dict>
</plist>
`;
}
