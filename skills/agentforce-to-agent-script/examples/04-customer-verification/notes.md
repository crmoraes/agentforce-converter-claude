# Example 04 — Customer Verification

## What this demonstrates

The canonical verification pattern: a verification topic gates other sensitive topics, with lockout protection.

## The 7 standard verification variables

When the skill detects a verification-shaped topic (keywords: "verify", "verification", "authenticate", "identity"), it injects these 7 variables — even if not present in the input:

| Variable | Type | Default | Purpose |
|---|---|---|---|
| `IsVerified` | mutable boolean | `False` | Set to `True` after successful verification |
| `VerificationStatus` | mutable string | `"PENDING"` | One of `PENDING`, `IN_PROGRESS`, `VERIFIED`, `FAILED` |
| `AttemptsRemaining` | mutable number | `3` | Counts down on each failure |
| `IsLockedOut` | mutable boolean | `False` | Set to `True` when `AttemptsRemaining == 0` |
| `VerifiedEmail` | mutable string | (no default) | Email the caller provided |
| `VerifiedDOB` | mutable date | (no default) | DOB the caller provided |
| `ContactId` (or `AccountId`) | linked string | from `@MessagingEndUser` | The CRM record being verified against |

The exact list and defaults must match the spec's "Customer verification" section. If the spec evolves these, update both the spec and this example.

## Key patterns shown

### before_reasoning gates

Every sensitive topic has:
```
reasoning:
    before_reasoning:
        if @variables.IsVerified == False:
            transition to @topic.customer_verification
```

This is a deterministic guard — it runs before the LLM ever sees the topic, so it costs no inference credits.

### Lockout pattern

The `customer_verification` topic itself gates on `AttemptsRemaining`:
```
before_reasoning:
    if @variables.AttemptsRemaining == 0:
        set @variables.IsLockedOut = True
        respond with "Too many failed attempts."
```

And `start_agent` checks `IsLockedOut` first to short-circuit any further topic routing.

### Topic ordering

Output is alphabetical: `account_balance`, `customer_verification`. `start_agent` is always first.

## Things flagged (would be in Notes)

- **Auto-injected 7 verification variables** — not present in the input. The skill detected the verification pattern and added them per the spec.
- `before_reasoning` guards added to `account_balance` based on the input's scope text "Only respond if the caller is verified."
- Lockout logic added even though input doesn't mention it — this is the canonical pattern from the spec.
