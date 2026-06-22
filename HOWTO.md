# HOWTO — Agentforce → Agent Script Conversion

A practical guide for using this skill in Claude Code.

---

> **New to this repo?** Start with [WALKTHROUGH.md](./WALKTHROUGH.md) — a step-by-step tutorial using the included sample agent, covering both conversion-only and full ADLC pipeline paths.

## 1. What this is

A Claude Code skill (and a companion subagent) that converts **legacy Agentforce JSON exports** — the older plugin / topic / function object model — into **Agent Script YAML** (`AiAuthoringBundle` `.agent` files).

There is **no compiled converter, no CLI, no rules engine**. Conversion happens by Claude reading three things:

1. A living spec (`agent-script-spec.md`) that documents the current Agent Script format.
2. Five worked examples (input JSON ↔ output `.agent` pairs) covering the common shapes.
3. A short procedural playbook (`conversion-playbook.md`).

When Agent Script evolves, you update the spec and (if needed) add a new example. No code to edit, recompile, or deploy.

---

## 2. Install

```bash
git clone https://github.com/crmoraes/agentforce-converter-claude ~/Dev/agentforce-converter-claude
cd ~/Dev/agentforce-converter-claude
./scripts/install.sh
```

The install script does two things:

1. **Local install** — copies the converter skill and all ADLC agents from this repo into `~/.claude/`.
2. **Upstream install** — invokes the [agentforce-adlc](https://github.com/SalesforceAIResearch/agentforce-adlc) installer to pull the four platform skills (`developing-agentforce`, `testing-agentforce`, `observing-agentforce`, `securing-agentforce`) into `~/.claude/skills/`.

Requires: Claude Code, Python 3.9+, curl. The upstream step degrades gracefully with a warning if either is missing.

It's idempotent — re-run it after a `git pull` to pick up spec/example updates and the latest upstream skills.

Verify:

```bash
ls ~/.claude/skills/agentforce-to-agent-script/SKILL.md
ls ~/.claude/agents/agentforce-converter.md
ls ~/.claude/agents/adlc-orchestrator.md
ls ~/.claude/skills/developing-agentforce/SKILL.md
```

---

## 3. Getting your agent configuration

Before you can convert anything, you need the legacy Agentforce JSON for the agent. To export an existing agent's planner configuration from Salesforce:

1. Navigate to your Salesforce org's base URL.
2. Append `/support/qa/planner.jsp` to the URL (e.g. `https://your-org.salesforce.com/support/qa/planner.jsp`).
3. Select your agent from the list.
4. Copy or download the JSON configuration.

> **Tip:** This planner config contains all the information needed for conversion, including topics, instructions, and functions. Save it locally (e.g. `/tmp/legacy-agent.json`) and feed it to the skill in Section 4.

---

## 4. How to use

Four usage modes, from quickest to most complete:

### Mode 1 — Full pipeline via orchestrator (recommended for new migrations)

Hand a legacy JSON to `adlc-orchestrator` and it will run the full life cycle: convert → author → deploy → test → security scan.

> *"Use adlc-orchestrator to convert, deploy, and test /path/to/agent.json against my org."*

The orchestrator runs Phase 0 (legacy conversion via `agentforce-converter`), then hands off to `adlc-author`, `adlc-engineer`, `adlc-qa`, and `securing-agentforce` in sequence, pausing for your approval at the deployment gate.

### Mode 2 — Converter skill only (conversion without deployment)

Open a Claude Code session in any directory. Paste or attach the Agentforce JSON, then say something like:

> *"Convert this Agentforce JSON to Agent Script."*

The skill auto-triggers based on its description (it watches for legacy-format keywords and `plugins[].pluginType === 'TOPIC'` shapes). You get back YAML + Notes. Stop here or hand the YAML off to `developing-agentforce` manually.

### Mode 3 — Subagent (programmatic orchestration)

When invoking from another agent or chaining manually:

```
Agent({
  subagent_type: 'agentforce-converter',
  prompt: 'Convert the Agentforce JSON at /tmp/legacy-agent.json to Agent Script.'
})
```

The subagent returns a single message with two sections: `## YAML` and `## Notes`.

### Mode 4 — Individual skills (targeted tasks)

Each downstream skill runs independently. Use them directly if you already have a `.agent` file:

```
# Validate and deploy an existing .agent file
Use developing-agentforce to validate and publish My_Agent to my org.

# Run smoke tests
Use testing-agentforce to run smoke tests on My_Agent.

# Production trace analysis
Use observing-agentforce to investigate failures in My_Agent.

# Security scan
Use securing-agentforce to run a full OWASP assessment on My_Agent.
```

### Mode 5 — Manual (debugging / learning)

Read the skill files yourself and follow the playbook by hand. Useful when you want to understand exactly what Claude is doing or to debug a surprising output.

```
~/.claude/skills/agentforce-to-agent-script/
├── SKILL.md
├── references/
│   ├── agent-script-spec.md       # the spec
│   ├── known-input-shapes.md
│   └── conversion-playbook.md
└── examples/                       # 5 worked examples
```

---

## 5. What you'll get back

A message containing:

**a) The YAML** — a complete Agent Script `.agent` ready to drop into:

```
force-app/main/default/aiAuthoringBundles/<developer_name>/<developer_name>.agent
```

**b) A `## Notes` section** that lists:
- **Reference example used** — which of the 5 examples Claude pattern-matched against.
- **Inputs ignored** — input fields that didn't map to anything in Agent Script, with one-line reasons.
- **Defaults injected** — fields the input was missing where Claude supplied spec-defined defaults.
- **Uncertainties** — anything Claude couldn't confidently resolve (e.g. *"Action `get_account` had no `target` in the input — used placeholder `flow://Get_Account_REPLACE_ME`"*).
- **Folder name** — the `developer_name` and the path you'd save under.
- **Next step** — typically *"Use `developing-agentforce` to validate and deploy."*

---

## 6. What's included

**Local (this repo):**
- **Skill** `agentforce-to-agent-script`: `SKILL.md` + 3 reference docs (spec, input shapes, playbook) + 5 worked input/output example pairs.
- **Agent** `agentforce-converter`: subagent wrapper for orchestration / programmatic invocation.
- **Agent** `adlc-orchestrator`: plan-mode orchestrator for the full 7-phase ADLC (Phase 0 = legacy conversion, Phases 1–7 = author → deploy → test → secure).
- **Agent** `adlc-author`: writes `.agent` files from requirements.
- **Agent** `adlc-engineer`: scaffolds Flow/Apex metadata and deploys bundles.
- **Agent** `adlc-qa`: tests agents and optimizes via session trace analysis.
- **Install script** (`scripts/install.sh`): installs local files and pulls upstream skills.
- **HOWTO.md** (this file).

**Upstream (pulled from [agentforce-adlc](https://github.com/SalesforceAIResearch/agentforce-adlc) during install):**
- **Skill** `developing-agentforce`: full Agent Script authoring, validation, deployment, and publish workflow.
- **Skill** `testing-agentforce`: smoke tests, batch test suites, CI/CD integration.
- **Skill** `observing-agentforce`: production session trace analysis via Salesforce Data Cloud.
- **Skill** `securing-agentforce`: OWASP LLM Top 10 security assessment (57 adversarial tests, A–F grade).

---

## 7. What's NOT included

- **No CLI, no HTTP server, no compiled converter.** Conversion is pure Claude reasoning over the spec + examples.
- **No authoring from scratch.** Use `developing-agentforce` (or invoke `adlc-author`) for new `.agent` files written from requirements rather than a legacy JSON.
- **No automatic Agent Script version detection.** The converter skill assumes the format documented in `agent-script-spec.md`. If you're targeting a specific older Agent Script release, edit the spec to match, or use the `nga_interpreter` HTTP API.
- **No conversion rules in code.** All conversion knowledge lives in the spec + examples — that's the point.

Note: deployment, testing, and security scanning **are** included via the upstream ADLC skills — see Section 6.

---

## 8. Things to be aware of

### The honest list

- **Output is not byte-stable.** Run the same input twice and you'll likely get cosmetically different YAML — different whitespace, comment placement, field order within blocks where order isn't enforced. **Structural correctness is the contract; byte parity is not.** If you need byte-exact reproducibility, use the `nga_interpreter` HTTP API instead.

- **Token cost per conversion is non-trivial.** The spec is loaded into context (~1100 lines). Plan for a few thousand input tokens per call. Cached on subsequent calls in the same session.

- **The spec is the source of truth.** If the skill produces something the spec doesn't endorse, that's a skill bug. File it; update the playbook or examples deliberately. Don't paper over it with one-off edits during a conversion.

- **Edge cases get flagged, not guessed.** Expect a "couldn't infer X — placeholder used" or "field Y has no Agent Script equivalent — dropped" line in Notes. **Don't treat the YAML as final without resolving flagged items.**

- **Variable extraction is conservative.** Variables only appear in the output if they're referenced in instruction text somewhere. If you expected a variable and it's missing, check the input — it was probably defined-but-unused, and the skill correctly dropped it.

- **Booleans are `True` / `False` (capitalized).** This is correct Agent Script syntax. Do not "fix" them to lowercase.

- **`developer_name` must match the folder name** when you save the file. The skill emits `developer_name` based on the input; rename your output folder to match, or rename `developer_name` to match your folder.

- **No automatic updates.** `install.sh` copies; it doesn't sync. After `git pull`, re-run `./scripts/install.sh`.

- **Conflict with existing skills:** the skill is scoped narrowly to legacy-JSON → YAML conversion. It will not trigger when you ask to author a new `.agent` from requirements (that's `developing-agentforce`). If both could apply, the more specific TRIGGER keywords win — paste a JSON, and this skill takes it; describe requirements verbally, and `developing-agentforce` takes it.

- **Maintenance ritual.** When Agent Script changes:
  1. Update `references/agent-script-spec.md`.
  2. If the change introduces a novel pattern, add an example folder.
  3. Run the existing 5 examples through the skill to confirm no regression.
  4. `./scripts/install.sh` to push the update to `~/.claude/`.

### Things the skill is good at

- The five canonical shapes (plugin agents, simple-topics agents, variable-heavy agents, verification-gated agents, agents with default escalation/off-topic/ambiguous topics).
- Lazy variable emission (only emit variables that are referenced).
- Variable reference normalization (`{!$X}` / `{$!X}` / `{!X}` / `{$X}` → `{!@variables.X}`).
- `start_agent topic_selector` synthesis with deterministic transitions.
- Action target type mapping (Flow, Apex, generative, retriever, etc.).
- Topic ordering (`start_agent` first, then alphabetical).

### Things the skill will struggle with

- **Custom planner types** beyond ReAct — flag-only, no auto-conversion.
- **Knowledge / RAG configurations with custom retrievers** — the skill emits a placeholder `target:` and points you at the spec's `knowledge:` block.
- **Complex Salesforce schema types** (`lightning__*`) not in the spec's mapping table — flagged.
- **Non-TOPIC `pluginType` values** (FLOW, APEX, etc. as plugin types) — flagged, never auto-mapped.
- **Very large inputs** (>5000 lines of JSON) — may exceed context budget. Split or extract the relevant subtree.

---

## 9. Troubleshooting

### Skill didn't trigger

1. Confirm install: `ls ~/.claude/skills/agentforce-to-agent-script/SKILL.md`
2. Check the input shape — does it have `plugins[].pluginType === 'TOPIC'` or `topics[]` at root?
3. Force-invoke: *"Use the agentforce-to-agent-script skill to convert this."*

### YAML failed to parse downstream

Run `developing-agentforce`'s validation step on the output. Share the validation error back with this skill (or with Claude in the same session) and ask for a fix. The skill should self-correct or escalate to a "this part of the input doesn't have a clean mapping" note.

### Output diverges from what I expected

The skill flags every deviation in the `## Notes` section. Read it. If a flagged uncertainty is wrong:
- It's a skill bug → file an issue, update the playbook or an example, and re-run.
- The input was ambiguous → patch the input (or pre-process it) and re-convert.

### Output diverges from `nga_interpreter`'s `/api/convert`

Both can be valid (the YAML format has flexibility in field order and whitespace). If both parse and produce the same agent behavior, that's success. If you need byte parity for diff/CI purposes, use the HTTP API as the deterministic path — this skill optimizes for maintainability, not byte-stability.

### "I added a new example but the skill ignores it"

After a `git pull` or local change, re-run `./scripts/install.sh`. The script overwrites `~/.claude/skills/agentforce-to-agent-script/`.

---

## 10. Contributing

When you encounter a real-world input the skill handles poorly:

1. **Add an example.** Create a new folder under `examples/` (e.g. `06-knowledge-grounded/`). Include `input.json`, `output.agent`, and a `notes.md` explaining what's interesting.
2. **Update the spec** if the format itself has evolved.
3. **Don't add rules to `conversion-playbook.md`** that aren't backed by either the spec or an example. The playbook is procedural; the rules live elsewhere.
4. **Run the existing examples** as regression checks before committing.

---

## 11. FAQ

**Q: Why no CLI?**
A: To keep the conversion knowledge in one place (the spec + examples) and avoid the maintenance burden of keeping a TS converter in sync with the format. The `nga_interpreter` repo retains a CLI/HTTP path if you need it.

**Q: Can I use this in a CI pipeline?**
A: Not easily — it requires Claude Code. For CI, use the `nga_interpreter` HTTP API.

**Q: Can I customize the skill for my org's conventions?**
A: Yes. Edit `references/agent-script-spec.md` and add an example demonstrating your conventions. Re-run `install.sh`.

**Q: What if a future Agent Script release breaks my existing examples?**
A: Update the spec first; then re-run each example through the skill and update the `output.agent` files where the format changed. The 5 examples become your regression suite.

**Q: Does this work for inputs in YAML instead of JSON?**
A: Yes. The skill parses YAML inputs the same way (per the `known-input-shapes.md` rules).
