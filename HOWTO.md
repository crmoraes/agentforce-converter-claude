# HOWTO — Agentforce → Agent Script Conversion

A practical guide for using this skill in Claude Code.

---

> **New to this repo?** Start with [WALKTHROUGH.md](./WALKTHROUGH.md) — a step-by-step tutorial using the included sample agent, covering both conversion-only and full ADLC pipeline paths.

## 1. What this is

A Claude Code skill (and a companion subagent) that does two things:

**A — Convert:** Takes a **legacy Agentforce JSON export** (the older plugin / topic / function object model) and produces **Agent Script YAML** (`AiAuthoringBundle` `.agent` files).

**B — Design from use case:** Takes a natural-language description of an agent scenario and recommends which of the **21 validated production patterns** best fits — then scaffolds a skeleton `.agent` file with topics, variables, actions, and guards pre-filled.

There is **no compiled converter, no CLI, no rules engine**. Both modes work by Claude reading:

1. A living spec (`agent-script-spec.md`) — the current Agent Script format.
2. `use-case-patterns.md` — 21 production use cases mapped to Agent Script constructs, covering five agentic pattern families, suitability criteria, and a design-decisions checklist.
3. Five worked examples (input JSON ↔ output `.agent` pairs) covering the common conversion shapes.
4. A short procedural playbook (`conversion-playbook.md`).

When Agent Script evolves, update the spec and (if needed) add a new example. No code to edit, recompile, or deploy.

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

## 3. Org authentication and metadata setup

Before running any deploy, retrieve, or test command you need a Salesforce org authenticated with SF CLI v2. Conversion (Modes 2 and 3 in Section 4) works without an org — but Path B of the walkthrough and any deployment step requires one.

### 3.1 Install SF CLI v2

```bash
npm install -g @salesforce/cli
sf --version          # must be 2.x or higher
sf plugins install @salesforce/plugin-agent   # adds sf agent commands
```

### 3.2 Authenticate your org

The quickest path is the interactive auth helper:

```bash
./scripts/org-auth.sh
```

It prompts you to choose a method, assigns an alias, and verifies the connection. Three methods are supported:

**Browser OAuth (recommended for workstations):**

```bash
# Production / Developer Edition
sf org login web --alias agentforce-dev

# Sandbox
sf org login web --alias agentforce-dev \
  --instance-url https://mycompany--dev.sandbox.my.salesforce.com
```

A browser window opens. Log in with an admin account that has `Modify Metadata` permission.

**JWT bearer (recommended for CI/CD — no browser):**

```bash
sf org login jwt \
  --alias agentforce-ci \
  --client-id <ConsumerKey> \
  --jwt-key-file config/server.key \
  --username ci-user@myorg.example.com
```

Prerequisites: a Connected App in the org with a digital certificate uploaded.
Run `./scripts/org-auth.sh jwt` for guided setup instructions.

**sfdx auth URL (re-authenticate from a saved URL):**

```bash
# Export the URL from an already-authenticated org
sf org display --verbose --json -o agentforce-dev \
  | jq -r '.result.sfdxAuthUrl' > /tmp/authurl.txt

# Authenticate on another machine
sf org login sfdx-url --alias agentforce-dev --sfdx-url-file /tmp/authurl.txt
```

### 3.3 Verify the connection

```bash
sf org display -o agentforce-dev
```

Confirm the org username, instance URL, and status show `Connected`. If the `sf agent` plugin is installed, also run:

```bash
sf org open authoring-bundle -o agentforce-dev
```

This opens Agentforce Studio in the browser — if it loads, the org has Agentforce enabled.

### 3.4 Set a default org (optional but convenient)

```bash
sf config set target-org=agentforce-dev --global
```

Once set, you can drop `-o agentforce-dev` from every command.

### 3.5 Getting your agent's source

Three options depending on what type of agent you have:

**Option A — CLI retrieve for legacy agents (recommended)**

For agents built in the classic Agentforce UI (stored as `GenAiPlugin` / `GenAiFunction`
metadata) — retrieve and assemble in one command:

```bash
# Find the agent's API name first if you don't know it
sf data query --use-tooling-api \
  --query "SELECT DeveloperName, MasterLabel FROM GenAiPlugin LIMIT 20" \
  -o agentforce-dev

# Retrieve and assemble into Shape A JSON
./scripts/retrieve-legacy-agent.sh Agentforce_Service_Agent -o agentforce-dev

# Output: legacy/Agentforce_Service_Agent.json
# Feed it to the conversion skill:
# "Use the agentforce-to-agent-script skill to convert legacy/Agentforce_Service_Agent.json"
```

The script retrieves all `GenAiPlugin` and `GenAiFunction` XML from the org, parses it,
and assembles a Shape A JSON file ready for the conversion skill. Fields that can't be
derived from XML (e.g. `plannerRole`, `plannerCompany`) are emitted as `TODO_REPLACE`
sentinels — the conversion skill flags every one of these in its Notes output.

**Option B — Planner UI export (alternative for legacy agents)**

1. Navigate to `https://your-org.salesforce.com/support/qa/planner.jsp`.
2. Select your agent from the list.
3. Copy or download the JSON configuration.
4. Save locally (e.g. `legacy/my-agent.json`) and pass to the conversion skill.

Use this when the CLI retrieve produces incomplete output (e.g. managed package plugins
whose XML is not retrievable) or when you want the complete planner config including
runtime fields.

**Option C — CLI retrieve for already-migrated agents**

For agents already built or deployed as Agent Script (stored as `AiAuthoringBundle`):

```bash
sf project retrieve start \
  --metadata "AiAuthoringBundle:My_Agent" \
  -o agentforce-dev

# The .agent YAML is written to:
# force-app/main/default/aiAuthoringBundles/My_Agent/My_Agent.agent
```

This gives you the source YAML directly — no conversion needed. Use `developing-agentforce`
to modify it, or review it as-is.

### 3.6 Retrieve any Salesforce metadata

```bash
# Retrieve specific types by name
sf project retrieve start \
  --metadata "AiAuthoringBundle:My_Agent Flow:My_Flow ApexClass:MyClass" \
  -o agentforce-dev

# Retrieve all bundles
sf project retrieve start \
  --metadata "AiAuthoringBundle:*" \
  -o agentforce-dev

# Retrieve permission sets
sf project retrieve start \
  --metadata "PermissionSet:My_Agent_Access" \
  -o agentforce-dev
```

> **Critical:** Use `--metadata` (not `--source-dir`) for agent bundles. Deployment with `--source-dir` can hang if `AiEvaluationDefinition` files are present in the source tree.

### 3.7 Push (deploy) metadata to the org

```bash
# Deploy agent bundle + its backing flows and Apex in one command
sf project deploy start \
  --metadata "AiAuthoringBundle:My_Agent Flow:My_Flow ApexClass:MyClass" \
  -o agentforce-dev

# Validate without deploying (dry run)
sf project deploy start --dry-run \
  --metadata "AiAuthoringBundle:My_Agent" \
  -o agentforce-dev
```

Deployment order matters for dependent metadata — deploy Apex first, then Flows, then the agent bundle. `adlc-engineer` handles this automatically when invoked via the orchestrator.

### 3.8 Full deploy → publish → activate sequence

After deploying the bundle, three more steps are required before the agent is live:

```bash
# 1. Validate the bundle syntax
sf agent validate authoring-bundle --api-name My_Agent -o agentforce-dev

# 2. Publish (creates BotVersion and GenAiPlannerBundle runtime records)
sf agent publish authoring-bundle --api-name My_Agent -o agentforce-dev

# 3. Activate (makes the published version available to users)
sf agent activate --api-name My_Agent_Bot -o agentforce-dev
```

See WALKTHROUGH.md Path B for the full end-to-end walkthrough, and Section 6 of this file for what each ADLC agent does at each phase.

---

## 4. How to use

Five usage modes, from quickest to most complete:

### Mode 1 — Full pipeline via orchestrator (recommended for new migrations)

Hand a legacy JSON to `adlc-orchestrator` and it will run the full life cycle: convert → author → deploy → test → security scan.

> *"Use adlc-orchestrator to convert, deploy, and test /path/to/agent.json against my org."*

The orchestrator runs Phase 0 (legacy conversion via `agentforce-converter`), then hands off to `adlc-author`, `adlc-engineer`, `adlc-qa`, and `securing-agentforce` in sequence, pausing for your approval at the deployment gate.

### Mode 2 — Design a new agent from a use-case description

Describe the agent you want to build in plain language. The skill identifies which of the 21 production patterns best fits, runs a suitability check, and returns a skeleton `.agent` file with design decisions surfaced as `# TODO:` comments.

> *"I need an agent that handles employee HR self-service questions over Slack. What pattern should I use?"*

> *"Design an Agent Script for an outbound voice recruitment pre-screening agent."*

> *"Which Agentforce pattern fits a headless churn-prevention agent triggered by a CRM event?"*

The skill auto-triggers on these design-intent phrases. You get back a scaffolded YAML + a Design Decisions section listing the policy choices a human must answer before the agent is complete. Hand the skeleton to `developing-agentforce` to refine and deploy.

### Mode 3 — Converter skill only (conversion without deployment)

Open a Claude Code session in any directory. Paste or attach the Agentforce JSON, then say something like:

> *"Convert this Agentforce JSON to Agent Script."*

The skill auto-triggers on legacy-format keywords and `plugins[].pluginType === 'TOPIC'` shapes. You get back YAML + Notes. Stop here or hand the YAML off to `developing-agentforce` manually.

### Mode 4 — Subagent (programmatic orchestration)

When invoking from another agent or chaining manually:

```
Agent({
  subagent_type: 'agentforce-converter',
  prompt: 'Convert the Agentforce JSON at /tmp/legacy-agent.json to Agent Script.'
})
```

The subagent returns a single message with two sections: `## YAML` and `## Notes`.

### Mode 5 — Individual skills (targeted tasks)

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

### Mode 6 — Manual (debugging / learning)

Read the skill files yourself and follow the playbook by hand. Useful when you want to understand exactly what Claude is doing or to debug a surprising output.

```
~/.claude/skills/agentforce-to-agent-script/
├── SKILL.md
├── references/
│   ├── agent-script-spec.md       # Agent Script format — the spec
│   ├── use-case-patterns.md       # 21 production patterns mapped to constructs
│   ├── known-input-shapes.md      # legacy JSON shape detection
│   └── conversion-playbook.md     # conversion procedure
└── examples/                       # 5 worked input/output pairs
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
- **Skill** `agentforce-to-agent-script`: `SKILL.md` + 4 reference docs (spec, use-case patterns, input shapes, playbook) + 6 worked input/output example pairs (including example 06 for CLI-assembled retrieved input).
- **Script** `scripts/retrieve-legacy-agent.sh`: retrieves `GenAiPlugin` + `GenAiFunction` XML from an org and assembles a Shape A JSON file ready for the conversion skill.
- **Script** `scripts/assemble_legacy_agent.py`: Python assembler called by the retrieve script — parses XML metadata and builds the planner JSON.
- **Directory** `legacy/`: output directory for assembled JSON files from `retrieve-legacy-agent.sh` (created automatically on first run).
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

- **No CLI, no HTTP server, no compiled converter.** Both modes are pure Claude reasoning over the spec + patterns + examples.
- **No deployment or activation from scratch.** The skill stops at "you have valid YAML." Use `developing-agentforce` (or invoke `adlc-author`) for refinement, then `adlc-engineer` for deployment.
- **No automatic Agent Script version detection.** The skill assumes the format documented in `agent-script-spec.md`. If you're targeting a specific older Agent Script release, edit the spec to match, or use the `nga_interpreter` HTTP API.
- **No conversion rules in code.** All knowledge lives in the spec + patterns reference + examples — that's the point.

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

- **Skill routing:** this skill covers two triggers — legacy-JSON conversion (paste a JSON) and design-from-use-case (describe a scenario and ask which pattern to use or request a skeleton). `developing-agentforce` takes over when you want to *modify* an existing `.agent` file, validate it, or deploy it. If you're unsure, force-invoke: *"Use the agentforce-to-agent-script skill to…"*

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

**When a conversion produces wrong output:**
1. **Add an example.** Create a new folder under `examples/` (e.g. `06-knowledge-grounded/`). Include `input.json`, `output.agent`, and a `notes.md` explaining what's interesting.
2. **Update the spec** if the Agent Script format itself has evolved.
3. **Don't add rules to `conversion-playbook.md`** that aren't backed by either the spec or an example. The playbook is procedural; the rules live elsewhere.
4. **Run the existing examples** as regression checks before committing.

**When a new real-world use case should be added to the patterns reference:**
1. **Update `references/use-case-patterns.md`** — add the use case profile to Section 8 following the existing format (pattern, agent type, channels, constructs, key variables, ROI signal, critical design decision).
2. **Add any new sub-pattern recipe** to Section 9 if the use case introduces a reusable structural pattern not already covered.
3. If the use case represents a new agentic pattern family (beyond the current five), add it to Section 1 with a canonical topic structure.

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
