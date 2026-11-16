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
function keys(entry, withShortDisplay) {
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
    // removes the dependence on which one it picks.
    //
    // It is a WIDER spelling, so it belongs on the deny side only. Adding it to the allow list meant
    // an agent installed as `<display minus " by X">` - for this roster `sap-se38-report-tester`,
    // `sap-st22-dump-analyst`, `sap-abap-reverse-engineering-analyst` - was trusted although the
    // roster never named that file, contradicting the rule two lines below that nothing but the
    // roster entry itself may inherit its trust. Measured 2026-11-16: those three keys were not
    // equal to any file stem, and section 5c could not see it because it only probed `.file`.
    if (withShortDisplay) add(String(entry.display || '').replace(/\s+by\s+.+$/i, ''));
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
    for (const d of roster.delegatable || []) {
        // Carry the entry through whole. The projection to {file, display, role} silently dropped
        // `files` and `displays`, which keys() supports and which the deny list uses - so a
        // delegatable entry written in the sibling shape was classified as not listed and its agent
        // was RESTRICTED. Section 5/5c of verify-all reads only .file too, so the audit could not see
        // it either. Measured 2026-11-15 with a roster using files:[...].
        allowed.push({ file: d.file, display: d.display, files: d.files, displays: d.displays, role: d.role || '' });
    }

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
    const exact = (list, withShortDisplay) => list.find((e) => keys(e, withShortDisplay).includes(want)) || null;
    const fuzzy = (list) => list.find((e) => keys(e, true).some((n) => want.startsWith(`${n}-`) || n.startsWith(`${want}-`))) || null;

    // The allow list is a permission, so the narrower spelling: exact match on what the roster names.
    const allow = exact(allowed, false);
    if (allow) return { trusted: true, role: allow.role };

    // Deny is checked with both, and deny wins over "not listed": the reason is more useful when it
    // names the entry the roster actually refused.
    const deny = exact(blocked, true) || fuzzy(blocked);
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
        // Bounded on purpose. This file is appended to on every subagent start - about 88 bytes each,
        // measured - and had no cap, rotation or truncation path, so it grew without limit for the
        // life of the machine (0.84 MB after 10,000 events).
        //
        // Truncated by BYTES, not by a line count. A fixed 250 lines could not converge: a restricted
        // entry carries the roster's whole reason text, measured 2026-11-16 at a mean of 197 B and a
        // maximum of 637 B, so 250 lines is up to 159 KB - still over the 64 KB cap, and every later
        // event would re-read and re-write the whole file for ever. Keeping the last half-cap means
        // the rewrite happens once per ~32 KB of events instead of once per event.
        const MAX_BYTES = 64 * 1024;
        let st = null;
        try {
            st = fs.statSync(LOG);
        } catch (e) {
            // No log yet is the normal first run, not a failure. Only an error that is not ENOENT
            // is worth a word: reporting ENOENT made every probe home print a false alarm, and a
            // diagnostic that fires on the healthy path is worse than none.
            if (!e || e.code !== 'ENOENT') {
                try {
                    process.stderr.write(`subagent-rules: cannot read ${LOG} (${(e && e.code) || 'error'})\n`);
                } catch { /* stderr is best effort */ }
            }
        }
        if (st && st.size > MAX_BYTES) {
            // Bytes in, bytes out. This used st.size (bytes) for the decision and then sliced a
            // string (UTF-16 code units) for the cut, so any log containing non-ASCII text could
            // never fall below the cap: measured 2026-11-16, a Thai log rotated 341,090 ->
            // 88,791 bytes, still over 65,536, and re-read and re-wrote the whole file on every
            // subsequent event for ever. Buffer slicing is byte-accurate by construction.
            const all = fs.readFileSync(LOG);
            let tail = all.subarray(Math.max(0, all.length - Math.floor(MAX_BYTES / 2)));
            const nl = tail.indexOf(0x0a);
            if (nl >= 0) tail = tail.subarray(nl + 1);
            // A cut can land inside a multi-byte character; the replacement mark is dropped rather
            // than written back as corruption.
            let keep = tail.toString('utf8').replace(/^\uFFFD+/, '');
            if (keep !== '' && !keep.endsWith('\n')) keep += '\n';
            // Serialised, because two rotations interleaved is worse than a lost line: each writes
            // the whole file, so the second silently discards the first's trim. A stale lock is
            // ignored after 10 s so a killed process cannot freeze rotation for ever.
            const lock = `${LOG}.lock`;
            let locked = false;
            try {
                const age = Date.now() - fs.statSync(lock).mtimeMs;
                if (age > 10000) fs.unlinkSync(lock);
            } catch { /* no lock present */ }
            try {
                fs.writeFileSync(lock, String(process.pid), { flag: 'wx' });
                locked = true;
            } catch { /* another process is rotating; skip this round */ }
            if (locked) {
                try { fs.writeFileSync(LOG, keep); } finally { try { fs.unlinkSync(lock); } catch { /* best effort */ } }
            }
        }
        fs.appendFileSync(LOG, `${new Date().toISOString()}\t${line}\n`);
    } catch (e) {
        // Was a bare comment. The hook still emits its context, which is correct, but a log that can
        // never be written should say so once instead of failing invisibly for the machine's life.
        try {
            process.stderr.write(`subagent-rules: cannot append to ${LOG} (${(e && e.code) || 'error'})\n`);
        } catch { /* stderr is best effort */ }
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
