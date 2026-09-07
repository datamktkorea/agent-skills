# Skill Design Principles

Use these rules when creating or revising agent skills. Write for the agent that performs the work. Every instruction must change a decision, protect a boundary, or define completion.

## Start with behavior

Define the behavior before the files.

- State the request that activates the skill.
- Identify the recurring failure or inconsistency.
- Define the observable result.
- Define decisions reserved for the user.
- Define where the skill stops.

Repeated prompt modifiers can reveal missing defaults. Keep project-specific preferences in the project unless they apply across repositories.

## Give the skill one job

Use one familiar organizing concept. Prefer terms with established meaning, such as atomic commits or release intent.

Define:

- inputs;
- outputs;
- allowed mutations;
- completion conditions;
- failure exits.

Split a skill only when a branch has a distinct purpose, sequence, or invocation need. Splitting files without reducing responsibility only moves complexity.

## Design invocation deliberately

Choose automatic discovery when the behavior should apply without the user naming the skill. Choose explicit-only invocation when the user must deliberately start the workflow.

Invocation and authorization are separate. Discovering a skill does not authorize a mutation. Infer authorization from the requested outcome and scope.

For explicit-only invocation:

- Claude Code: set `disable-model-invocation: true`.
- Codex: set `policy.allow_implicit_invocation: false` in `agents/openai.yaml`.

Verify runtime support before relying on metadata.

## Treat descriptions as routers

The description tells the agent when to load the skill. Include distinct triggers, not synonym lists. Put operating instructions in the body.

A reference pointer must state:

- the condition that requires the resource;
- the resource to read.

If a resource is skipped, improve its pointer before moving all content into `SKILL.md`.

## Keep one owner per behavior

Each behavior has one authoritative owner. A skill returns a usable result without forcing the next lifecycle step.

A caller must receive exact artifacts and status. Do not rely on hidden conversation state.

When composing skills:

- the caller owns orchestration;
- the callee owns its mutation;
- the callee returns exact paths, identifiers, and validation status;
- missing required dependencies are reported directly.

## Separate facts, policy, meaning, and intent

| Decision source | Owner |
| --- | --- |
| Git refs, changed paths, file presence, exit codes | Existing tools or deterministic code |
| Release units, required checks, repository conventions | Repository configuration or checker |
| Compatibility, user impact, summary wording | Agent reasoning |
| Unclear scope or material product intent | User |

Do not infer policy from directory names alone. Do not turn missing evidence into a negative result. Represent unknown and ambiguous states explicitly.

## Keep project policy in the project

Shared skills must remain useful across repository sizes, languages, and layouts. Keep deployment maps, branch conventions, release units, and custom gates in repository-owned configuration or checks.

Optional tools require mechanical detection. For Changesets:

- no `.changeset/config.json`: skip the Changesets branch;
- config present: use the repository's release policy;
- `check:changesets` present: treat it as the repository's automated gate;
- required integration missing: report it instead of inventing policy.

`check:changesets` is a company integration convention, not a Changesets standard. Do not require small projects to adopt Changesets only to simplify a shared skill.

## Use deterministic helpers selectively

Use code for repeated deterministic work such as parsing structured files, resolving refs, or returning machine-readable facts.

Prefer existing `git` and `gh` commands before adding wrappers. Add a script only when it removes repeated logic or prevents a demonstrated consistency error.

Return structured output. Distinguish candidates from verified facts and unsupported cases from empty results.

Portability is a dependency choice:

- `.sh` requires a compatible shell;
- `.mjs` requires Node.js;
- the application language does not guarantee the agent runtime.

Do not add a runtime dependency to unrelated skills.

## Place information by use

| Location | Content |
| --- | --- |
| `SKILL.md` | Purpose, workflow, boundaries, completion |
| `references/` | Conditional rules too large for the common path |
| `scripts/` | Repeated deterministic operations |
| `assets/` | Templates and output resources |

Create only the files the behavior requires. Keep each rule in one authoritative location. Read repository state instead of copying it into prose.

## Stabilize output when shape matters

Use a template when section names, order, or required evidence must remain stable.

Apply this precedence:

1. explicit user instruction;
2. applicable repository template;
3. meaningful existing structure during an update;
4. bundled team fallback.

A template defines shape, not facts. Never invent checks, QA, screenshots, issue links, or release details. Remove unused placeholders and guidance comments from the final output.

## Write direct instructions

- Use short sentences.
- Lead with the required action.
- Prefer positive instructions.
- Reserve prohibitions for hard boundaries.
- Keep rules beside their caveats.
- Remove repetition and explanations of standard agent behavior.
- Remove chronology, authorship notes, migration stories, and conversation context.
- Write comments and documentation as the current contract.

The common path must remain easy to scan. Use progressive disclosure only for real conditional branches.

## Define observable completion

Every important step needs a checkable result.

- Verify the exact artifact that will be committed or published.
- Re-run affected checks after the artifact changes.
- Read back remote state after publication.
- Report remaining work and partial success.
- Stop retries that make no progress.

Ask the user only when the answer changes a material decision. Ask about the unresolved decision, not the entire workflow.

## Validate behavior

Validate structure and behavior separately.

- Check frontmatter, links, syntax, and whitespace.
- Exercise meaningful branches and failure paths.
- Verify mutations against the requested scope.
- Test deterministic helpers with ambiguous and unsupported inputs.
- Inspect the final artifact or remote result.

Text matching proves that words exist. It does not prove agent behavior. Keep evaluation proportional to the risk and scope of the change.

## Review checklist

- Does the description route the correct requests?
- Does the skill have one clear job?
- Are inputs, outputs, mutations, and stopping conditions explicit?
- Are facts checked mechanically where practical?
- Does repository policy remain repository-owned?
- Are optional integrations detected mechanically?
- Are references and assets loaded only by relevant branches?
- Is output shape stable where required?
- Are completion and failure states observable?
- Can any sentence be removed without changing behavior?
- Does every comment and document state only the current contract?
