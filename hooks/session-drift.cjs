// Session-start drift check for the SAP/ABAP agent workspace.
//
// Reads the live agent/skill/tool inventory and compares it with the last snapshot.
// Emits additionalContext ONLY when something changed, so an unchanged session pays
// nothing. Returns {} when there is nothing to report.
//
// Design rules:
// - Detection only. This script never edits an agent, skill, or config file.
// - Facts only. Every line it prints comes from a file it read this run.
// - Fail quiet. A crash must not block the session, so main() is wrapped.
// - No secrets in output. Counts and names only; never an env value.

const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');

const HOME = os.homedir();
const COPILOT = path.join(HOME, '.copilot');
const STATE_DIR = path.join(COPILOT, 'state');
const SNAPSHOT = path.join(STATE_DIR, 'surface.json');
const PREV = path.join(STATE_DIR, 'surface.prev.json');
const ROSTER = path.join(COPILOT, 'roster.json');
// APPDATA is not guaranteed: when it is unset the old expression produced a RELATIVE path
// ('Code\\User\\mcp.json'), the read failed, and the snapshot then recorded "zero MCP servers" as a
// measured fact. The next session reported all five as newly added. lesson-capture.cjs already had
// this fallback; this file did not. Measured 2026-11-15 with APPDATA cleared.
const APPDATA = process.env.APPDATA || path.join(HOME, 'AppData', 'Roaming');
const MCP_JSON = path.join(APPDATA, 'Code', 'User', 'mcp.json');
// The Copilot CLI's own list. Referenced by serverNamesCli below - it was not declared at all in the
// first version of that function, so buildSurface() threw on every run, the catch turned it into an
// empty object, and the snapshot was never written. `node --check` cannot see a missing identifier.
const MCP_CLI_JSON = path.join(COPILOT, 'mcp-config.json');
const EXT_DIR = path.join(HOME, '.vscode', 'extensions');

function readJson(file) {
    let text;
    try {
        text = fs.readFileSync(file, 'utf8');
    } catch {
        return null;
    }

    // Strip a UTF-8 BOM. PowerShell 5.1 `Set-Content -Encoding UTF8` and Notepad both
    // write one, and JSON.parse rejects it. Without this the snapshot reads as null and
    // drift detection silently disables itself — the worst possible failure mode.
    if (text.charCodeAt(0) === 0xfeff) text = text.slice(1);

    // Strict JSON first. Extension manifests and roster.json are plain JSON, and a
    // JSONC cleanup pass can corrupt valid content (a trailing-comma regex will also
    // match inside string values). Only fall back to cleanup when strict parsing fails.
    try {
        return JSON.parse(text);
    } catch {
        /* fall through to JSONC handling for editors that allow comments */
    }

    const cleaned = text
        .split(/\r?\n/)
        .filter((line) => !/^\s*\/\//.test(line))
        .join('\n')
        .replace(/\/\*[\s\S]*?\*\//g, '');

    try {
        return JSON.parse(cleaned);
    } catch {
        try {
            return JSON.parse(cleaned.replace(/,(\s*[}\]])/g, '$1'));
        } catch {
            return null;
        }
    }
}

function listSkillFolders(root) {
    try {
        return fs
            .readdirSync(root, { withFileTypes: true })
            .filter((d) => d.isDirectory())
            .filter((d) => fs.existsSync(path.join(root, d.name, 'SKILL.md')))
            .map((d) => d.name)
            .sort();
    } catch {
        return [];
    }
}

function listAgents() {
    try {
        return fs
            .readdirSync(path.join(COPILOT, 'agents'))
            .filter((f) => f.endsWith('.agent.md'))
            .map((f) => f.replace(/\.agent\.md$/, ''))
            .sort();
    } catch {
        return [];
    }
}

// Count tools an extension contributes, so a surface change is visible even when the
// extension is not an MCP server.
function extensionToolCounts() {
    const out = {};
    let entries = [];
    try {
        entries = fs.readdirSync(EXT_DIR, { withFileTypes: true }).filter((d) => d.isDirectory());
    } catch {
        return out;
    }
    for (const e of entries) {
        const pkg = path.join(EXT_DIR, e.name, 'package.json');
        const json = readJson(pkg);
        if (!json) continue;
        const tools = Array.isArray(json?.contributes?.languageModelTools)
            ? json.contributes.languageModelTools.length
            : 0;
        if (tools > 0) {
            const id = `${json.publisher || '?'}.${json.name || e.name}`;
            out[id] = tools;
        }
    }
    return out;
}

function serverNames() {
    const cfg = readJson(MCP_JSON);
    if (!cfg || !cfg.servers) return [];
    return Object.keys(cfg.servers).sort();
}

// The Copilot CLI keeps its own list in ~/.copilot/mcp-config.json, and VS Code imports that file as a
// discovery source by default. Snapshotting only the VS Code file meant a server added to the CLI
// produced no drift line, while it still changed what the tool picker offered.
function serverNamesCli() {
    const cfg = readJson(MCP_CLI_JSON);
    if (!cfg || !cfg.mcpServers) return [];
    return Object.keys(cfg.mcpServers).sort();
}

function buildSurface() {
    return {
        takenAt: new Date().toISOString(),
        agents: listAgents(),
        skills: {
            dotAgents: listSkillFolders(path.join(HOME, '.agents', 'skills')),
            dotCopilot: listSkillFolders(path.join(COPILOT, 'skills')),
        },
        mcpServers: serverNames(),
        mcpServersCli: serverNamesCli(),
        extensionTools: extensionToolCounts(),
    };
}

function diffList(label, before, after, lines) {
    const added = after.filter((x) => !before.includes(x));
    const removed = before.filter((x) => !after.includes(x));
    if (added.length) lines.push(`${label} added: ${added.join(', ')}`);
    if (removed.length) lines.push(`${label} removed: ${removed.join(', ')}`);
}

function diffMap(label, before, after, lines) {
    for (const key of Object.keys(after)) {
        if (!(key in before)) lines.push(`${label} added: ${key} (${after[key]} tools)`);
        else if (before[key] !== after[key]) {
            lines.push(`${label} changed: ${key} (${before[key]} -> ${after[key]} tools)`);
        }
    }
    for (const key of Object.keys(before)) {
        if (!(key in after)) lines.push(`${label} removed: ${key}`);
    }
}

// Roster coverage: an agent that is in no roster list is undeclared. Report names only.
function rosterCoverage(surface, lines) {
    const roster = readJson(ROSTER);
    if (!roster) return;
    const known = [];
    // File stems only: the surface lists installed agent FILES. Guarded because a roster entry that
    // carried only a display name would push `undefined` into the set and be reported as an agent
    // that does not exist.
    for (const d of roster.delegatable || []) {
        if (!d) continue;
        if (d.file) known.push(d.file);
        for (const f of d.files || []) if (f) known.push(f);
    }
    for (const g of roster.not_delegatable || []) {
        if (!g) continue;
        if (g.file) known.push(g.file);
        for (const f of g.files || []) if (f) known.push(f);
    }
    const undeclared = surface.agents.filter((a) => !known.includes(a));
    const dangling = known.filter((a) => !surface.agents.includes(a));
    if (undeclared.length) {
        lines.push(`agents not classified in roster.json: ${undeclared.join(', ')}`);
    }
    if (dangling.length) {
        lines.push(`roster.json names agents that do not exist: ${dangling.join(', ')}`);
    }
}

function main() {
    const surface = buildSurface();
    // Guarded, because an unwritable state folder used to throw here and the caller's catch returned
    // {} - so the session reported no drift at all, including drift it had already been able to see.
    // The snapshot write below has its own guard; failing to create the folder must cost the snapshot,
    // not the report.
    try {
        fs.mkdirSync(STATE_DIR, { recursive: true });
    } catch (e) {
        try {
            process.stderr.write(`session-drift: cannot create ${STATE_DIR} (${(e && e.code) || 'error'}); drift will not be compared against a snapshot\n`);
        } catch { /* stderr is best effort */ }
    }

    const prev = readJson(SNAPSHOT);
    // "No previous snapshot" and "a previous snapshot I could not parse" are different facts, and the
    // old code treated both as a first run. A half-written file - the snapshot was written with a
    // single non-atomic writeFileSync - therefore disabled drift detection for that session and was
    // then overwritten, so the mistake removed its own evidence. Measured 2026-11-15: a truncated
    // snapshot plus a deliberately added agent produced '{}', exit 0, and no drift line.
    const hadSnapshotFile = fs.existsSync(SNAPSHOT);
    const lines = [];
    if (hadSnapshotFile && !prev) {
        lines.push('previous surface snapshot was unreadable and has been replaced; this session cannot report what changed since it was taken');
    }

    if (prev) {
        diffList('agents', prev.agents || [], surface.agents, lines);
        diffList('.agents skill', prev.skills?.dotAgents || [], surface.skills.dotAgents, lines);
        diffList('.copilot skill', prev.skills?.dotCopilot || [], surface.skills.dotCopilot, lines);
        diffList('MCP server', prev.mcpServers || [], surface.mcpServers, lines);
        diffList('MCP server (CLI)', prev.mcpServersCli || [], surface.mcpServersCli, lines);
        diffMap('extension tool set', prev.extensionTools || {}, surface.extensionTools, lines);
    }

    rosterCoverage(surface, lines);

    // Rotate snapshot: keep the previous one for diagnosis of a missed change.
    if (prev) {
        try {
            fs.writeFileSync(PREV, JSON.stringify(prev, null, 2));
        } catch {
            /* rotation is best effort */
        }
    }
    // Written through a temporary file and renamed, so an interrupted write cannot leave a truncated
    // snapshot that silently disables the next comparison.
    try {
        const tmp = `${SNAPSHOT}.tmp`;
        fs.writeFileSync(tmp, JSON.stringify(surface, null, 2));
        fs.renameSync(tmp, SNAPSHOT);
    } catch {
        /* a snapshot that cannot be written must not block the session */
    }

    if (lines.length === 0) {
        process.stdout.write('{}');
        return;
    }

    const context = [
        'SAP/ABAP workspace surface drift detected at session start.',
        'Facts read from live config, extension manifests, and roster.json this run:',
        ...lines.map((l) => `- ${l}`),
        'Report these to the user. Do not edit any agent, skill, or config file to resolve them;',
        'a human decides. An agent absent from roster.json is NOT delegatable until it is added.',
    ].join('\n');

    // The product reads context ONLY from hookSpecificOutput.additionalContext, and the
    // hookEventName must match the event that fired or the whole block is stripped.
    process.stdout.write(
        JSON.stringify({
            hookSpecificOutput: { hookEventName: 'SessionStart', additionalContext: context },
        })
    );
}

try {
    main();
} catch (err) {
    // Never block a session because the drift check failed, but never fail silently
    // either: stderr is observable, stdout must stay clean JSON for the hook contract.
    try {
        process.stderr.write(`session-drift: ${err && err.message ? err.message : 'failed'}\n`);
    } catch {
        /* nothing else to do */
    }
    process.stdout.write('{}');
}
