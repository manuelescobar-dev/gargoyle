/**
 * The LaunchAgents that keep the hub and the creature running.
 *
 * Every path is resolved at install time from wherever the user cloned the repo — nothing
 * here is specific to any one machine.
 */

export const AGENT_LABEL = "dev.gargoyle.hub";
export const PET_LABEL = "dev.gargoyle.pet";

/** An unescaped `&` in a path produces a plist macOS silently refuses to load. */
const xml = (value: string) =>
  value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

type AgentSpec = {
  label: string;
  args: string[];
  logDir: string;
  /** Which log file it writes to. */
  name: string;
  /** PATH to run with. Omitted entirely rather than set empty when unknown. */
  path?: string;
};

function agentPlist({ label, args, logDir, name, path }: AgentSpec): string {
  const environment = path
    ? `  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>${xml(path)}</string>
  </dict>
`
    : "";

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
${environment}  <key>RunAtLoad</key>
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

/**
 * `path` is the PATH you had when you installed.
 *
 * launchd gives an agent a minimal PATH with no nvm, no Homebrew and no `~/bin` in it — so
 * every declared source and every `reply_to` that isn't an absolute path dies with
 * "command not found", and the user has no idea why. Capturing your PATH at install time
 * is what makes `reply_to: "openclaw agent ..."` work the way anyone would expect.
 */
export function plistFor({
  node,
  script,
  logDir,
  path,
}: {
  node: string;
  script: string;
  logDir: string;
  path?: string;
}): string {
  return agentPlist({ label: AGENT_LABEL, args: [node, script], logDir, name: "hub", path });
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
