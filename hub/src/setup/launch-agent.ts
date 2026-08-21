/**
 * The LaunchAgent that keeps the hub running.
 *
 * Every path is resolved at install time from wherever the user cloned the repo —
 * nothing here is specific to any one machine.
 */

export const AGENT_LABEL = "dev.gargoyle.hub";
export const PET_LABEL = "dev.gargoyle.pet";

/** An unescaped `&` in a path produces a plist macOS silently refuses to load. */
const xml = (value: string) =>
  value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

export function plistFor({
  node,
  script,
  logDir,
}: {
  node: string;
  script: string;
  logDir: string;
}): string {
  return agentPlist({ label: AGENT_LABEL, args: [node, script], logDir, name: "hub" });
}

/** The creature. Same mechanism, but it launches an app bundle rather than a script. */
export function petPlistFor({ app, logDir }: { app: string; logDir: string }): string {
  return agentPlist({
    label: PET_LABEL,
    args: [`${app}/Contents/MacOS/Gargoyle`],
    logDir,
    name: "pet",
  });
}

function agentPlist({
  label,
  args,
  logDir,
  name,
}: {
  label: string;
  args: string[];
  logDir: string;
  name: string;
}): string {
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${xml(label)}</string>
  <key>ProgramArguments</key>
  <array>
${args.map((arg) => `    <string>${xml(arg)}</string>`).join("\n")}
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${xml(`${logDir}/${name}.log`)}</string>
  <key>StandardErrorPath</key>
  <string>${xml(`${logDir}/${name}.error.log`)}</string>
</dict>
</plist>
`;
}
