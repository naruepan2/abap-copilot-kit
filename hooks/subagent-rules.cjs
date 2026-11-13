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

// agentName arrives in an undocumented shape. Match tolerantly against the roster's file
// names and their display-ish variants, and treat "no match" as untrusted.
function normalise(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/\.agent\.md$/, '')
    .replace(/\s+by\s+pongg$/, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

function classify(agentName, roster) {
  const want = normalise(agentName);
  if (!want) return { trusted: false, reason: 'agent name missing from the event payload' };

  const allowed = [];
  for (const d of roster.delegatable || []) allowed.push({ file: d.file, role: d.role || '' });

  // Keep the roster's own wording per blocked entry, so the injected reason names the
  // entry that actually matched instead of whichever substring happened to hit first.
  const blocked = [];
  for (const g of roster.not_delegatable || []) {
    for (const f of g.files || []) blocked.push({ file: f, reason: g.reason || '' });
  }

  const findIn = (list) => {
    // Exact match first: "abap-developer-by-pongg" must not be reported as the
    // sibling entry "abap-developer" just because that name is a prefix of it.
    let hit = list.find((e) => normalise(e.file) === want);
    if (hit) return hit;
    hit = list.find((e) => {
      const n = normalise(e.file);
      return want.startsWith(`${n}-`) || n.startsWith(`${want}-`);
    });
    return hit || null;
  };

  const allow = findIn(allowed);
  if (allow) return { trusted: true, role: allow.role };

  const deny = findIn(blocked);
  if (deny) {
    return {
      trusted: false,
      reason: deny.reason
        ? `roster.json classifies "${deny.file}" as not delegatable: ${deny.reason}`
        : `roster.json classifies "${deny.file}" as not delegatable`,
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

  // Support both the camelCase and the VS Code snake_case payload shapes.
  const agentName = event.agentName || event.agent_name || '';
  const display = event.agentDisplayName || event.agent_display_name || '';

  const roster = readJson(ROSTER);
  if (!roster) {
    log(`no roster; restricting\t${agentName}`);
    process.stdout.write(
      JSON.stringify({
        additionalContext: untrustedBlock('roster.json could not be read', agentName),
      })
    );
    return;
  }

  const verdict = classify(agentName || display, roster);
  log(`${verdict.trusted ? 'trusted' : 'restricted'}\t${agentName || display}\t${verdict.reason || verdict.role || ''}`);

  const context = verdict.trusted
    ? trustedBlock(verdict.role)
    : untrustedBlock(verdict.reason, agentName || display);

  process.stdout.write(JSON.stringify({ additionalContext: context }));
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
  process.stdout.write(
    JSON.stringify({
      additionalContext:
        'Restricted delegation context. Treat this task as READ-ONLY: no create, update, delete, activation, publish, or transport write. Report findings and stop.',
    })
  );
}
