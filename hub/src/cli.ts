import { execFileSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { homedir, userInfo } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { AGENT_LABEL, plistFor } from "./setup/launch-agent.ts";
import { type Checks, diagnose } from "./setup/doctor.ts";
import { HUB_PORT, withGargoyleHooks, withoutGargoyleHooks } from "./setup/claude-hooks.ts";

// Everything resolves from where this repo actually lives and where this user's
// home actually is. Nothing is baked in. The env vars exist so the installer can
// be exercised against a throwaway directory instead of a real machine.
const home = homedir();
const claudeDir = process.env.CLAUDE_CONFIG_DIR || join(home, ".claude");
const settingsPath = join(claudeDir, "settings.json");
const agentsDir = process.env.GARGOYLE_LAUNCH_AGENTS_DIR || join(home, "Library", "LaunchAgents");
const plistPath = join(agentsDir, `${AGENT_LABEL}.plist`);
const logDir = join(home, "Library", "Logs", "gargoyle");
const hubScript = join(dirname(fileURLToPath(import.meta.url)), "index.ts");

function readSettings(): Record<string, unknown> {
  if (!existsSync(settingsPath)) return {};
  const raw = readFileSync(settingsPath, "utf8").trim();
  if (!raw) return {};
  try {
    return JSON.parse(raw);
  } catch (error) {
    // Never overwrite a config we couldn't parse. That's the worst thing this could do.
    console.error(`✗ ${settingsPath} isn't valid JSON, so nothing was changed.`);
    console.error(`  ${(error as Error).message}`);
    process.exit(1);
  }
}

function writeSettings(settings: Record<string, unknown>): void {
  mkdirSync(claudeDir, { recursive: true });
  if (existsSync(settingsPath)) copyFileSync(settingsPath, `${settingsPath}.bak`);
  writeFileSync(settingsPath, `${JSON.stringify(settings, null, 2)}\n`);
}

const launchctl = (...args: string[]): boolean => {
  // For exercising the installer without touching a real launchd, and for people
  // who'd rather supervise the hub themselves.
  if (process.env.GARGOYLE_NO_LAUNCHCTL) return false;
  try {
    execFileSync("launchctl", args, { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
};

const domain = `gui/${userInfo().uid}`;

async function reachable(path: string): Promise<Response | null> {
  try {
    const res = await fetch(`http://127.0.0.1:${HUB_PORT}${path}`, {
      signal: AbortSignal.timeout(1500),
    });
    return res.ok ? res : null;
  } catch {
    return null;
  }
}

switch (process.argv[2]) {
  case "install": {
    const { settings, added, alreadyPresent } = withGargoyleHooks(readSettings());
    writeSettings(settings);
    if (added.length) console.log(`✓ wired Claude Code hooks: ${added.join(", ")}`);
    if (alreadyPresent.length) console.log(`· already wired: ${alreadyPresent.join(", ")}`);

    mkdirSync(agentsDir, { recursive: true });
    mkdirSync(logDir, { recursive: true });
    writeFileSync(plistPath, plistFor({ node: process.execPath, script: hubScript, logDir }));

    launchctl("bootout", `${domain}/${AGENT_LABEL}`); // ignore failure: usually not loaded yet
    const loaded = launchctl("bootstrap", domain, plistPath) || launchctl("load", "-w", plistPath);

    console.log(
      loaded
        ? "✓ hub installed as a launch agent — it starts at login"
        : `· wrote ${plistPath}, but launchctl wouldn't load it. Run the hub with \`npm start\`.`,
    );
    console.log("\nRun an agent, then `gargoyle doctor` to check events are arriving.");
    break;
  }

  case "uninstall": {
    writeSettings(withoutGargoyleHooks(readSettings()));
    console.log("✓ removed Gargoyle's hooks from Claude Code");

    launchctl("bootout", `${domain}/${AGENT_LABEL}`) || launchctl("unload", "-w", plistPath);
    if (existsSync(plistPath)) rmSync(plistPath);
    console.log("✓ removed the launch agent\n\nYour other hooks and settings were left alone.");
    break;
  }

  case "doctor": {
    const health = await reachable("/health");
    const hooks = JSON.stringify(readSettings());

    const checks: Checks = {
      hubUp: health !== null,
      hooksWired: hooks.includes("/event"),
      agentLoaded: launchctl("print", `${domain}/${AGENT_LABEL}`),
      eventsSeen: health ? ((await health.json()) as { eventsReceived: number }).eventsReceived : 0,
    };

    const { ok, lines } = diagnose(checks);
    for (const line of lines) console.log(line);
    process.exit(ok ? 0 : 1);
  }

  default:
    console.log(`gargoyle — connect Claude Code to the hub

  install     wire the hooks and run the hub at login
  uninstall   undo both, leaving your other settings alone
  doctor      check it's actually working

Everything is idempotent, and install backs up your settings first.`);
}
