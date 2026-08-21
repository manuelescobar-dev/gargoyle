import { execFileSync } from "node:child_process";
import {
  copyFileSync,
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { homedir, userInfo } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { HUB_PORT, withGargoyleHooks, withoutGargoyleHooks } from "./setup/claude-hooks.ts";
import { type Checks, diagnose } from "./setup/doctor.ts";
import { AGENT_LABEL, PET_LABEL, petPlistFor, plistFor } from "./setup/launch-agent.ts";

// Everything resolves from where this repo actually lives and where this user's
// home actually is. Nothing is baked in. The env vars exist so the installer can
// be exercised against a throwaway directory instead of a real machine.
const home = homedir();
const claudeDir = process.env.CLAUDE_CONFIG_DIR || join(home, ".claude");
const settingsPath = join(claudeDir, "settings.json");
const agentsDir = process.env.GARGOYLE_LAUNCH_AGENTS_DIR || join(home, "Library", "LaunchAgents");
const plistPath = join(agentsDir, `${AGENT_LABEL}.plist`);
const petPlistPath = join(agentsDir, `${PET_LABEL}.plist`);
/// Installed out of the repo, so moving or deleting the checkout doesn't take the
/// creature with it.
const installedApp = join(home, "Applications", "Gargoyle.app");
const builtApp = join(
  dirname(dirname(dirname(fileURLToPath(import.meta.url)))),
  "pet",
  "Gargoyle.app",
);
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
    const { settings, added, alreadyPresent, upgraded } = withGargoyleHooks(readSettings());
    writeSettings(settings);
    if (added.length) console.log(`✓ wired Claude Code hooks: ${added.join(", ")}`);
    if (upgraded.length) console.log(`✓ updated existing hooks: ${upgraded.join(", ")}`);
    if (alreadyPresent.length) console.log(`· already current: ${alreadyPresent.join(", ")}`);

    mkdirSync(agentsDir, { recursive: true });
    mkdirSync(logDir, { recursive: true });
    writeFileSync(
      plistPath,
      // Your PATH, not launchd's: otherwise every source and every reply_to that isn't an
      // absolute path fails with "command not found".
      plistFor({ node: process.execPath, script: hubScript, logDir, path: process.env.PATH }),
    );

    launchctl("bootout", `${domain}/${AGENT_LABEL}`); // ignore failure: usually not loaded yet
    launchctl("bootstrap", domain, plistPath) || launchctl("load", "-w", plistPath);
    // Ask launchd rather than trusting the exit code. `bootstrap` immediately after
    // `bootout` can report success while the service never comes up, and an installer
    // that says "✓" when it didn't work is worse than one that fails loudly.
    const loaded = launchctl("print", `${domain}/${AGENT_LABEL}`);

    console.log(
      loaded
        ? "✓ hub starts at login"
        : `· wrote ${plistPath}, but launchctl wouldn't load it. Run the hub with \`npm start\`.`,
    );

    // The creature is the half you notice is missing after a reboot.
    if (existsSync(builtApp)) {
      rmSync(installedApp, { recursive: true, force: true });
      mkdirSync(dirname(installedApp), { recursive: true });
      cpSync(builtApp, installedApp, { recursive: true });
      writeFileSync(petPlistPath, petPlistFor({ app: installedApp, logDir }));

      launchctl("bootout", `${domain}/${PET_LABEL}`);
      launchctl("bootstrap", domain, petPlistPath) || launchctl("load", "-w", petPlistPath);
      const petLoaded = launchctl("print", `${domain}/${PET_LABEL}`);
      console.log(
        petLoaded
          ? `✓ creature installed to ${installedApp} — it starts at login too`
          : `· installed ${installedApp}, but launchctl wouldn't load it. Open it yourself.`,
      );
    } else {
      console.log("· no creature built yet — run `pet/make-app.sh`, then this again");
    }
    // Found the hard way: Claude Code reads hooks when a session starts, so the session
    // you ran this from will never fire them. Without saying so, the first five minutes
    // are "I installed it and nothing happened".
    console.log(
      "\nHooks take effect in your NEXT Claude Code session — the one you ran this from\n" +
        "already loaded its hooks at startup.\n\n" +
        "Start a new session, then `gargoyle doctor` to confirm events are arriving.",
    );
    break;
  }

  case "uninstall": {
    writeSettings(withoutGargoyleHooks(readSettings()));
    console.log("✓ removed Gargoyle's hooks from Claude Code");

    for (const [label, path] of [
      [AGENT_LABEL, plistPath],
      [PET_LABEL, petPlistPath],
    ] as const) {
      launchctl("bootout", `${domain}/${label}`) || launchctl("unload", "-w", path);
      if (existsSync(path)) rmSync(path);
    }
    rmSync(installedApp, { recursive: true, force: true });
    console.log("✓ removed both launch agents and the installed app");
    console.log("\nYour other hooks and settings were left alone.");
    break;
  }

  case "doctor": {
    const health = await reachable("/health");
    const hooks = JSON.stringify(readSettings());

    const checks: Checks = {
      hubUp: health !== null,
      hooksWired: hooks.includes("/event"),
      agentLoaded: launchctl("print", `${domain}/${AGENT_LABEL}`),
      creatureRunning: launchctl("print", `${domain}/${PET_LABEL}`),
      eventsSeen: health ? ((await health.json()) as { eventsReceived: number }).eventsReceived : 0,
    };

    const { ok, lines } = diagnose(checks);
    for (const line of lines) console.log(line);
    // `process.exit` ends things, but the linter can't know that.
    process.exit(ok ? 0 : 1);
    break;
  }

  default:
    console.log(`gargoyle — connect Claude Code to the hub

  install     wire the hooks and run the hub at login
  uninstall   undo both, leaving your other settings alone
  doctor      check it's actually working

Everything is idempotent, and install backs up your settings first.`);
}
