# SAP Interface Field Semantics

## Gate
Classify every field before proposing reuse:
1. Business-domain: accounting, tax, partner, inventory, valuation, pricing, or reporting meaning.
2. Technical-control: idempotency key, event flag, correlation ID, processing status, retry marker, or duplicate-detection key.
3. Mixed or unknown: requires owner confirmation and system evidence.

## Decision rules
- Default: preserve business semantics.
- Reject field reuse when the proposed technical behavior can change posting, compliance, matching, reporting, authorization, or downstream integration meaning.
- A same-process memory flag is not durable idempotency. State the lifetime and reset boundary.
- For payment/accounting interfaces, record posting document key, source reference, message/interface ID, run ID, company code, fiscal year, and item granularity when available.

## Required output
Add a field-semantics matrix with: field, object, current meaning, proposed meaning, owner, lifecycle, persistence, consumers, risk, evidence, and verdict.
