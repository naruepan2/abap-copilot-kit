// subagentStart hook: inject the workspace rules a subagent would otherwise miss.
//
// A subagent runs in its own context, so the coordinator's rules do not follow it.
// This hook prepends a short rule block to the subagent's first message.
//
// Safety stance: when the agent cannot be matched against roster.json, the RESTRICTIVE
// block is injected. An unknown agent is treated as read-only, never as trusted.
//
// Detection and injection only. This script does not edit any file except its own log.

const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');

const HOME = os.homedir();
const COPILOT = path.join(HOME, '.copilot');
const ROSTER = path.join(COPILOT, 'roster.json');
const STATE_DIR = path.join(COPILOT, 'state');
const LOG = path.join(STATE_DIR, 'subagent-rules.log');

function readJson(file) {
    let text;
    try {
        text = fs.readFileSync(file, 'utf8');
    } catch {
        return null;
    }
    if (text.charCodeAt(0) === 0xfeff) text = text.slice(1);
    try {
        return JSON.parse(text);
    } catch {
        try {
            const cleaned = text
                .split(/\r?\n/)
                .filter((l) => !/^\s*\/\//.test(l))
                .join('\n')
                .replace(/\/\*[\s\S]*?\*\//g, '');
            return JSON.parse(cleaned.replace(/,(\s*[}\]])/g, '$1'));
        } catch {
            return null;
        }
    }
}

// agentName arrives in an undocumented shape. The roster is keyed on file stems, but the harness
// sends the frontmatter display name, so a match is either spelling - never a guess about which one
// the product picked. Treat "no match" as untrusted.
function normalise(value) {
    return String(value || '')
        .toLowerCase()
        .replace(/\.agent\.md$/, '')
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-|-$/g, '');
}

// Every spelling an entry may be recognised by. `file`/`files` are the stems the roster is curated
// with; `display`/`displays` are the names in the agent frontmatter. Keeping both in the data is the
// fix for a real defect: normalise() used to strip " by pongg", a suffix the stems do not carry, so
// the allowlist never matched a display name and every delegatable agent was classified "not listed
// in roster.json" and restricted. The log on this machine recorded it before the fix.
function keys(entry) {
    const out = [];
    const add = (v) => {
        const k = normalise(v);
        if (k && !out.includes(k)) out.push(k);
    };
    if (!entry) return out;
    add(entry.file);
    add(entry.display);
    // The harness has been seen sending the display name with and without the " by <author>" suffix:
    // the full form for the delegatable agents, the short form for the coordinator. One extra key
    // removes the dependence on which one it picks. Normalise() turns the stripped form into the same
    // shape as a file stem.
    add(String(entry.display || '').replace(/\s+by\s+.+$/i, ''));
    for (const f of entry.files || []) add(f);
    for (const d of entry.displays || []) add(d);
    return out;
}

function classify(agentName, roster) {
    const want = normalise(agentName);
    if (!want) return { trusted: false, reason: 'agent name missing from the event payload' };

    // Carry every spelling through. Building this object with only `file` was the second half of the
    // same defect: the roster had a display name, and the projection to {file, role} threw it away.
    const allowed = [];
    for (const d of roster.delegatable || []) allowed.push({ file: d.file, display: d.display, role: d.role || '' });

    // Keep the roster's own wording per blocked entry, so the injected reason names the
    // entry that actually matched instead of whichever substring happened to hit first.
    const blocked = [];
    for (const g of roster.not_delegatable || []) {
        for (const f of g.files || []) blocked.push({ file: f, reason: g.reason || '' });
        for (const d of g.displays || []) blocked.push({ display: d, reason: g.reason || '' });
    }

    // Two different questions, so two different matching rules. Collapsing them into one fuzzy search
    // was a real defect: `findIn(allowed)` ran first and accepted a bidirectional prefix match, so an
    // agent named after an allowed one - `<allowed>-anything`, or a truncated prefix of it - was
    // classified TRUSTED. Latent while the roster happens to be free of such collisions, and armed
    // the moment somebody installs an agent whose name starts like a delegatable one.
    //
    // The allow list is a permission, so it requires an exact match: nothing but the roster entry
    // itself may inherit its trust. The deny list is a restriction, so a broader match is the safe
    // direction - if a name resembles something the roster refused, refuse it.
    const exact = (list) => list.find((e) => keys(e).includes(want)) || null;
    const fuzzy = (list) => list.find((e) => keys(e).some((n) => want.startsWith(`${n}-`) || n.startsWith(`${want}-`))) || null;

    const allow = exact(allowed);
    if (allow) return { trusted: true, role: allow.role };

    // Deny is checked with both, and deny wins over "not listed": the reason is more useful when it
    // names the entry the roster actually refused.
    const deny = exact(blocked) || fuzzy(blocked);
    if (deny) {
        const named = deny.file || deny.display || '(unnamed entry)';
        return {
            trusted: false,
            reason: deny.reason
                ? `roster.json classifies "${named}" as not delegatable: ${deny.reason}`
                : `roster.json classifies "${named}" as not delegatable`,
        };
    }

    return { trusted: false, reason: 'agent is not listed in roster.json' };
}

function trustedBlock(role) {
    return [
        `Workspace rules for this delegated task (role: ${role || 'read-only'}).`,
        '',
        '- This task is READ-ONLY. Do not create, update, delete, activate, publish, or write a transport.',
        '- Write repository objects only in the Z or Y namespace. Read SAP standard objects freely.',
        '- State the confirmed SAP system and client in your first line, copied from the brief.',
        '- A claim about the environment needs a tool result from this run. Label a hypothesis',
        '  HYPOTHESIS and pair it with the check that would confirm it. If you cannot check, write',
        '  UNVERIFIED and name the check. Never fill a gap in a tool result with a plausible value.',
        '- An empty search result does not prove absence. A passing check does not prove behaviour.',
        '- Return findings, not edits. If the task needs a write, report that and stop.',
    ].join('\n');
}

function untrustedBlock(reason, agentName) {
    return [
        'Restricted delegation context.',
        '',
        `This subagent (${agentName || 'unknown'}) is not a workspace-approved delegate: ${reason}.`,
        '',
        '- Treat this task as READ-ONLY. Do not create, update, delete, activate, publish, or write a',
        '  transport, and do not change SAP state in any way.',
        '- Do not modify files outside the workspace folder you were given.',
        '- Report what you find and stop. If the task requires a write, say so instead of doing it.',
        '- Every claim needs evidence from this run. Label guesses as HYPOTHESIS; write UNVERIFIED',
        '  when a check cannot be run.',
    ].join('\n');
}

function log(line) {
    try {
        fs.mkdirSync(STATE_DIR, { recursive: true });
        fs.appendFileSync(LOG, `${new Date().toISOString()}\t${line}\n`);
    } catch {
        /* logging is best effort */
    }
}

// The product reads context ONLY from hookSpecificOutput.additionalContext, and it strips
// the block when hookSpecificOutput.hookEventName does not match the event that fired.
// A top-level additionalContext is ignored.
function emit(context) {
    process.stdout.write(
        JSON.stringify({
            hookSpecificOutput: { hookEventName: 'SubagentStart', additionalContext: context },
        })
    );
}

function main() {
    let raw = '';
    try {
        raw = fs.readFileSync(0, 'utf8');
    } catch {
        raw = '';
    }
    if (raw.charCodeAt(0) === 0xfeff) raw = raw.slice(1);

    let event = {};
    try {
        event = JSON.parse(raw) || {};
    } catch {
        event = {};
    }

    // Field names seen in the product code:
    //   extension (SubagentStart): { hook_event_name, agent_id, agent_type }
    //   CLI                      : { hookEventName, agentName | agentType }
    // An unknown shape falls through to the restrictive block, never to trusted.
    const agentName =
        event.agent_type ||
        event.agentType ||
        event.agentName ||
        event.agent_name ||
        event.agent_id ||
        '';
    const display = event.agentDisplayName || event.agent_display_name || event.agent_id || '';

    const roster = readJson(ROSTER);
    if (!roster) {
        log(`no roster; restricting\t${agentName}`);
        emit(untrustedBlock('roster.json could not be read', agentName));
        return;
    }

    const verdict = classify(agentName || display, roster);
    log(`${verdict.trusted ? 'trusted' : 'restricted'}\t${agentName || display}\t${verdict.reason || verdict.role || ''}`);

    const context = verdict.trusted
        ? trustedBlock(verdict.role)
        : untrustedBlock(verdict.reason, agentName || display);

    emit(context);
}

try {
    main();
} catch (err) {
    // Fail safe: never let a hook error leave a subagent without the restriction.
    try {
        process.stderr.write(`subagent-rules: ${err && err.message ? err.message : 'failed'}\n`);
    } catch {
        /* ignore */
    }
    emit(
        'Restricted delegation context. Treat this task as READ-ONLY: no create, update, delete, activation, publish, or transport write. Report findings and stop.'
    );
}
