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
  return String(text || '')
    .replace(/\r?\n+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

// Noise that carries no lesson. Everything else is captured.
function isNoise(tool, error) {
  const e = error.toLowerCase();
  if (!error) return true;
  if (/\b(user cancel|user_cancel|cancell?ed by user|operation cancelled|aborted)\b/.test(e)) return true;
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
  const key = `${String(tool)}::${normaliseError(error).slice(0, 90).toLowerCase()}`;
  return key;
}

function countOccurrences(content, sig) {
  // Rows store the tool in cell 2 and the error in cell 4. Rebuild each row's signature
  // from those cells so the count reflects real repeats, not a substring coincidence.
  let n = 0;
  for (const line of content.split(/\r?\n/)) {
    if (!line.startsWith('| ')) continue;
    const cells = line.split('|').map((c) => c.trim());
    if (cells.length < 6) continue;
    const tool = cells[2];
    const err = cells[4];
    if (!tool || !err || tool === 'tool') continue;
    if (signature(unescapeCell(tool), unescapeCell(err)) === sig) n += 1;
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

  let existing = '';
  try {
    existing = fs.readFileSync(file, 'utf8');
    if (existing.charCodeAt(0) === 0xfeff) existing = existing.slice(1);
  } catch {
    existing = '';
  }

  if (!existing.trim()) existing = HEADER;

  const sig = signature(tool, error);
  const seen = countOccurrences(existing, sig);
  const now = new Date().toISOString().replace('T', ' ').slice(0, 19);

  const row = `| ${now} | ${escapeCell(tool)} | error | ${escapeCell(error.slice(0, 200))} | ${seen + 1} |\n`;

  try {
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(file, existing.endsWith('\n') ? existing + row : `${existing}\n${row}`);
  } catch {
    return;
  }

  // Surface only a repeat. First occurrence costs no context.
  if (seen + 1 >= 3) {
    process.stdout.write(
      JSON.stringify({
        additionalContext:
          `Recurring tool failure (occurrence ${seen + 1}): ${tool}. ` +
          `Same error text seen before: "${error.slice(0, 120)}". ` +
          'Recorded in the session lesson ledger. Do not retry the same call unchanged; ' +
          'report the pattern and let the user decide whether a rule should change.',
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
