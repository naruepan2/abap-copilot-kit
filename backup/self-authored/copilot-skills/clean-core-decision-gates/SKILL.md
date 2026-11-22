---
name: clean-core-decision-gates
description: >
  Decision rules for Clean Core Level A-D work - the lowest-level rule, "unclassified = Level C",
  ATC priority-to-level mapping, the transactional-consistent gate for a classic API used inside RAP,
  and wrapper governance (level follows the wrapped object, SU22 variants, one exemption, retirement).
  Use when choosing a released/classic/internal API, wrapping a non-released API, judging an ATC finding
  or exemption, or deciding whether a classic API is safe in RAP. Not a package-wide audit and not a
  release-state lookup.
---

# Clean Core decision gates

Four decisions that change a design. Each rule has one home; do not repeat it in the agent file.

## Boundary

- Need per-object Level A-D classification for a whole package -> load installer skill `sap-clean-core-atc`. It owns the audit workflow and its ARC-1 / mcp-sap-docs calls. Do not rebuild it here.
- Need the release state of one object -> `sap-docs.sap_get_object_details`, or `GetAPIReleaseState` when that server is in scope, per the agent's MCP routing table. Public data is a candidate, not target-system truth.
- Need to run ATC -> ADT MCP per the agent's tool routing. This skill interprets findings; it does not run them.

## 1. Level of an extension

- **Lowest level wins.** One Level C call demotes a Level A application to Level C.
- **Unclassified is Level C.** A non-released SAP object not listed in the classification data defaults to internal; there is no "unclassified = safe" state.
- State mapping in `objectClassifications_SAP.json`: `released` -> A (no finding); `classicAPI` -> B (Priority 3); `internalAPI` -> C (Priority 2); `noAPI` -> D (Priority 1). DDIC data types are not classified; only SQL access to SAP tables is checked.
- ATC finding to level: **P1/D** = object modification, disallowed enhancement technology, implicit/explicit enhancement plug-in, direct table write, SAP form routine call, `noAPI` object, critical statements. **P2/C** = direct table read, internal object. **P3/B** = deprecated or classic API.

## 2. transactional-consistent gate (RAP)

> A classic API may only be used inside a RAP application if it carries the `transactional-consistent` label in the Cloudification Repository. Other classic APIs may break RAP's transactional model.

Source: `skills/rap/SKILL.md` section "Clean Core Level Notes for RAP", key rule; the label is defined in `atc-cloudification/references/quick-reference.md` section "Labels". Check the label for the exact target release before relying on it - do not infer it from "this BAPI is usually fine".

## 3. Wrapper governance

- Build the wrapper in a classic software component and release it for ABAP Cloud consumption; the consuming code keeps its own level.
- The wrapper's level follows the wrapped object: classic -> B, internal -> C, `noAPI` -> **do not build**. A wrapper never upgrades a Level D object.
- Supply `SU22` data and variants for the wrapped authorization behavior.
- Many findings -> **one** fine-grained ATC exemption at the wrapper, not one per caller.
- Import the changelog for SAP objects via `SYCM`, and register the wrapper for retirement when SAP releases a successor.

## 4. ATC configuration anchors (verify before use)

- Variants: `ABAP_CLEAN_CORE_DEVELOPMENT`, `ABAP_CLOUD_DEVELOPMENT_DEFAULT`, `ABAP_CLOUD_READINESS`. List the real names on the target first; a missing variant is not permission to silently run DEFAULT.
- Checks: `SYCM_USAGE_OF_APIS`, `SYCM_ALLOWED_ENH_TECHNOLOGY`, `CI_SEARCH_CUST_MODIFICATIONS`, `CI_CRITICAL_STATEMENTS`, `SLIN_SEC`. SAP Note 3565942 enables the Clean Core checks.
- Cloudification Repository `SAP/abap-atc-cr-cv-s4hc`, directory `src/`:

| Target | File |
| --- | --- |
| SAP Cloud ERP (public) | `objectReleaseInfoLatest.json` |
| SAP Cloud ERP Private | `objectReleaseInfo_PCELatest.json`, or `objectReleaseInfo_PCE{YEAR}_{FPS}.json` |
| SAP BTP, ABAP Environment | `objectReleaseInfo_BTPLatest.json` |
| Clean Core classification | `objectClassifications_SAP.json` (not `_3TierModel`, which is superseded) |

Confirm that the file exists for the target release; do not assume the URL pattern from another release.

## Provenance and freshness

Rules 1-4 were extracted from the intake copy at `C:\Users\narue\Desktop\abap-skills-main\skills\` and re-read directly: `rap/SKILL.md` lines 417 and 423; `abap-cloud/SKILL.md` section "Wrapper Pattern"; `atc-cloudification/references/quick-reference.md`. That copy is not SAP documentation - confirm version-sensitive claims against the live Cloudification Repository or the target system before acting on them. The same intake repo contains verified defects in other skills (RAP events, CDS admin fields, BAdI snippets, Fiori `AppList.json`); none of that was copied here.
