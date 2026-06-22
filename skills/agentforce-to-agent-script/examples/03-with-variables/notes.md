# Example 03 — Variables (linked, mutable, lazy emission)

## What this demonstrates

The variable extraction rules — the most error-prone part of the conversion.

## Key behaviors

### 1. Lazy emission

Input has 4 variables: `ContactId`, `AccountId`, `AttemptCount`, `UnusedFlag`.

Output has 2: `AccountId` (referenced via `{!$AccountId}`) and `AttemptCount` (referenced via `{$!AttemptCount}`).

`ContactId` is **not referenced** in any instruction text in this input → dropped.
`UnusedFlag` is **not referenced** → dropped.

### 2. Linked vs mutable classification

- `AccountId` has `valueType: "REFERENCE"` with a `source: "@MessagingEndUser.AccountId"` → **`linked`**.
- `AttemptCount` has `valueType: "PRIMITIVE"` with a default `value: "0"` → **`mutable`** with default `= 0`.

### 3. Variable reference normalization

Input syntax → output syntax:

| Input | Output |
|---|---|
| `{!$AccountId}` | `{!@variables.AccountId}` |
| `{$!AttemptCount}` | `{!@variables.AttemptCount}` |
| `{$AccountId}` | `{!@variables.AccountId}` |
| `{!AccountId}` | `{!@variables.AccountId}` |
| `@variables.AccountId` (already modern) | `@variables.AccountId` (unchanged) |

### 4. Variable plumbing into action calls

The `with accountId = @variables.AccountId` line in `reasoning.actions` shows how a linked variable flows into an action input. Without that line, the planner would have to ask the user for `accountId` despite having it linked.

## Things flagged (would be in Notes)

- 2 of 4 input variables dropped (ContactId, UnusedFlag) — neither was referenced in instruction text.
- `AccountId` classified as `linked` because of its `REFERENCE` valueType.
- `AttemptCount` mutable with default `0`.
