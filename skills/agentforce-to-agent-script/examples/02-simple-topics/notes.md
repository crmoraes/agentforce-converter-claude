# Example 02 — Simple Topics

## What this demonstrates

Shape B: a leaner input that puts `topics[]` directly at the root, with no `plugins[]` wrapper. Functions are called `actions` in this shape and live inside the topic.

## Key differences from Example 01

- No `plugins[]` → no plugin-level `scope` to merge in. Topic instructions come straight from `topic.instructions`.
- `topic.actions[]` (input) maps directly to `topic.<name>.actions:` (output) without an intermediate plugin layer.
- No `welcomeMessage` in input → `system.messages.welcome` defaulted from `label`. Flagged in Notes.
- No `secondaryLocales` → `additional_locales: ""`.
- No variables in input → `variables:` block is omitted entirely (do not emit an empty block).

## Action target type: retriever

`invocationTargetType: "retriever"` → `target: "retriever://Warranty_KB"`. See the spec's action-target table for the full list of mappings.

## Things flagged (would be in Notes)

- `system.messages.welcome` — defaulted from agent label; suggest the user override with something more specific.
- `default_agent_user` — placeholder.
