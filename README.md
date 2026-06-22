# agentforce-converter-claude

A self-contained Claude Code stack that covers the **full Agentforce Agent Development Life Cycle** — from legacy JSON conversion through authoring, deployment, testing, and security assessment.

## Prerequisites

| Requirement | Notes |
|---|---|
| [Claude Code](https://github.com/anthropics/claude-code) | `npm install -g @anthropic-ai/claude-code` |
| Python 3.9+ | Required by the upstream ADLC skill installer |
| curl | Required to pull upstream skills during install |
| [Salesforce CLI v2](https://developer.salesforce.com/tools/salesforcecli) | `npm install -g @salesforce/cli` — required for deploy/test/retrieve; optional for conversion-only use |
| sf agent plugin | `sf plugins install @salesforce/plugin-agent` — required for `sf agent` commands |
| Agentforce-enabled Salesforce org | Required for deploy/test/retrieve phases |

## What's included

### Local (this repo)

| Component | What it does |
|---|---|
| `skills/agentforce-to-agent-script` | Converts legacy Agentforce JSON exports to Agent Script `.agent` YAML; or designs a new agent skeleton from a use-case description using 21 validated production patterns |
| `agents/agentforce-converter.md` | Subagent wrapper — callable by the orchestrator for legacy conversions |
| `agents/adlc-orchestrator.md` | Plan-mode orchestrator for the full 7-phase ADLC (patched to include Phase 0 legacy conversion) |
| `agents/adlc-author.md` | Writes `.agent` files from requirements |
| `agents/adlc-engineer.md` | Scaffolds Flow/Apex metadata and deploys bundles |
| `agents/adlc-qa.md` | Tests agents and optimizes via session trace analysis |

### Upstream (pulled from [SalesforceAIResearch/agentforce-adlc](https://github.com/SalesforceAIResearch/agentforce-adlc) during install)

| Skill | What it does |
|---|---|
| `developing-agentforce` | Author, validate, deploy, publish agents |
| `testing-agentforce` | Smoke tests, batch test suites, CI integration |
| `observing-agentforce` | Production session trace analysis via Data Cloud |
| `securing-agentforce` | OWASP LLM Top 10 security assessment (57 tests, A–F grade) |

## Install

```bash
git clone https://github.com/crmoraes/agentforce-converter-claude ~/Dev/agentforce-converter-claude
cd ~/Dev/agentforce-converter-claude
./scripts/install.sh
```

Requires: Claude Code, Python 3.9+, curl. SF CLI optional (needed for deploy/test/retrieve phases).

The script is idempotent — re-run it after `git pull` to pick up spec or example updates.

## Authenticate your Salesforce org

Required for deploy, retrieve, and test phases. Not needed for conversion or design-from-use-case.

```bash
./scripts/org-auth.sh          # interactive: browser OAuth, JWT, or sfdx auth URL
```

Or directly:

```bash
# Browser OAuth (workstations)
sf org login web --alias agentforce-dev

# JWT bearer (CI/CD)
sf org login jwt --alias agentforce-ci \
  --client-id <ConsumerKey> --jwt-key-file config/server.key \
  --username ci-user@myorg.example.com

# Set as default to avoid -o on every command
sf config set target-org=agentforce-dev --global
```

See [HOWTO.md §3](./HOWTO.md) for full setup, connection verification, and retrieve/deploy reference.

## Two starting points

**Start from a use-case description (new agent):**

```
I need an agent that handles HR self-service questions for employees. What pattern
should I use and how should I structure the Agent Script?
```

The skill reads 21 validated production patterns, matches your scenario, runs a
suitability check, and scaffolds a skeleton `.agent` file with topics, variables,
and actions pre-filled — plus a list of design decisions you must answer.

**Start from a legacy JSON export (migration):**

```
Use the agentforce-to-agent-script skill to convert /path/to/agent.json
```

## Full pipeline (legacy JSON → live agent)

```
Org (legacy agent)               Planner UI export        Use-case description
    │                                    │                        │
    ▼  retrieve-legacy-agent.sh          │                        │
    │  Retrieves XML, assembles JSON     │                        │
    └──────────────┬─────────────────────┘                        │
                   │ legacy/<name>.json                           │
    ▼  Phase 0 — agentforce-converter    ▼  agentforce-to-agent-script (Mode B)
    │  Converts JSON to .agent YAML      │  Scaffolds .agent skeleton from pattern
    │
    ▼  Phase 1 — Requirements review
    │  Resolve placeholder targets and design decisions
    │
    ▼  Phase 2 — adlc-author (developing-agentforce)
    │  Refines/finalizes the .agent file
    │
    ▼  Phase 3+4 — adlc-engineer (developing-agentforce)
    │  Discovers missing flows/apex, scaffolds stubs, deploys
    │
    ▼  Phase 5 — Deploy, publish, activate
    │
    ▼  Phase 6 — adlc-qa (testing-agentforce)
    │  Smoke tests, trace analysis, optimization
    │
    ▼  Phase 7 — adlc-qa → securing-agentforce
       OWASP LLM Top 10 security assessment
```

Drive the whole pipeline with one prompt:

```
Use adlc-orchestrator to convert, deploy, and test /path/to/agent.json against my org.
```

Or use each piece independently:

```
# Design a new agent from a use-case description
Which Agent Script pattern should I use for an outbound voice recruitment agent?

# Convert a legacy JSON export
Use the agentforce-to-agent-script skill to convert /path/to/agent.json

# Deploy only (if you already have a .agent file)
Use developing-agentforce to validate and publish My_Agent to my org.

# Test only
Use testing-agentforce to run smoke tests on My_Agent.

# Security scan only
Use securing-agentforce to run a full assessment on My_Agent.
```

## Getting your legacy Agentforce JSON

1. Navigate to your Salesforce org.
2. Append `/support/qa/planner.jsp` to the base URL.
3. Select your agent and copy/download the JSON.

See [WALKTHROUGH.md](./WALKTHROUGH.md) for a step-by-step tutorial using the included sample agent (Path A: conversion only; Path B: full ADLC pipeline).

See [HOWTO.md](./HOWTO.md) for the full reference guide, known limitations, and troubleshooting.

## Architecture

No compiled converter, no rules engine. The skill works by:

1. Loading a living spec (`agent-script-spec.md`) — the single source of truth for Agent Script format.
2. Reading `use-case-patterns.md` — 21 validated production patterns mapped to Agent Script constructs.
3. Matching against five worked examples (input JSON ↔ output `.agent` pairs) for conversion.
4. Following a short procedural playbook.

When Agent Script evolves, update the spec and (optionally) add a new example — no code to change.

## Updating

```bash
git pull
./scripts/install.sh   # re-installs local files + pulls latest upstream skills
```
