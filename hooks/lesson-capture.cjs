// postToolUseFailure hook: capture what a failed tool call actually returned.
//
// Writes one table row per failure to the session lesson ledger. It records only what the
// event carried: tool name, outcome, the error text as returned, and the error's shape.
// It never infers a cause and never proposes a fix — capture is evidence, not action.
//
// Context cost is near zero: the hook returns {} on first occurrence. It only returns
// additionalContext when the SAME failure recurs, because a repeat is the signal worth
// acting on. Promotion into a rule stays a human decision.

const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');

const HOME = os.homedir();
const COPILOT = path.join(HOME, '.copilot');
const APPDATA = process.env.APPDATA || path.join(HOME, 'AppData', 'Roaming');

const HEADER = [
    '# Session lessons',
    '',
    'Written by the postToolUseFailure hook. One row per failed tool call, evidence only.',
    'Review and promotion happen on request, under the ownership gate in the agent file.',
    '',
    '| time | tool | outcome | error (as returned) | count |',
    '| --- | --- | --- | --- | --- |',
    '',
].join('\n');

// The ledger belongs next to session memory so the agent can read and promote it.
// Probe the known VS Code variants, then fall back to the hook's own state folder.
function ledgerPath() {
    const overridden = process.env.SAP_AGENT_LESSONS_FILE;
    if (overridden) return overridden;

    const candidates = [
        path.join(APPDATA, 'Code', 'User', 'globalStorage', 'github.copilot-chat', 'memory-tool', 'memories', 'session'),
        path.join(APPDATA, 'Code - Insiders', 'User', 'globalStorage', 'github.copilot-chat', 'memory-tool', 'memories', 'session'),
    ];

    for (const dir of candidates) {
        const parent = path.dirname(dir);
        if (fs.existsSync(parent)) return path.join(dir, 'lessons.md');
    }
    return path.join(COPILOT, 'state', 'lessons.md');
}

function readStdin() {
    try {
        let raw = fs.readFileSync(0, 'utf8');
        if (raw.charCodeAt(0) === 0xfeff) raw = raw.slice(1);
        return raw;
    } catch {
        return '';
    }
}

function normaliseError(text) {
    // An object became the literal string "[object Object]". Measured 2026-11-16: posting
    // {"error":{"message":"disk full","code":28}} wrote a ledger row reading `| error | [object
    // Object] | 1 |`, so the hook recorded that a failure repeated while destroying the only part a
    // human could act on. String(value) is right for strings and numbers and wrong for everything
    // structured, so the structured case is serialised first.
    if (text && typeof text === 'object') {
        try {
            text = typeof text.message === 'string' ? text.message : JSON.stringify(text);
        } catch {
            text = String(text);
        }
    }
    return String(text || '')
        .replace(/\r?\n+/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
}

// Noise that carries no lesson. Everything else is captured.
function isNoise(tool, error) {
    const e = error.toLowerCase();
    if (!error) return true;
    // `aborted` used to be matched on its own. Windows renders a dropped socket as "connection aborted
    // by the remote host (0x80072745)", so the one class of failure this hook most needs to record - a
    // real network error - was discarded as though the user had pressed Escape.
    if (/\b(user cancel|user_cancel|cancell?ed by user|operation cancelled|aborted by the user)\b/.test(e)) return true;
    if (/\b(request was cancelled|command was cancelled)\b/.test(e)) return true;
    void tool;
    return false;
}

function escapeCell(value) {
    return String(value || '')
        .replace(/\|/g, '\\|')
        .replace(/\s+/g, ' ')
        .trim();
}

function signature(tool, error) {
    // 200, not 90. The row stores the first 200 characters of the error, so a 90-character signature
    // merged every failure that shared a 90-character prefix - two different SQL errors from the
    // same statement became one recurring failure, and a genuinely new failure could be reported as
    // occurrence 4 of an old one. The signature now spans exactly as much of the error as is kept.
    const key = `${String(tool)}::${normaliseError(error).slice(0, 200).toLowerCase()}`;
    return key;
}

function countOccurrences(content, sig) {
    // Rows store the tool in cell 2 and the error in cell 4. Rebuild each row's signature
    // from those cells so the count reflects real repeats, not a substring coincidence.
    //
    // The split ignores escaped pipes. writeRow() escapes `|` as `\|` so the table stays valid, and
    // splitting on a raw `|` first cut an error that contained one into extra cells: cells[4] came
    // back truncated, the signature never matched, and `seen` stayed 0 forever - so the recurring
    // failure this hook exists to surface never fired for exactly the errors most likely to have
    // pipes in them (SQL, PowerShell, table dumps).
    let n = 0;
    for (const line of content.split(/\r?\n/)) {
        if (!line.startsWith('| ')) continue;
        const cells = line.split(/(?<!\\)\|/).map((c) => c.trim());
        if (cells.length < 6) continue;
        const tool = cells[2];
        const err = cells[4];
        if (!tool || !err || tool === 'tool') continue;
        if (signature(unescapeCell(tool), unescapeCell(err)) === sig) {
            // The count column, not the row count. Rotation keeps only the last 250 rows, so
            // counted-rows restarted at 1 once a failure's older occurrences were trimmed and the
            // >=3 alert could never fire again for that signature - the hook's only output silently
            // forgot. The row already records its own occurrence number, so the highest is the truth
            // regardless of what rotation removed.
            const recorded = parseInt(cells[5], 10);
            n = Math.max(n, Number.isFinite(recorded) ? recorded : 0);
        }
    }
    return n;
}

function unescapeCell(value) {
    return String(value || '').replace(/\\\|/g, '|');
}

function main() {
    const raw = readStdin();
    let event = {};
    try {
        event = JSON.parse(raw) || {};
    } catch {
        return; // no payload, nothing to capture
    }

    const tool = event.toolName || event.tool_name || '';
    const error = normaliseError(event.error || event.errorText || '');

    if (!tool) return;
    if (isNoise(tool, error)) return;

    const file = ledgerPath();
    const dir = path.dirname(file);
    try {
        fs.mkdirSync(dir, { recursive: true });
    } catch {
        return;
    }

    // A failed read is not an empty ledger. The old catch set `existing = ''`, the next line replaced
    // it with HEADER, and the write below then overwrote the real ledger with a header plus one row -
    // losing every captured failure and restarting the occurrence count that is this hook's only
    // output. Only ENOENT means "no ledger yet"; a sharing violation or an ACL means "do not touch it".
    let existing = '';
    try {
        existing = fs.readFileSync(file, 'utf8');
        if (existing.charCodeAt(0) === 0xfeff) existing = existing.slice(1);
    } catch (e) {
        if (!e || e.code !== 'ENOENT') {
            try {
                process.stderr.write(`lesson-capture: cannot read ${file} (${(e && e.code) || 'error'}); ledger not touched\n`);
            } catch {
                /* stderr is best effort */
            }
            return;
        }
        existing = '';
    }

    if (!existing.trim()) existing = HEADER;

    const sig = signature(tool, error);
    const seen = countOccurrences(existing, sig);
    const now = new Date().toISOString().replace('T', ' ').slice(0, 19);

    const row = `| ${now} | ${escapeCell(tool)} | error | ${escapeCell(error.slice(0, 200))} | ${seen + 1} |\n`;

    try {
        fs.mkdirSync(dir, { recursive: true });
        // Unbounded before: every failure appended for ever and the whole file was rewritten each
        // time. Measured 2026-11-16: +71 bytes per event, about 750 KB at 10,000 failures, so the
        // rewrite cost grew with the ledger's age. Same cap the subagent log already uses.
        let next = existing.endsWith('\n') ? existing + row : `${existing}\n${row}`;
        const MAX_BYTES = 256 * 1024;
        if (Buffer.byteLength(next, 'utf8') > MAX_BYTES) {
            const keep = next.split('\n').filter(Boolean).slice(-250);
            next = `${HEADER}${keep.join('\n')}\n`;
        }
        fs.writeFileSync(file, next);
    } catch {
        return;
    }

    // Surface only a repeat. First occurrence costs no context.
    if (seen + 1 >= 3) {
        const context =
            `Recurring tool failure (occurrence ${seen + 1}): ${tool}. ` +
            `Same error text seen before: "${error.slice(0, 120)}". ` +
            'Recorded in the session lesson ledger. Do not retry the same call unchanged; ' +
            'report the pattern and let the user decide whether a rule should change.';
        process.stdout.write(
            JSON.stringify({
                hookSpecificOutput: {
                    hookEventName: 'PostToolUseFailure',
                    additionalContext: context,
                },
            })
        );
    }
}

try {
    main();
} catch (err) {
    try {
        process.stderr.write(`lesson-capture: ${err && err.message ? err.message : 'failed'}\n`);
    } catch {
        /* ignore */
    }
}
