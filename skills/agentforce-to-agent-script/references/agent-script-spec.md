# AI LLM Skill: Salesforce Agentforce Script Expert

**Name:** agentforce-script-expert
**Version:** 3.1.0
**Updated:** 2026-04-02
**Description:** Comprehensive reference for designing, reviewing, and fixing Salesforce Agentforce Scripts (NGA format). Covers all YAML blocks, syntax rules, variable management, action definitions, control logic, and best practices for deterministic agent behavior.

---

## Table of Contents
1. [Core Architecture & Logical Blocks](#1-core-architecture--logical-blocks)
2. [YAML Structure: Keys & Indentation](#2-yaml-structure-keys--indentation)
3. [Complete File Skeleton](#3-complete-file-skeleton)
4. [Variables](#4-variables)
5. [Actions: Full Field Reference](#5-actions-full-field-reference)
6. [@utils Utilities & Routing](#6-utils-utilities--routing)
7. [before_reasoning & after_reasoning](#7-before_reasoning--after_reasoning)
8. [Instructions & Expressions](#8-instructions--expressions)
9. [The 5 Levels of Determinism](#9-the-5-levels-of-determinism)
10. [Standard Library Functions](#10-standard-library-functions)
11. [Customer Verification Pattern](#11-customer-verification-pattern)
12. [Anti-Patterns & Constraints](#12-anti-patterns--constraints)
13. [Agent Metadata & Lifecycle](#13-agent-metadata--lifecycle)
14. [Salesforce CLI Reference](#14-salesforce-cli-reference)
15. [Agent Access & Permissions](#15-agent-access--permissions)
16. [Agent User Setup](#16-agent-user-setup)
17. [Topic-Level System Overrides](#17-topic-level-system-overrides)
18. [N-ary Conditions & Complex Logic](#18-n-ary-conditions--complex-logic)
19. [Escalation & Connection Block](#19-escalation--connection-block)
20. [Validation, Debugging & Production Gotchas](#20-validation-debugging--production-gotchas)
21. [Known Platform Issues & Workarounds](#21-known-platform-issues--workarounds)
22. [Action Chaining & Sequencing](#22-action-chaining--sequencing)
23. [Variables: Lists & Index Iteration](#23-variables-lists--index-iteration)
24. [Context Engineering](#24-context-engineering)
25. [Daisy++ (Unified Planner) Migration](#25-daisy-unified-planner-migration)
26. [Performance & Observability](#26-performance--observability)

---

## 1. Core Architecture & Logical Blocks

Agent Script orchestrates the Atlas Reasoning Engine by combining natural language flexibility with programmatic determinism. Every file is composed of these top-level blocks (declared in this order):

| Block | Purpose |
|---|---|
| `system:` | Global persona, welcome/error messages applied across all topics |
| `config:` | Agent metadata: name, type, description |
| `variables:` | Session-scoped state trackers (mutable or linked to CRM) |
| `language:` | Locale configuration |
| `connection <type>:` | Channel settings (`messaging` or `voice`) |
| `start_agent <name>:` | Entry point — evaluates intent and routes to the first topic |
| `topic <name>:` | Domain-specific handler (one per "Job to be Done") |

### Agent Types
The `config.agent_type` field must be one of:
- `AgentforceServiceAgent` — customer-facing service agent
- `AgentforceEmployeeAgent` — internal employee-facing agent

### Instruction Modes
Inside a `reasoning:` block, instructions use one of two modes:
- **Template mode** (`instructions: |`) — static text with simple variable injection only
- **Procedural mode** (`instructions: ->`) — executes logic alongside text; all plain-text lines must be prefixed with `|`

### Topic Design Architecture

**Rule of 10:** No more than 10 topics per agent. The topic classification prompt degrades beyond this limit — keep the topic set small and semantically distinct.

**Bottom-Up 4-Step Approach** (use when designing topics from scratch):
1. **Inventory Granular Actions** — list every specific task the agent must perform (e.g., "Check Inventory", "Update Address").
2. **Analyze Semantic Distance** — identify action pairs with similar descriptions. If "Troubleshooting" and "Product Support" descriptions overlap, they will cause misclassification.
3. **Group for Semantic Distinction** — create topics that are semantically distinct from one another.
4. **Define Classification Descriptions** — write a concise, one-sentence description per topic. This is the *only* metadata the engine uses to select a topic.

**Critical — Instructions do NOT influence topic selection.** Only the Topic Name and Classification Description are sent to the topic selection prompt. Instructions only guide behavior *after* a topic is chosen. Over-investing in instructions to fix routing problems will not work — fix the descriptions instead.

**Semantic Overlap Failure:** If two actions or topics in the same agent have nearly identical descriptions (e.g., "Modify Order" and "Update Shipment"), the reasoning engine will fluctuate between them non-deterministically. Maintain clear semantic distance between all topic and action descriptions.

**Topic Selector anti-pattern — responding directly:** Without an explicit instruction in the topic selector such as `"THE ONLY purpose of this topic is to route. NEVER respond directly from this topic. ALWAYS route to an appropriate topic first."`, the agent may bypass routing and reply from the selector itself.

---

## 2. YAML Structure: Keys & Indentation

### Topic Key Naming
Keys use a **compound format**: `<block_type> <identifier>`

```yaml
start_agent topic_selector:    # entry point — always this exact compound key
topic order_status:            # a regular topic
topic customer_verification:   # another topic
```

The identifier portion must be `snake_case` with no spaces. The `start_agent` block is always named `start_agent topic_selector`.

### Indentation Reference
Agent Script YAML uses **spaces only** (no tabs). Levels are strict:

```yaml
system:                                    # 0 — top-level block
    instructions: "..."                    # 4 spaces
    messages:                              # 4 spaces
        welcome: "..."                     # 8 spaces
        error: "..."                       # 8 spaces

config:                                    # 0 — top-level block
  agent_label: "..."                       # 2 spaces  ← config uses 2-space indent
  developer_name: "..."                    # 2 spaces
  agent_type: "..."                        # 2 spaces
  description: "..."                       # 2 spaces

variables:                                 # 0
    my_var: mutable string = ""            # 4 spaces — declaration
        description: "..."                 # 8 spaces
    crm_var: linked string                 # 4 spaces
        source: @MessagingSession.Id       # 8 spaces
        description: "..."                 # 8 spaces

language:                                  # 0
    default_locale: "en_US"               # 4 spaces
    additional_locales: ""                 # 4 spaces
    all_additional_locales: False          # 4 spaces

connection messaging:                      # 0
    adaptive_response_allowed: True        # 4 spaces

topic my_topic:                            # 0
    label: "..."                           # 4 spaces
    description: "..."                     # 4 spaces
    reasoning:                             # 4 spaces
        before_reasoning:                  # 8 spaces
            if @variables.x == "y":        # 12 spaces
                transition to @topic.z     # 16 spaces
        instructions: ->                   # 8 spaces
            | Do something.               # 12 spaces — procedural text line
        after_reasoning:                   # 8 spaces
            if @variables.done == True:    # 12 spaces
                transition to @topic.next  # 16 spaces
        actions:                           # 8 spaces — reasoning action references
            my_action: @actions.my_action  # 12 spaces
                with param = ...           # 16 spaces — slot-fill
    actions:                               # 4 spaces — action definitions
        my_action:                         # 8 spaces
            description: "..."             # 12 spaces
            target: "flow://..."           # 12 spaces
            inputs:                        # 12 spaces
                "inputName": string        # 16 spaces — name is quoted
                    is_required: True      # 20 spaces
            outputs:                       # 12 spaces
                "outputName": string       # 16 spaces — name is quoted
                    is_displayable: False  # 20 spaces
```

---

## 3. Complete File Skeleton

Minimal but complete agent showing all blocks and their relationships:

```yaml
system:
    instructions: "You are a helpful service agent for Acme Corp."
    messages:
        welcome: "Hi, I'm the Acme Assistant. How can I help you today?"
        error: "Sorry, something went wrong. Please try again."

config:
  default_agent_user: "agentforce_service_agent@acme.ext"
  agent_label: "Acme Service Agent"
  developer_name: "Acme_Service_Agent"
  agent_type: "AgentforceServiceAgent"
  description: "Handles customer service requests for Acme Corp."

variables:
    IsVerified: mutable boolean = False
        description: "Whether the customer has been verified."
    ContactId: linked string
        source: @MessagingEndUser.ContactId
        description: "Salesforce Contact ID of the messaging user."

language:
    default_locale: "en_US"
    additional_locales: ""
    all_additional_locales: False

connection messaging:
    adaptive_response_allowed: True

start_agent topic_selector:
    label: "Topic Selector"
    description: "Routes user to the correct topic based on intent."
    reasoning:
        instructions: ->
            | Select the best tool based on the user's intent.
        actions:
            go_to_order_status: @utils.transition to @topic.order_status
            go_to_escalation: @utils.transition to @topic.escalation

topic order_status:
    label: "Order Status"
    description: "Handles order status enquiries."
    reasoning:
        before_reasoning:
            if @variables.IsVerified == False:
                transition to @topic.customer_verification
        instructions: ->
            | Retrieve the order status and present it to the user.
            | ALWAYS call get_order_status before answering.
        actions:
            get_order_status: @actions.get_order_status
                with orderId = ...
    actions:
        get_order_status:
            description: "Retrieves order status from the backend system."
            require_user_confirmation: False
            include_in_progress_indicator: True
            progress_indicator_message: "Looking up your order..."
            target: "flow://Get_Order_Status"
            inputs:
                "orderId": string
                    description: "The order ID to look up."
                    is_required: True
                    is_user_input: True
                    complex_data_type_name: "lightning__textType"
            outputs:
                "status": string
                    description: "The current order status."
                    is_displayable: True
                    is_used_by_planner: True
                    complex_data_type_name: "lightning__textType"

topic escalation:
    label: "Escalation"
    description: "Transfers the user to a live human agent."
    reasoning:
        instructions: ->
            | Transfer the user to a live agent if they explicitly request it.
            | If escalation fails, offer to log a support case instead.
        actions:
            escalate_to_human: @utils.escalate
```

---

## 4. Variables

### Declaration Syntax

```yaml
variables:
    # Mutable — read/write, requires a default value
    order_count:   mutable number = 0
        description: "Number of orders retrieved this session."
    status_flag:   mutable boolean = False
        description: "Tracks whether processing is complete."
    selected_item: mutable string = ""
        description: "Item selected by the user."
    results:       mutable list[object] = []
        description: "List of search results."

    # Linked — read-only, bound to a Salesforce CRM record field
    session_id: linked string
        source: @MessagingSession.Id
        description: "Current messaging session ID."
    contact_id: linked string
        source: @MessagingEndUser.ContactId
        description: "Contact ID of the end user."
```

### Supported Types

| Type | Mutable | Linked |
|---|---|---|
| `string` | ✓ | ✓ |
| `number` | ✓ | ✓ |
| `boolean` | ✓ | ✓ |
| `date` | ✓ | ✓ |
| `timestamp` | ✓ | ✓ |
| `currency` | ✓ | ✓ |
| `id` | ✓ | ✓ |
| `object` | ✓ only | ✗ |
| `list[string]`, `list[number]`, `list[object]`, etc. | ✓ only | ✗ |

**Rules:**
- `linked` variables **cannot** use `object` or `list` types — scalars only
- `linked` variables **do not** have a default value
- `mutable` variables **must** have a default value (e.g., `""`, `0`, `False`, `[]`)

### Common Linked Sources

| Source | Description |
|---|---|
| `@MessagingSession.Id` | Current session ID |
| `@MessagingSession.MessagingEndUserId` | End user platform ID |
| `@MessagingSession.EndUserLanguage` | End user preferred language |
| `@MessagingEndUser.ContactId` | Salesforce Contact ID |
| `@MessagingEndUser.Name` | End user display name |

### In-Instruction Variable Usage

```yaml
instructions: ->
    | set @variables.status = "pending"
    | set @variables.count = @variables.count + 1
    | set @variables.caseId = @outputs.caseId        # capture action output
    | The case ID is {!@variables.caseId}.            # inject into prompt text
    | run @actions.create_case                        # force deterministic execution
```

---

## 5. Actions: Full Field Reference

### Reasoning Block Reference (inside `reasoning.actions:`)
Links the LLM to an action and controls how it is invoked.

```yaml
reasoning:
    actions:
        my_action: @actions.my_action              # reference to defined action
            with orderId = ...                     # slot-fill: LLM extracts from conversation
            with customerId = @variables.cid       # explicit bind: uses variable value
            available when @variables.IsVerified == True   # gate: LLM cannot see this unless true
            description: "Use this to retrieve order details."
```

**Rules:**
- Only **one `available when` clause** per action. Use `and`/`or` for multiple conditions.
- `with param = ...` (slot-fill) should be kept to 4 or fewer per action to avoid interrogation loops.

### Action Definition Block (inside topic `actions:`)

```yaml
actions:
    action_name:
        description: "What this does — used by the LLM to decide when to call it."
        label: "Human-readable label"                      # optional
        require_user_confirmation: False                   # prompt user before executing
        include_in_progress_indicator: True                # show a spinner while running
        progress_indicator_message: "Looking that up..."   # spinner text (optional)
        source: "My_Flow_API_Name"                         # Salesforce API name (optional)
        target: "flow://My_Flow_API_Name"                  # required — invocation URI
        inputs:
            "paramName": string                            # quoted name, then type
                description: "What this input is for."
                label: "Param Label"
                is_required: True                          # True = action fails if missing
                is_user_input: True                        # False = system/internal param, skipped by LLM
                complex_data_type_name: "lightning__textType"
        outputs:
            "outputName": string                           # quoted name, then type
                description: "What this output contains."
                label: "Output Label"
                is_displayable: False                      # False = LLM cannot show raw value to user
                is_used_by_planner: True                   # True = LLM can reason about this value
                complex_data_type_name: "lightning__textType"
```

### Action Target Protocols

| Protocol | Usage |
|---|---|
| `flow://FlowApiName` | Salesforce Flow |
| `apex://ClassName` | Apex invocable method |
| `<prompt://TemplateName>` | Prompt Template (LLM sub-call) — preferred format |
| `generatePromptResponse://TemplateName` | Prompt Template (legacy format — avoid in new authoring) |
| `api://EndpointName` | External API |
| `externalService://ServiceName` | External Service |
| `standardInvocableAction://ActionName` | Standard invocable action |
| `retriever://ConfigName` | RAG knowledge retrieval |

### `complex_data_type_name` Mapping

| NGA Type | `complex_data_type_name` |
|---|---|
| `string` | `lightning__textType` |
| `number` | `lightning__numberType` |
| `boolean` | `lightning__booleanType` |
| `object` | `lightning__recordInfoType` |
| `list[object]` | `lightning__recordInfoType` |
| `list[string]` | `lightning__textType` |
| Rich text / HTML | `lightning__richTextType` → stored as `object` |

### Output Flags — Zero-Hallucination Guardrails

| Flag | Value | Effect |
|---|---|---|
| `is_displayable` | `False` | LLM **cannot** show this value to the user |
| `is_displayable` | `True` | LLM may render this value in its response |
| `is_used_by_planner` | `True` | LLM can reason about this value for next steps |
| `is_used_by_planner` | `False` | LLM is completely blind to this value |
| `filter_from_agent` | `True` | Hides output from user-facing response while still allowing planner use; prevents hallucination on large/complex responses |

**Pattern:** Sensitive backend data (IDs, internal codes) → `is_displayable: False`, `is_used_by_planner: True`

**Pattern:** Large action responses (records, lists) → also add `filter_from_agent: True` to prevent state corruption from oversized payloads.

### Stub (Placeholder) Actions

Use placeholder stub actions to compile and validate agents without the backing Flow/Apex implementation being ready (available 260.14+). The action passes validation as long as the target follows the correct URI format — the backing implementation can be added later.

```yaml
actions:
    get_order_details:
        description: "Retrieves order details. (STUB — backing flow not yet deployed)"
        target: "flow://Get_Order_Details_REPLACE_ME"
        inputs:
            "orderId": string
                is_required: True
        outputs:
            "status": string
                is_displayable: True
```

### model_config — Confirmed Models Only

Only these models are confirmed for tool-calling (as of June 2026). Others fail **silently** at runtime:
- `llmgateway__GPT41` (GPT-4.1) — default for general reasoning
- `claude-sonnet-4` / `claude-haiku-4-5` — strong reasoning
- `gemini-flash` (Gemini 3.x Flash) — high-volume, fast
- `sfdc_ai__DefaultEinsteinHyperClassifier` — routing/classification only (~95ms), no `before/after_reasoning` hooks

Do NOT configure `model_config` with untested models (e.g., GPT-3.5-turbo, other Anthropic model IDs not listed above). They fail silently at runtime.

---

## 6. @utils Utilities & Routing

### Complete @utils Reference

| Utility | Syntax | Description |
|---|---|---|
| `@utils.transition` | `@utils.transition to @topic.<name>` | Permanent handoff to another topic |
| `@utils.escalate` | `@utils.escalate` | Transfer conversation to a live human agent |
| `@utils.setVariables` | `@utils.setVariables` | Slot-fill multiple variables from conversation in a single LLM turn |
| `@utils.end_session` | `@utils.end_session` | Terminate the session cleanly (available 260.14+). Use instead of leaving sessions orphaned after completion. |
| `@topic.X` | `@topic.X` in `reasoning.actions` | Delegate to child topic; control returns to parent to synthesize response |

> **Note:** `@utils.setVariables` is useful when you need to collect several values at once without calling a full action. The LLM fills the declared variables from the conversation context.

### Three Routing Patterns

| Pattern | Syntax | Who generates response | When to use |
|---|---|---|---|
| **Handoff (Transition)** | `@utils.transition to @topic.X` in `reasoning.actions` | Child topic | Terminal states, escalations, phase changes |
| **Supervision (Delegation)** | `@topic.X` in `reasoning.actions` | Parent topic synthesizes | DRY sub-routines, shared action sets |
| **Deterministic Jump** | `transition to @topic.X` in `before/after_reasoning` | Next topic | Conditional routing with no LLM involvement |

### DRY Architecture via Supervision

Define a shared action once in a delegate topic. All other topics reference it via supervision — control returns to the caller after execution.

```yaml
topic order_management:
    reasoning:
        instructions: ->
            | Handle the user's order request using the appropriate action.
        actions:
            check_order:  @topic.order_lookup    # delegates — control returns here
            cancel_order: @topic.order_cancel    # delegates — control returns here
```

---

## 7. before_reasoning & after_reasoning

These blocks execute **outside the LLM context** — 100% deterministic, no AI credit consumed, no hallucination possible. They are the primary tool for enforcing critical business logic.

### Placement
Both blocks sit directly under `reasoning:`, at the same level as `instructions:` and `actions:`.

### Syntax Rules
- Content goes **directly** under the block — no `instructions:` wrapper, no `|` prefix
- Supports: `if/then`, `transition to`, `run`, `set`
- Use `transition to @topic.X` (no `@utils.` prefix) — this is the deterministic jump form
- No nested `if` — use compound `and`/`or` conditions

### before_reasoning
Executes **before** the LLM processes the turn. Use for: guard clauses, enforcing preconditions, pre-loading state.

```yaml
reasoning:
    before_reasoning:
        if @variables.IsVerified == False:
            transition to @topic.customer_verification
        if @variables.case_created == True:
            transition to @topic.case_confirmation
        run @actions.load_customer_profile
    instructions: ->
        | Help the customer with their request.
```

### after_reasoning
Executes **after** the LLM responds. Use for: advancing a state machine, post-condition checks, completion detection.

```yaml
reasoning:
    instructions: ->
        | Collect the required information from the user.
    after_reasoning:
        if @variables.all_fields_collected == True:
            transition to @topic.submit_request
        if @variables.retry_count >= 3:
            transition to @topic.escalation
```

### Same-Turn Variable Availability
Variables set by actions called during the **current turn** are available in `after_reasoning`. However, if the LLM chose *not* to call the action, the variable retains its previous value. To guarantee the variable is set, use `run @actions.name` inside `instructions:` to force the call before `after_reasoning` evaluates.

---

## 8. Instructions & Expressions

### Safe Operator Set

| Category | Supported | NOT Supported |
|---|---|---|
| Comparison | `==`, `<>`, `<`, `<=`, `>`, `>=`, `is`, `is not` | — |
| Logical | `and`, `or`, `not` | — |
| Arithmetic | `+`, `-` | `*`, `/`, `%` |
| Nesting | compound `if x and y:` | nested `if x: then if y:` |

### Procedural Instruction Patterns

```yaml
instructions: ->
    # Variable assignment
    | set @variables.status = "active"

    # Capture action output into a variable
    | set @variables.caseId = @outputs.caseId

    # Inject variable value into prompt text
    | The case ID is {!@variables.caseId}.

    # Force an action — LLM cannot skip this call
    | run @actions.create_case

    # Conditional transition
    | if @variables.IsVerified == False:
    |     transition to @topic.verification

    # Compound condition
    | if @variables.attempt_count >= 3 and @variables.IsVerified == False:
    |     transition to @topic.escalation
```

### available when (Action/Topic Gating)
Prevents the LLM from seeing an action unless a condition is met. **One clause per action only** — combine multiple conditions with `and`/`or`.

```yaml
reasoning:
    actions:
        submit_case: @actions.submit_case
            available when @variables.IsVerified == True
        premium_support: @actions.premium_support
            available when @variables.tier == "premium" and @variables.IsVerified == True
```

### Prompt Engineering Guidelines
- Use **commanding verbs**: "Retrieve", "Verify", "Calculate", "Confirm"
- Use **capitalization** for hard boundaries: `ALWAYS`, `NEVER`, `DO NOT`
- Use **RAG actions** (`retriever://`) for complex policies instead of hard-coding rules in instructions
- Keep topics to **~25–40 lines** of instructions. Beyond that, decompose into phase topics.

### Instruction Quality Pitfalls

**Sequence Enforcement:** Agentforce treats separate UI instruction boxes as an unordered group. If Step A must happen before Step B, they MUST be combined into a single instruction block — do not rely on order of entry.

**Strict Output Adherence (regulated industries):** In Legal/Finance contexts, use the `promptResponse` reference to prevent the agent from rephrasing validated outputs. Example: `"Do not change promptResponse output. Deliver the text exactly as provided."`

**Avoid Overscripting:** Do not try to predict every conversational exchange.
- Bad: `"If user says 'How are you', say 'I am an AI.'"`
- Better: `"Maintain a professional and empathetic persona at all times."`

**Instruction Drift & Context Rot:** In long conversations (20+ exchanges), agents can lose track of original constraints even with large context windows. An agent configured to recommend only specific product categories may start suggesting items outside those categories after extended sessions. Fix:
- Periodically restate critical constraints in instructions.
- Use "System Reminder" sections within instructions.
- Use `before_reasoning` to re-evaluate key variable conditions on every turn.

**Overloaded Instructions:** An agent with 50+ rules shows inconsistent behavior — it may follow rule #12 sometimes and ignore it depending on conversation flow. Fix with Layered Prompting:
1. TIER 1: Generate a summary for all users.
2. TIER 2: Ask "Would you like details for [specific role/context]?"
3. Provide targeted response based on selection.

**`after_reasoning` deprecation (post-Daisy++):** `after_reasoning` was accidentally functional in old Daisy — that behavior was a bug, now fixed. Remove all `after_reasoning` hooks and implement correct patterns using `before_reasoning` or topic transitions instead.

---

## 9. The 5 Levels of Determinism

Apply progressively when designing or refactoring. Higher levels give more control but require more explicit design.

| Level | Technique | When to use |
|---|---|---|
| **1. Instruction-free** | No instructions — pure LLM autonomy | Prototyping only |
| **2. Instructions** | Natural language `instructions:` block | Guiding tone, scope, and behavior |
| **3. Data Grounding** | `retriever://` RAG, Prompt Templates | Preventing knowledge hallucination |
| **4. Variables** | State tracking + `available when` gating | Multi-step flows, conditional logic |
| **5. Deterministic Actions** | `before/after_reasoning`, `run @actions.x`, forced transitions | Critical operations — financial, legal, case creation |

### Phase Decomposition Pattern
Break any topic exceeding ~30 lines into dedicated phase topics. Use `after_reasoning` to advance phases without LLM involvement:

```
[collect_info] --(after_reasoning: all_fields_collected == True)--> [confirm_details]
                                                                    --(after_reasoning: confirmed == True)--> [submit]
```

Each phase topic is ~25 lines max, has a single clear responsibility, and transitions deterministically to the next.

---

## 10. Standard Library Functions

**Text Functions:**
- `text.contains(string, substring)` → `boolean`
- `text.concat(string1, string2)` → `string`
- `text.is_empty(string)` → `boolean` (true if null or empty string)

**List Functions:**
- `list.length(list)` → `number`
- `list.contains(list, item)` → `boolean`
- `list.add(list, item)` → `list` (returns new list with item appended)

**Date Functions:**
- `date.today()` → `date` (current date)
- `date.now()` → `timestamp` (current datetime)

**Usage in procedural instructions:**

```yaml
instructions: ->
    | if text.is_empty(@variables.email):
    |     set @variables.status = "missing_email"
    | if list.contains(@variables.selected_items, "premium"):
    |     transition to @topic.premium_flow
    | if list.length(@variables.results) == 0:
    |     transition to @topic.no_results
```

---

## 11. Customer Verification Pattern

When a topic related to customer verification or identity authentication exists, declare this canonical variable set. These names and sources are the standard for all auth flows.

```yaml
variables:
    # Linked — from CRM session context (read-only)
    EndUserId: linked string
        source: @MessagingSession.MessagingEndUserId
        description: "End user platform ID. Also referred to as MessagingEndUser Id."
    RoutableId: linked string
        source: @MessagingSession.Id
        description: "Current session ID. Also referred to as MessagingSession Id."
    ContactId: linked string
        source: @MessagingEndUser.ContactId
        description: "Salesforce Contact ID of the end user."
    EndUserLanguage: linked string
        source: @MessagingSession.EndUserLanguage
        description: "End user preferred language."

    # Mutable — written during the verification flow
    VerifiedCustomerId: mutable string = ""
        description: "Stores the verified customer ID after successful authentication."
    VerificationAttempts: mutable number = 0
        description: "Tracks the number of failed verification attempts."
    IsVerified: mutable boolean = False
        description: "Whether the customer has been successfully verified."
```

**Guard pattern** — add to `before_reasoning` in every sensitive topic:

```yaml
before_reasoning:
    if @variables.IsVerified == False:
        transition to @topic.customer_verification
```

**Lockout pattern** — inside the verification topic's `after_reasoning`:

```yaml
after_reasoning:
    if @variables.IsVerified == True:
        transition to @topic.topic_selector
    if @variables.VerificationAttempts >= 3:
        transition to @topic.escalation
```

---

## 12. Anti-Patterns & Constraints

1. **Manual topic tracking**: Do not use `set @variables.current_topic = "X"`. The framework tracks state natively — duplicating it creates synchronization bugs.

2. **`actions:` at root level**: `actions:` may only exist inside a `topic <name>:` block, never at the top level of the file.

3. **Missing required inputs**: Actions with `is_required: True` inputs fail silently if the input is not bound. Always bind or slot-fill every required input.

4. **Too many slot-fills**: More than 4–5 `with param = ...` per action causes interrogation loops and increases hallucination risk. Pre-bind from variables wherever possible.

5. **Same-turn variable race condition**: Checking a variable in `after_reasoning` that was supposed to be set by an action the LLM *might not have called*. Fix: use `run @actions.name` in `instructions:` to force the call, or handle the unset case explicitly in `after_reasoning`.

6. **`object` or `list` type as `linked`**: Only scalar types (`string`, `number`, `boolean`, `date`, etc.) can be `linked`. Objects and lists must always be `mutable`.

7. **Nested `if` statements**: `if x: then if y:` is not supported. Use `if x and y:` or flatten into sequential statements.

8. **`instructions:` wrapper in before/after_reasoning**: These blocks must not use an `instructions:` key or `|` prefixes. Direct statements only.

9. **Circular topic references**: The runtime caps iterations at ~3–4 per turn. Circular transitions will break out and revert to the Topic Selector.

10. **Multiple `available when` clauses**: Only one `available when` per action is supported. Combine conditions using `and`/`or`.

11. **`is_user_input: False` on fields the user must provide**: Setting `is_user_input: False` tells the LLM the value is a system/internal parameter and it will not prompt the user for it. Only use this for params populated from variables or constants.

12. **Monolithic topics**: Topics with hundreds of lines overload the LLM context window, causing hallucination and cognitive overload. Break into phase topics of ~25–40 lines each with deterministic `after_reasoning` transitions between them.

13. **`#` characters in reasoning instructions**: `#` is parsed as a comment marker, causing cascading compile errors. Wrap channel names or any `#`-prefixed strings in **double** quotes (single quotes are not sufficient). Example: use `"#support-channel"` not `'#support-channel'`.

14. **`set @variables.X = []` in the body**: The empty-list literal `[]` is only valid as a variable initializer (in the `variables:` block). Using it in an instruction body causes a runtime error. Use `= None` or a sentinel variable instead.

15. **`complex_data_type_name` on primitive types**: Setting `complex_data_type_name` on `string`, `number`, or `boolean` action parameters is a hard error in 262.10. Only `object` and `list[object]` may carry `complex_data_type_name`.

16. **`lightning__objectType` on record inputs**: Use `lightning__recordInfoType` (not `lightning__objectType`) for `UpdateRecordFields` and `recordDetailInput` parameters. Fixed in 260.13+.

17. **Action fires twice**: If an action is called deterministically via `{!@actions.X}` in instructions, it will fire twice post-Daisy++ if the same action is also listed in `reasoning.actions`. Fix: remove it from `reasoning.actions` when calling it deterministically only.

18. **`agent_name` is deprecated**: Use `developer_name` in `config:`. The `agent_name` field is legacy and will be removed in a future release.

19. **Suppressing default follow-up prompts is non-deterministic**: The base system prompt injects follow-up question behavior. Override via `system:` instructions, but this works inconsistently — it sometimes suppresses, sometimes does not. This is a known platform limitation as of 260.13+.

20. **Actions skipped in sequential logic (same-turn dependency)**: Action B depends on a variable set by Action A within the same reasoning loop iteration — Action B never executes because the variable isn't available yet. Fix: use a Two-Step Topic Pattern — Topic 1 gathers info and stores to variable (no conditional logic), Topic 2 reads stored variable and executes conditional logic. Alternative: move complex conditional logic to an Apex invocable method.

---

*(Note: ISSUE-001 — instructions resolving only on topic entry — was resolved February 2026. Variables now correctly re-evaluate across iterations within the same turn. Run-then-if patterns within the same topic are valid.)*

---

## 13. Agent Metadata & Lifecycle

### Two Independent Metadata Domains

```
AUTHORING DOMAIN (developer-owned, exists before any publish)
  AiAuthoringBundle
    ├── .agent                  (Agent Script source — the editable text file)
    └── .bundle-meta.xml        (metadata; optional <target> links to published version)

RUNTIME DOMAIN (created by publish — do NOT edit directly)
  Bot                           (top-level container, one per agent)
    └── BotVersion              (one per published version)
          └── GenAiPlannerBundle (versioned compiled bundle)
                └── local topics and actions
```

**AiAuthoringBundle forms:**
- **Naked** (e.g., `My_Agent`) — always points to the highest DRAFT; the only writable surface
- **Version-suffixed** (e.g., `My_Agent_1`) — frozen snapshot; read-only

**Retrieve after publish** locks the authoring bundle via a `<target>` tag in `bundle-meta.xml`. Recovery: remove `<target>` from bundle-meta.xml and redeploy.

**`Agent:X` pseudo-type** covers the runtime domain (Bot, BotVersion, GenAiPlannerBundle). Does **NOT** include AiAuthoringBundle.

### File Locations

```
<packageDirectory>/main/default/aiAuthoringBundles/<Developer_Name>/
    <Developer_Name>.agent
    <Developer_Name>.bundle-meta.xml
```

### Deploy vs. Publish

| Operation | What it does | Creates runtime? |
|---|---|---|
| `sf project deploy start` | Stages `AiAuthoringBundle` metadata | No |
| `sf agent publish authoring-bundle` | Creates Bot + BotVersion + GenAiPlannerBundle | Yes |

### Recommended 6-Step Pipeline

```bash
# 1. Generate boilerplate (--no-spec is MANDATORY — omitting causes CLI hang)
sf agent generate authoring-bundle --json --no-spec --name "My Agent" --api-name My_Agent

# 2. Edit the .agent file

# 3. Deploy (stages metadata, validates backing logic existence via Invocable Action Registry)
sf project deploy start --json --metadata AiAuthoringBundle:My_Agent

# 4. Validate syntax
sf agent validate authoring-bundle --json --api-name My_Agent

# 5. Publish (creates runtime entities)
sf agent publish authoring-bundle --json --api-name My_Agent

# 6. Activate
sf agent activate --json --api-name My_Agent_Bot
```

**Deploy validation note:** Deploy checks that referenced flows/apex classes *exist* via the Invocable Action Registry, but does NOT validate parameter names or types.

### Lifecycle Operations

| Operation | Notes |
|---|---|
| Delete | DRAFT-only agents can be deleted via CLI; published agents require Setup UI |
| Rename | Do not rename in-place; create a new agent with the desired name |
| Open in Builder | `sf org open authoring-bundle` (all) or `sf org open agent --api-name <Bot>` |
| Test lifecycle | `sf agent test create` → `sf agent test run --wait 5` → `sf agent test results` |

**Tests run against activated published agents only.** `sf agent test create` does NOT auto-deploy to the org.

---

## 14. Salesforce CLI Reference

### Core Command Summary

| Command | Purpose |
|---|---|
| `sf agent generate authoring-bundle` | Create new agent bundle (always use `--no-spec`) |
| `sf agent validate authoring-bundle` | Check syntax before deployment |
| `sf project deploy start` | Push backing logic and AiAuthoringBundle |
| `sf agent publish authoring-bundle` | Convert bundle into runtime agent |
| `sf agent activate` | Make published agent available |
| `sf agent deactivate` | Deactivate a published agent |
| `sf agent test create` | Create test spec in org |
| `sf agent test run --wait 5` | Run tests and wait for results |
| `sf agent test results` | Retrieve test results |
| `sf agent preview start` | Interactive test without publishing |
| `sf org open authoring-bundle` | Open all bundles in Agentforce Studio |
| `sf org open agent --api-name <Bot>` | Open specific published agent |

### Critical CLI Rules

- Always place `--json` immediately after the base command (`sf agent generate --json ...`)
- Use **space-separated** (not comma-separated) metadata arguments: `--metadata "TypeA:Name TypeB:Name"`
- Quote wildcard patterns: `--metadata "AiAuthoringBundle:*"`
- Agent metadata types are **NOT queryable via SOQL** — use CLI retrieve commands instead
- `sf bot` commands were removed in sf CLI v2 — use `sf agent` exclusively
- Deployment with `--source-dir` may hang if `AiEvaluationDefinition` files are present — use `--metadata AiAuthoringBundle:MyAgent` instead

### CI/CD Pipeline (8 Steps)

```bash
# 1. Retrieve current state
sf project retrieve start --json --metadata "AiAuthoringBundle:My_Agent"

# 2. Edit .agent source file

# 3. Deploy backing logic (flows/apex) and authoring bundle together
sf project deploy start --json --metadata "AiAuthoringBundle:My_Agent Flow:My_Flow ApexClass:MyClass"

# 4. Validate
sf agent validate authoring-bundle --json --api-name My_Agent

# 5. Publish
sf agent publish authoring-bundle --json --api-name My_Agent

# 6. Activate
sf agent activate --json --api-name My_Agent_Bot

# 7. Run tests
sf agent test run --json --api-name My_Agent_Bot --wait 5

# 8. Verify
sf agent test results --json --api-name My_Agent_Bot
```

---

## 15. Agent Access & Permissions

### Making a Published Agent Visible to Users

Agents require a `PermissionSet` with `<agentAccesses>` to appear in the Lightning Copilot panel.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
    <agentAccesses>
        <agentName>My_Agent</agentName>  <!-- must exactly match developer_name -->
        <enabled>true</enabled>
    </agentAccesses>
    <hasActivationRequired>false</hasActivationRequired>
    <label>My Agent Access</label>
</PermissionSet>
```

```bash
# Deploy the permission set
sf project deploy start --json --metadata "PermissionSet:My_Agent_Access"

# Assign to a user
sf org assign permset --json --name My_Agent_Access --on-behalf-of user@example.com
```

### Visibility Troubleshooting

| Symptom | Cause | Solution |
|---|---|---|
| No Agentforce icon in UI | `CopilotSalesforceUser` PS not assigned | Assign `CopilotSalesforceUser` permission set |
| Icon visible, agent not in list | Missing `<agentAccesses>` | Add `<agentAccesses>` to permission set |
| Agent visible, errors on open | Agent not fully published/active | Verify `BotVersion` Status = Active |
| "Agent not found" error | Developer name mismatch | Ensure `<agentName>` exactly matches `developer_name` in config |

### Apex Class Permissions

Einstein Agent User must have access to **every** Apex class referenced by **any** action across **all** topics. Missing even one class causes the whole agent to fail.

- System permission set: `AgentforceServiceAgentUser`
- Custom permission set: `{AgentName}_Access` — must explicitly list all `<classAccesses>` for every Apex class used

> **Warning:** The auto-generated `NextGen_{AgentName}_Permissions` permission set is frequently incomplete. Always build the custom PS manually.

---

## 16. Agent User Setup

### Service vs. Employee Agents

| Type | User Model | Permissions |
|---|---|---|
| `AgentforceServiceAgent` | Dedicated Einstein Agent User account | Consistent, uniform across all sessions |
| `AgentforceEmployeeAgent` | Runs as the logged-in user | Respects individual sharing rules |

### Service Agent 6-Step Setup

```bash
# Step 1: Create Einstein Agent User (scratch org)
sf org create user --json --definition-file config/agent-user.json

# Step 1 (production/sandbox): Use sf data create record
sf data create record --json --sobject User --values "Username=agent@myorg.ext ProfileId=<EinsteinAgentProfile> ..."

# Step 2: Assign system permission set (BEFORE publishing)
sf org assign permset --json --name AgentforceServiceAgentUser --on-behalf-of agent@myorg.ext

# Step 3: Create custom permission set listing ALL Apex classes
# (create {AgentName}_Access.permissionset-meta.xml manually)

# Step 4: Assign custom permission set
sf org assign permset --json --name MyAgent_Access --on-behalf-of agent@myorg.ext

# Step 5: Set in agent config
#   default_agent_user: "agent@myorg.ext"

# Step 6: Deploy → validate → publish → activate
```

> **Critical:** `default_agent_user` must reference a user with an Einstein Agent license. An incorrect license produces a misleading "Internal Error, try again later" — not a permissions error.

---

## 17. Topic-Level System Overrides

Topics can define their own `system:` block to **completely replace** the global system instructions for that topic. This enables persona switching and specialist modes.

### Hierarchy

| Level | Location | Scope | Dynamic? |
|---|---|---|---|
| Global `system:` block | Top-level file | All topics (baseline) | No — static text only |
| Topic `system:` block | Inside `topic <name>:` | Overrides global for that topic | No — static text only |
| Topic `reasoning.instructions:` | Inside `reasoning:` | Extends/adjusts within topic | Yes — variables and conditionals |

### Topic-Level System Override Syntax

```yaml
topic formal_mode:
    label: "Formal Communication"
    description: "Professional business communication mode"

    # Completely replaces global system: for this topic only
    system:
        instructions: "You are a formal business professional. Use professional language at all times. Address users as Sir or Madam. Avoid contractions and slang. Maintain a respectful, corporate tone."

    reasoning:
        instructions: ->
            | Good day. How may I be of assistance?
        actions:
            back: @utils.transition to @topic.topic_selector
```

### Dynamic Per-User Behavior via Reasoning Instructions

Use variables to branch behavior within a topic's `reasoning.instructions:` — this is the correct pattern for dynamic adjustments (topic `system:` only accepts static text):

```yaml
topic support:
    reasoning:
        instructions: ->
            if @variables.customer_tier == "vip":
                | PRIORITY CUSTOMER — provide white-glove service.
                | You have authority to offer 20% discounts.

            if @variables.customer_tier == "premium":
                | PREMIUM CUSTOMER — provide thorough, detailed responses.
                | You can offer 10% discounts.

            if @variables.business_hours == False:
                | NOTE: Outside business hours. Do not transfer to live agents.

            | Help the customer with their request.
```

**Best practice:** Global `system:` for universal guardrails → topic `system:` for complete persona changes → topic `reasoning.instructions:` for context-aware personalization.

---

## 18. N-ary Conditions & Complex Logic

### Flat Compound Conditions

Agent Script does **not** support nested `if` statements. Use compound `and`/`or` on a single `if` line instead.

```yaml
# ❌ INVALID — nested if
before_reasoning:
    if @variables.a == True:
        if @variables.b == True:
            transition to @topic.x

# ✅ CORRECT — flat N-ary condition
before_reasoning:
    if @variables.a == True and @variables.b == True:
        transition to @topic.x
```

### Grouping with Parentheses

Use parentheses to express mixed `and`/`or` logic:

```yaml
before_reasoning:
    # Premium with any product, OR standard with active warranty
    if (@variables.tier == "premium" and @variables.product_type != None) or (@variables.tier == "standard" and @variables.has_warranty == True):
        transition to @topic.priority_support
```

### N-ary `available when`

```yaml
reasoning:
    actions:
        process_return: @actions.handle_return
            available when @variables.order_exists == True and @variables.within_return_window == True and @variables.item_eligible == True

        use_priority: @actions.priority_service
            available when @variables.tier == "gold" or @variables.tier == "platinum" or @variables.tier == "enterprise"

        expedite: @actions.expedite_order
            available when @variables.product_type == "perishable" and (@variables.status == "pending" or @variables.status == "processing")
```

### Type Notes

- Use `number` — **not** `integer`. The `integer` type is **not supported** in AiAuthoringBundle and will cause errors.
- Boolean literals must be capitalized: `True` / `False` — lowercase `true`/`false` will fail.

---

## 19. Escalation & Connection Block

### Connection Block Syntax

The `connection messaging:` block is required for `@utils.escalate` to work. It defines the Omni-Channel routing destination.

```yaml
# Single channel (singular 'connection')
connection messaging:
    outbound_route_type: "OmniChannelFlow"    # ONLY "OmniChannelFlow" is supported
    outbound_route_name: "My_Omni_Channel_Flow"  # API name of the Omni-Channel Flow
    escalation_message: "Transferring you to a human agent now..."   # required when block is present
    adaptive_response_allowed: True

# Multiple channels (plural 'connections')
connections:
    messaging:
        outbound_route_type: "OmniChannelFlow"
        outbound_route_name: "Chat_Support_Flow"
        escalation_message: "Connecting you to chat support..."
        adaptive_response_allowed: True
    telephony:
        outbound_route_type: "OmniChannelFlow"
        outbound_route_name: "Phone_Support_Flow"
        escalation_message: "Transferring to phone support..."
        adaptive_response_allowed: False
```

> **Warning:** Only `"OmniChannelFlow"` is supported for `outbound_route_type`. Values like `"queue"`, `"skill"`, or `"agent"` cause validation errors.

> **Warning:** `@utils.escalate with reason="..."` syntax is **only** valid in GenAiPlannerBundle. Using it in AiAuthoringBundle causes a SyntaxError.

### CustomerWebClient Surface Post-Publish Patch

Every publish via `sf agent publish` overwrites the GenAiPlannerBundle and drops the `CustomerWebClient` surface. A 6-step manual patch is required after each publish if that surface is needed:

```xml
<!-- Patch XML to add to GenAiPlannerBundle after each publish -->
<plannerSurfaces>
    <adaptiveResponseAllowed>false</adaptiveResponseAllowed>
    <callRecordingAllowed>false</callRecordingAllowed>
    <outboundRouteConfigs>
        <escalationMessage>One moment while I connect you with a support specialist.</escalationMessage>
        <outboundRouteName>Route_from_Your_Agent</outboundRouteName>
        <outboundRouteType>OmniChannelFlow</outboundRouteType>
    </outboundRouteConfigs>
    <surface>SurfaceAction__CustomerWebClient</surface>
    <surfaceType>CustomerWebClient</surfaceType>
</plannerSurfaces>
```

### Prompt Template Action Target

```yaml
actions:
    generate_summary:
        description: "Generate a customer-facing summary."
        inputs:
            "Input:customerName": string       # quoted, with "Input:" prefix
                description: "Customer name"
                is_required: True
            "Input:caseDetails": string
                description: "Case details to summarize"
                is_required: True
        outputs:
            promptResponse: string             # always "promptResponse"
                description: "The generated content."
                is_used_by_planner: True
                is_displayable: True
        target: "generatePromptResponse://My_Prompt_Template"  # quotes required

# Reasoning invocation
reasoning:
    actions:
        run_summary: @actions.generate_summary
            with "Input:customerName" = @variables.customer_name
            with "Input:caseDetails" = @variables.case_details
            set @variables.summary = @outputs.promptResponse
```

**Input mapping:** Agent Script `"Input:fieldName"` → Prompt Template `{!fieldName}`

**Known limitation:** Chained actions using the `run` keyword may fail to map Prompt Template input parameters. Use Prompt Template actions as primary (LLM-invoked) actions, not via `run`.

---

## 20. Validation, Debugging & Production Gotchas

### Credit Costs

| Operation | Cost |
|---|---|
| `transition to @topic.X`, `set @variables.*`, `@utils.escalate` | Free (0 credits) |
| `before_reasoning` / `after_reasoning` execution | Free (0 credits) |
| Action call (Flow, Apex, API) | ~20 credits per call |
| Prompt Template action | ~2–16 credits per call |

**Optimization pattern:** Fetch data once in `before_reasoning:`, cache in variables, reuse across the topic rather than calling the same action multiple times.

### Validation Commands

```bash
# Validate before publish (catches syntax errors, missing references)
sf agent validate authoring-bundle --json --api-name My_Agent

# Retrieve after publish to inspect version lock
sf project retrieve start --json --metadata "AiAuthoringBundle:My_Agent"

# List agent metadata (not SOQL-queryable — must use CLI)
sf project retrieve start --json --metadata "Bot:My_Agent_Bot"
```

### 8-Step Debugging Workflow

1. **Reproduce** with minimal input — isolate the turn/topic where failure occurs
2. **Check `default_agent_user`** — wrong license → "Internal Error" (misleading)
3. **Verify backing logic deployed** — Flow/Apex must exist before publish
4. **Inspect `bundle-meta.xml`** — stale `<target>` lock may prevent edits
5. **Check Apex permissions** — agent user must have access to ALL Apex classes across ALL topics
6. **Look for same-turn race conditions** — check if `after_reasoning` depends on an action the LLM may not have called; fix with `run @actions.X`
7. **Check action output sizes** — large responses can corrupt session state; use `filter_from_agent: True`
8. **Deactivate → republish** — when all else fails, deactivate the Bot, republish, and reactivate

### Variable Management in Deployment

**Variable Mapping Errors:** Deployment fails with "Variable 'X' not found" even though it's defined in source org. Cause: variables must exist in the target org BEFORE deploying the agent.

Pre-Deployment Checklist:
1. Document all variables (Name, Type, Default Value, which topics use them).
2. In the target org, create variables FIRST: Setup > Agent > Variables.
3. Then deploy the agent.
4. Verify mappings in UI after deployment.

**Auto-Generated Duplicate Variable Names:** If the UI auto-generates `userId_1`, `userId_2` duplicates — delete all versions, manually create ONE variable, reference it consistently.

**Safe Variable Rename Process** (renaming in place causes metadata corruption — mappings are stored by ID, not name):
1. Create a NEW variable with the desired name.
2. Update ONE topic at a time to use the new variable.
3. Test thoroughly after each topic update.
4. After ALL topics are updated, delete the old variable.
If already broken: clone the agent, rebuild variable mappings manually — no automated fix available.

**Testing Variables During Development:** Can't test Topic Selector without runtime variables populated from previous topics. Create a `Dev_PopulateTestVars` Flow (trigger: Agent Session Start) that sets test variable values. Add `[TEST]` prefix to all responses when `$testMode = true`. Remove this flow before production deployment. Alternative: use Conversation Variables set in Test Conversation UI before running tests.

### Character and Token Limits

**65,000 Character Hard Limit:** Agent output is capped at 65,000 characters per response. An agent summarizing 100+ knowledge articles will hit this limit mid-generation, causing truncated outputs.

Pre-Processing Model workaround:
1. Create a custom field: `Summary__c` (Rich Text, 32K characters).
2. Use a Scheduled Apex job to pre-generate summaries offline.
3. Agent retrieves the pre-generated summary at runtime.
4. Response stays well under the limit.

**10,000 Tokens = 1 Action Credit:** An agent processing 200 case records in a single query may consume multiple action credits due to token usage, quickly exhausting the action budget.

Smart Batching Pattern:
- Initial query: `LIMIT 20` records.
- Display summary with "Load More" option.
- Subsequent queries: `WHERE Id IN :nextBatch`.
- Lazy loading based on user interaction.

Example SOQL:
```sql
SELECT Id, Subject, Status, Priority
FROM Case
WHERE OwnerId = :userId
ORDER BY Priority DESC, CreatedDate DESC
LIMIT 20
```

**Timeout on Large Datasets:** Agents timeout when trying to process 10,000+ records at runtime (e.g., quarterly sales summary from all opportunities).

MapReduce Approach:
1. Flow runs weekly to create `Summary__c` records per region.
2. Agent queries: `SELECT Region__c, Summary__c FROM QuarterlySummary__c`.
3. Combines 12 pre-built summaries instead of processing 10K raw records.
4. Response time: <2 seconds vs. timing out.

### Reserved Apex Variable Names

Avoid using these names in `@InvocableVariable` declarations — they cause Apex compilation errors:
- `model`
- `description`
- `label`

### Response Size Limit

Agent output is capped at **1 MB** per turn. Return minimal, summarized data from actions.

---

## 21. Known Platform Issues & Workarounds

| # | Issue | Status | Workaround |
|---|---|---|---|
| 1 | `AiEvaluationDefinition` files under `force-app/` cause deployment hang (2+ min) | WORKAROUND | Use `--metadata AiAuthoringBundle:MyAgent` instead of `--source-dir` |
| 2 | `sf agent publish` fails with namespace prefix on `apex://` targets | OPEN | Try `apex://ns__ClassName`, or wrap Apex in a Flow |
| 3 | `require_user_confirmation` does not trigger confirmation dialog | OPEN | Implement manually: two-step pattern with `available when @variables.user_confirmed == True` |
| 4 | Action definitions without an `outputs:` block cause "Internal Error" on publish | WORKAROUND | Always include an `outputs:` block, even if empty |
| 5 | Large action responses cause session state corruption | OPEN | Return minimal data; add `filter_from_agent: True` to large outputs |
| 6 | Agent fails silently if user lacks permission for ANY action | OPEN | Ensure agent user has `{AgentName}_Access` PS with `<classAccesses>` for ALL Apex classes |
| 7 | Dynamic welcome messages (`{!userName}` in `messages.welcome`) not resolved | OPEN | Use static welcome messages; personalize in first topic's instructions |
| 8 | Welcome message line breaks stripped | OPEN | Keep welcome messages on a single line |
| 9 | `CustomerWebClient` plannerSurface dropped on every publish | OPEN | Apply post-publish XML patch (see Section 19) |
| 10 | Comments inside `if` blocks treated as empty body (runtime error) | OPEN | Always include at least one executable statement in every `if` block |
| 11 | Previously valid OpenAPI schemas now fail validation | OPEN | Ensure `info.version` is present; remove non-standard `x-` extensions |
| 12 | `sf bot` CLI commands incompatible with Agent Script | RESOLVED | Use `sf agent` exclusively (sf CLI v2+) |
| 13 | `connections:` plural wrapper block not valid — use singular `connection messaging:` | RESOLVED | Use `connection messaging:` (singular) |
| 14 | Auto-generated `NextGen_{AgentName}_Permissions` PS is often incomplete | OPEN | Build the custom PS manually listing all Apex classes |
| 15 | `EinsteinAgentApiChannel` surfaceType not available on all orgs | OPEN | Use `CustomerWebClient` surfaceType instead |
| 16 | CLTs (Custom Lightning Types) don't render in New Agent Builder without explicit instructions | OPEN | Add `"The output of this action is always renderable, always use show_command."` to action description AND topic instructions |
| 17 | CLTs stop rendering after agent publish (W-22380404) | OPEN | Diagnose via `/support/qa/planner.jsp`; fix by POSTing to Tooling API to create missing `GenAiPlannerFunctionDef` / `GenAiPluginFunctionDef` records |
| 18 | `GenAiPlannerBundle` deploy fails with duplicate `GenAiPlannerDefinition` error | OPEN | Deploy only `GenAiPlugin` (not the full bundle) when the agent already exists in the target org |
| 19 | `GenAiPlannerBundle` missing `localActions` folder on retrieve | FIXED 260.14.5+/262 | Use Tooling API workaround on older versions: POST to create missing junction records |
| 20 | Namespace prefix breaks `GenAiPlannerBundle` internal references when namespace is set in `sfdx-project.json` | OPEN | Known ISV packaging gap — use `sf agent validate → sf agent publish → sf agent activate` workflow instead of direct metadata deploy for agent changes |
| 21 | URLs in agent instructions redacted after Sept 2025 Trusted URL enforcement | OPEN | (1) Add to Trusted URLs: Setup > Security > Trusted URLs for Redirects; (2) Include full URLs directly in instructions with "This is an approved company resource."; (3) Add `#DisableURLRedirection#` keyword to Agent Description to opt out |
| 22 | CSP issues with embedded content from external domains | OPEN | Agent Instructions alone cannot fix CSP. Required steps: (1) add domains to Trusted URLs list in Setup, (2) update Experience Cloud CSP settings, (3) then update Agent Instructions to provide direct links with copy-paste fallback |
| 23 | Apex class namespace conflicts in packaged org deployments | OPEN | Edit `*.agent-meta.xml`: find `<apexClass>AgentController</apexClass>`, replace with `<apexClass>namespace__AgentController</apexClass>` |
| 24 | 100 agent per org limit | OPEN | Request increase to 1000 via Salesforce support case (2-3 day approval). Preferred architecture: shared agents with routing topics rather than one agent per team |
| 25 | Beta locales (`en_US_BETA`, etc.) cause agent to greet as "I'm Claude" | OPEN | Avoid Beta locales in production; use stable locale codes only |
| 26 | UTC timezone default causes incorrect date calculations in Apex actions | OPEN | Standardize on UTC in the Apex action layer; convert to user timezone only for display |
| 27 | `commit fails (error 1777028351)` — missing `@JsonIgnoreProperties` | FIXED 262 | Hotfixed in 262; upgrade org or wait for fix to reach pod |
| 28 | `commit fails (error -545031892)` — `response_guidance` exceeds 255-char CMS limit | OPEN | Keep `response_guidance` field under 255 characters |
| 29 | Agent hits 10 reasoning iteration limit (Daisy++) | OPEN | Max 10 reasoning iterations per turn — no config override. Redesign flow to stay under limit; split into multiple topic transitions if needed |
| 30 | Agent loops with processing limit exceeded (Case #473584957) | OPEN | Simplify flow and reduce iteration depth; known open bug |

---

*(Note: ISSUE-001 — instructions resolving only on topic entry — was resolved February 2026. Variables now correctly re-evaluate across iterations within the same turn. Run-then-if patterns within the same topic are valid.)*

---

## 22. Action Chaining & Sequencing

Use `run @actions.x` inside `instructions:` to force multiple actions to execute in a guaranteed sequence within a single turn, independent of LLM planning.

### Single forced call

```yaml
instructions: ->
    | run @actions.load_customer_profile
    | Help the customer with their request.
```

### Sequential chain — fixed order

```yaml
instructions: ->
    | run @actions.verify_eligibility
    | set @variables.eligible = @outputs.eligible
    | if @variables.eligible == False:
    |     transition to @topic.ineligible
    | run @actions.create_case
    | set @variables.caseId = @outputs.caseId
    | The case {!@variables.caseId} has been created.
```

Each `run` fires in order. Later runs can reference outputs from earlier ones via `@outputs.<name>` or a `set` assignment.

### LLM-driven chain via reasoning actions

When the LLM should decide which actions to call (but must call them all), list them all in `reasoning.actions:` and use commanding language:

```yaml
reasoning:
    instructions: ->
        | ALWAYS call search_orders first, then call get_order_details.
        | Do not respond until both actions have been called.
    actions:
        search_orders:     @actions.search_orders
            with customerId = @variables.ContactId
        get_order_details: @actions.get_order_details
            with orderId = ...
```

### Pre-fetch then reason

The most credit-efficient pattern: load data in `before_reasoning` (0 credits), then let the LLM reason over it.

```yaml
reasoning:
    before_reasoning:
        run @actions.load_account_summary
    instructions: ->
        | Using the account summary already loaded, help the customer.
        | Do not call load_account_summary again.
    actions:
        update_contact: @actions.update_contact
            with ...
```

**Rules:**
- `run @actions.x` inside `before/after_reasoning` executes deterministically (0 credits).
- `run @actions.x` inside `instructions:` is still LLM-context but treated as a directive — the LLM is told it must call it.
- Chaining more than ~4 `run` calls in a single topic turn increases latency. Consider splitting into phase topics if sequencing is long.

---

## 23. Variables: Lists & Index Iteration

### Declaring list variables

```yaml
variables:
    results:       mutable list[object] = []
        description: "Search results returned by an action."
    selected_ids:  mutable list[string] = []
        description: "IDs chosen by the user."
    scores:        mutable list[number] = []
        description: "Numeric scores for each result."
```

Supported list element types: `string`, `number`, `boolean`, `object`.

### Reading list length

```yaml
instructions: ->
    | if list.length(@variables.results) == 0:
    |     transition to @topic.no_results
    | There are {!list.length(@variables.results)} results available.
```

### Index-based access

Access individual elements using bracket notation:

```yaml
instructions: ->
    | set @variables.first_id = @variables.selected_ids[0]
    | set @variables.second_id = @variables.selected_ids[1]
```

Indexes are zero-based. Accessing an out-of-bounds index returns `None`.

### Iteration pattern via index variable

Agent Script has no native `for` loop. Simulate iteration with a `mutable number` index counter and topic-to-self transitions:

```yaml
variables:
    results:       mutable list[object] = []
        description: "List of items to process."
    current_index: mutable number = 0
        description: "Current position in the results list."

topic process_results:
    label: "Process Results"
    description: "Iterates through results one at a time."
    reasoning:
        before_reasoning:
            if @variables.current_index >= list.length(@variables.results):
                transition to @topic.done
        instructions: ->
            | Process item {!@variables.current_index}: {!@variables.results[@variables.current_index]}.
            | run @actions.handle_item
            | set @variables.current_index = @variables.current_index + 1
        after_reasoning:
            if @variables.current_index < list.length(@variables.results):
                transition to @topic.process_results
    actions:
        handle_item:
            description: "Processes a single result item."
            target: "flow://Handle_Item"
            inputs:
                "item": object
                    is_required: True
                    is_user_input: False
```

**Warning:** The runtime caps same-topic transitions at ~3–4 per turn to prevent infinite loops. For longer lists, return batch-processed results from an action rather than looping in script.

### Appending to a list

```yaml
instructions: ->
    | set @variables.selected_ids = list.add(@variables.selected_ids, @outputs.newId)
```

`list.add` returns a new list — it does not mutate in place.

### Checking list membership

```yaml
instructions: ->
    | if list.contains(@variables.selected_ids, @variables.target_id):
    |     transition to @topic.already_selected
```

---

## 24. Context Engineering

Context engineering controls what the Atlas Reasoning Engine sees at inference time — the system prompt, conversation history, action outputs, and retrieved knowledge. Poor context hygiene causes hallucination, state corruption, and cost overruns.

### The four context layers

| Layer | Controlled by | How to tune |
|---|---|---|
| **System context** | `system:` + topic `system:` blocks | Keep persona concise; move policy to RAG |
| **Reasoning instructions** | `topic.reasoning.instructions:` | Scope tightly to the topic's job; ~25–40 lines max |
| **Action output context** | `is_displayable`, `is_used_by_planner`, `filter_from_agent` | Expose only what the LLM needs to reason or display |
| **Retrieved knowledge** | `retriever://` action outputs | Gate with `available when`; use `filter_from_agent: True` on large payloads |

### Strategy 1 — Minimize system prompt surface area

Put universal guardrails in `system.instructions`. Put everything else in topic instructions or RAG.

```yaml
system:
    instructions: "You are a helpful service agent for Acme Corp. Never discuss competitor products. Respond in the user's language."
```

Avoid embedding long policy documents or enumerated product lists in `system:` — they bloat every turn's context. Use a `retriever://` action instead.

### Strategy 2 — Output flag discipline

Every action output should declare exactly the context access it needs:

```yaml
outputs:
    "customerId": string
        is_displayable: False       # internal ID — never show to user
        is_used_by_planner: True    # but LLM needs it to call the next action
    "policyText": string
        is_displayable: True        # LLM may quote this to the user
        is_used_by_planner: True
        filter_from_agent: True     # but strip it from session state after display (large payload)
    "debugTrace": string
        is_displayable: False
        is_used_by_planner: False   # LLM is completely blind to this
```

**Default posture:** `is_displayable: False`, `is_used_by_planner: True`. Grant display and visibility deliberately.

### Strategy 3 — Pre-fetch, don't mid-fetch

Fetch lookup data in `before_reasoning` so it enters the LLM context as a given, not as a mid-reasoning tool call:

```yaml
reasoning:
    before_reasoning:
        run @actions.load_customer_tier
    instructions: ->
        | The customer's tier is already loaded.
        | Use it to calibrate your response.
```

This reduces the number of reasoning cycles needed per turn and prevents the LLM from re-fetching data it already has.

### Strategy 4 — Topic decomposition as context scoping

Each topic gets its own reasoning context. A topic with 200 lines of instructions crowds out space for the conversation and action outputs. Decompose:

```
[collect_info]  25 lines → [confirm_details]  20 lines → [submit]  15 lines
```

Each phase topic is small, focused, and transitions deterministically. The LLM only sees the current phase's instructions, not the entire workflow.

### Strategy 5 — RAG for policy and knowledge

Replace hard-coded rules with retrieval:

```yaml
# Instead of this (static, grows without bound):
instructions: ->
    | POLICY: Returns are allowed within 30 days. Exceptions: perishables (7 days),
    | electronics (15 days), software (no returns)...

# Do this:
reasoning:
    instructions: ->
        | run @actions.get_return_policy
        | Apply the retrieved policy to the customer's request.
    actions:
        get_return_policy: @actions.get_return_policy
            available when @variables.product_category is not None
actions:
    get_return_policy:
        description: "Retrieves the applicable return policy for the product category."
        target: "retriever://Return_Policy_KB"
        inputs:
            "category": string
                is_required: True
                is_user_input: False
        outputs:
            "policy": string
                is_displayable: False
                is_used_by_planner: True
                filter_from_agent: True
```

### Strategy 6 — Persona isolation via topic system overrides

When a topic needs a radically different persona (e.g. a legal disclaimer mode, a formal escalation topic), use a topic-level `system:` override rather than conditional logic inside `instructions:`. This gives the LLM a clean context for that topic with no residual signals from the global persona.

```yaml
topic legal_disclaimer:
    system:
        instructions: "You are presenting a legal disclaimer. Read it verbatim. Do not paraphrase, add context, or answer questions about its content."
    reasoning:
        instructions: ->
            | run @actions.get_disclaimer_text
            | Present the retrieved disclaimer text verbatim.
```

### Context engineering anti-patterns

| Anti-pattern | Problem | Fix |
|---|---|---|
| Long `system:` with enumerated rules | Bloats every turn; rules drift out of sync with reality | Move to RAG retriever |
| `is_used_by_planner: True` on all outputs | LLM reasons over irrelevant data; increases hallucination risk | Set `False` for outputs the LLM doesn't need |
| `filter_from_agent: False` on large payloads | Oversized outputs corrupt session state (1 MB cap) | Add `filter_from_agent: True` to large action outputs |
| Monolithic topics (100+ lines) | LLM context crowded; poor instruction adherence | Decompose into phase topics of ~25–40 lines |
| Re-fetching data the LLM already has | Wastes credits; increases turn latency | Pre-fetch in `before_reasoning`; reference via variables |
| One global RAG retriever for all topics | Low retrieval accuracy (often 40%) — retriever must rank across unrelated domains | Use separate topic-scoped retrievers with narrowed data sources and prompt templates |

### Strategy 7 — Topic-Scoped RAG Retrievers

Using one global retriever for all topics produces low accuracy (observed 40% in production). Configure separate retrievers per topic with narrowed scope:

```yaml
# Topic: Product Questions
# Knowledge Setup:
#   Data Source: Product_KB__kav
#   Categories: Products, Features, Specifications
#   Prompt Template: "Answer only about product features and specs"

# Topic: Billing Questions
# Knowledge Setup:
#   Data Source: Billing_KB__kav
#   Categories: Invoices, Payments, Refunds
#   Prompt Template: "Focus on billing and payment topics"
```

Result: Accuracy improved from 40% to 75%+ by narrowing retrieval scope (Navigator Agent production case).

### Strategy 8 — Knowledge Article Quality Checklist

Poor RAG accuracy is often caused by poor article quality, not retriever configuration. Before tuning retriever parameters, verify article quality:

1. Remove duplicate articles (consolidate versions).
2. Target length: 500–2000 words per article.
3. Add structured headings (H2, H3) for better semantic chunking.
4. Include a `Summary__c` field (150–200 words) — retrievers use this for ranking.
5. Add rich metadata fields: `Category__c`, `SubCategory__c`, `Keywords__c`, `Language__c`, `LastReviewDate__c`.

Recommended article structure:
```
# [Title]
## Summary
[150-word overview — used by retriever for ranking]

## Details
[Main content with clear sections]

## Related Topics
[Links to 3-5 related articles]
```

### Strategy 9 — Language-Aware Retrieval

For multilingual agents, filter knowledge retrieval by the user's language to prevent citing English articles to non-English speakers:

```yaml
# SOQL filter in knowledge action:
# WHERE Language__c = :userLanguage AND Status = 'Published'
# 
# In instructions:
# "Detect the user's language from the conversation.
#  Filter knowledge retrieval to match the detected language.
#  If no match found, state: 'I don't have information in [language]. Would you like English results?'"
```

### Strategy 10 — Context Injection Pattern (Agent Hydration)

For agents that pull incorrect information from previous conversation history, apply the Agent Hydration Pattern:

1. Detailed role description in Agent Instructions (anchors the agent's identity).
2. Glossary retrieval via flows at conversation start (loads domain context).
3. Conversation history injection for continuity (explicit, not implicit).
4. Explicit directives to ignore conversation context variables when needed: `"Focus only on the current request. Do not reference earlier conversation turns unless the user explicitly asks you to."`

---

## 25. Daisy++ (Unified Planner) Migration

Daisy++ (Unified Planner) became GA on April 10, 2026. All new NGA agents use it by default. All existing NGA agents were upgraded by April 24, 2026. Legacy Builder agents are NOT affected.

### Key Behavioral Changes Post-Daisy++

**1. Conditional logic in `reasoning.instructions` is silently IGNORED.**
Conditions like `if @variables.X == ''` inside the `instructions:` block are silently ignored. Fix: move all conditional transitions to `before_reasoning`.

**2. Action chaining failure on error.**
In old Daisy, if an action failed, remaining chained actions stopped. In Daisy++, remaining actions in the sequence continue regardless. Be explicit about error handling — check action output status before proceeding.

**3. `after_reasoning` was a Daisy bug, not a feature.**
`after_reasoning` was accidentally functional in old Daisy due to a bug. That bug is fixed in Daisy++. Remove `after_reasoning` hooks and implement correct patterns using `before_reasoning` or topic transitions.

**4. Multiple Prompt Template outputs: only the final output shown.**
If multiple Prompt Template actions are chained, only the final reasoning output is shown; intermediate outputs are redacted. Restructure to surface intermediate outputs explicitly via `set @variables.X = @outputs.promptResponse` before the next action.

**5. Max 10 reasoning iterations per turn.**
Complex flows that require many back-and-forth reasoning cycles will hit this cap. No configuration override exists today. Design agents to stay under the limit — split complex flows into multiple topic transitions.

### HyperClassifier vs GPT-4.1 for Routing

| Model | Use For | Speed | Limitations |
|---|---|---|---|
| `EinsteinHyperClassifier` (`sfdc_ai__DefaultEinsteinHyperClassifier`) | Topic/sub-agent classification (routing) only | ~95ms | No `before/after_reasoning` hooks; only `@utils.transition` available; classification-only — no rich reasoning or response generation |
| GPT-4.1 (default) | General reasoning, tool selection, response generation | ~2.6s | None — full feature support |
| `claude-sonnet-4` / `claude-haiku-4-5` | Strong reasoning, good balance | Medium | Confirm tool-calling support before use |
| `gemini-flash` | High-volume, fast responses | Fast | Confirm tool-calling support before use |

**Pattern:** Use HyperClassifier for the `agent_router` node only; use GPT-4.1 (or Sonnet 4 / Gemini Flash) for all other subagents.

### Workaround to Revert to Legacy Daisy Planner (Temporary)

```yaml
config:
  additional_parameter__disable_graph_runtime: True
```

**Note:** After adding this flag, remove and re-add Knowledge actions to the subagent to restore knowledge retrieval.

### CLT (Custom Lightning Type) Rendering

CLT rendering is LLM-driven and non-deterministic. Without explicit instructions, the planner may not use `show_command`.

**Fix — Explicit Rendering Instructions:**

At the action level (description):
```
"Returns a UI component. The output of this action is always renderable, always use show_command."
```

At the topic level (instructions):
```
"Run @actions.My_CLT_Action. The output of this action is always renderable. Always use show_command to display the result to the user."
```

**Additional CLT constraints:**
- **ASA Draft Preview** CANNOT render CLTs (Messaging license restriction). Use AEA Preview instead, or activate and test via Enhanced Chat v2 deployment settings.
- **ECv2 Connection Required:** Agent Script must configure Enhanced Chat v2 connection for Lightning Types to render client-side. Without ECv2, `formatType` degrades to text. Disable Adaptive Response Formats (incompatible with ECv2) via Agent Builder → Connections menu.
- **Voice + Rich Web Chat:** `Atlas__VoiceAgent` planner breaks CLT rendering. For dual-channel (voice + web chat), use separate agents sharing the same GenAiPlugin/GenAiFunctions with different planner types, OR use a single Agent Script agent (the script-agent runtime handles planner-type differences internally).
- **Cross-subagent CLT limitation:** The CLT-rendering action must be declared in the **same subagent** that renders it. Cross-subagent `@subagent.X` or `@actions.X` references for rendering do not work.

---

## 26. Performance & Observability

### Speed Optimization Techniques

**1. Reduce Action Count:**
Combine SOQL queries where possible. Use fewer but richer actions — each action call costs ~20 credits and adds latency.

**2. Streaming Responses:**
Add to topic instructions: `"Begin your response immediately with available information. Add details as you gather them."` This creates a streaming-like experience.

Example output pattern: `"I found your account... [loading recent cases]... here are your 3 open cases with details."`

**3. Set User Expectations:**
`"I'm analyzing your request across multiple systems. This will take about 10 seconds..."` — users tolerate wait time far better when progress is visible and the task completes successfully.

**4. Model Selection for Performance:**
Configure per topic in Topic Settings based on workload:
- `llmgateway__GPT41` (default): general reasoning, ~2.6s
- `claude-sonnet-4` / `claude-haiku-4-5`: strong reasoning, good balance
- `gemini-flash`: fast, good for high-volume
- `EinsteinHyperClassifier`: routing only, fastest (~95ms)

**Note:** GPT-3.5-turbo and other untested models fail silently at runtime — do not use.

### Agent Analytics

Enable to gain visibility into where agent performance is lagging.

Setup: `Setup > Agent Analytics > Enable`

**Key Metrics Dashboard:**
- **Deflection Rate:** % resolved without human escalation
- **Escalation Rate:** % transferred to human
- **Average Actions per Session:** high values indicate over-reliance on data fetches
- **Topic Coverage:** % queries correctly matched to topics
- **Action Success Rate:** low values indicate backing logic failures
- **Session Duration:** long sessions indicate friction or unclear instructions

**Debugging Resources:**
- Session Tracing (STDM): `Setup > Session Tracing` — filter by Agent Sessions to inspect reasoning path
- Agent Analytics: `Setup > Agent Analytics`
- Debug Logs: `Setup > Debug Logs > Enable for Agent User`

**Weekly Review Pattern:**
1. Identify topics with >30% escalation rate.
2. Investigate actions with <80% success rate.
3. Optimize slowest topics first (sort by Session Duration descending).

Example finding: "Password Reset" topic with 60% escalation. Root cause: action required manager approval for standard users. Fix: add self-service flow for standard users. Result: 15% escalation rate.

### Key Architectural Principles

These five principles, derived from 10 months of production deployments, distinguish reliable enterprise agents from fragile ones:

**1. Separation of Concerns**
Agent Script defines rails (deterministic); reasoning runs inside them.
- Critical paths (auth, routing, transactions) → `before_reasoning`, explicit transitions, Apex
- Creative tasks (answers, summaries, recommendations) → LLM reasoning

**2. Determinism Over Intelligence**
Prefer predictable flows over purely AI-driven logic for business-critical decisions. Example: use Apex to determine refund eligibility rather than asking the LLM to decide from policy text — result is 100% consistent vs. ~90% consistent.

**3. Progressive Disclosure**
Avoid context stuffing (15,000-word system instructions). Instead:
- Global Instructions: ~500 words (core behavior, universal guardrails)
- Topic 1 — Product Info: ~800 words (loaded only when topic selected)
- Topic 2 — Billing: ~600 words (loaded only when topic selected)
Only the relevant topic's instructions are loaded, giving the LLM a focused context for each task.

**4. Skills-Based Architecture (Atomic Design)**
Each action should do one thing well. Avoid monolithic actions that look up an account, check eligibility, create a case, send an email, and update a dashboard in one call — if email fails, everything fails. Build atomic actions and chain them explicitly.

**5. Pre-Processing Over Runtime**
Generate complex summaries offline (scheduled Apex), retrieve at runtime. Avoids 45-second waits and timeout risk on large datasets. A scheduled `QuarterlySummaryBatch` that pre-computes summaries into `Summary__c` objects reduces a query over 50,000 records to a 2-second lookup.

**The Golden Rule:** If you can't accept the agent being wrong 5–10% of the time, don't use an LLM for that decision — use code.
