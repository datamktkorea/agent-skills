---
name: git-pull-request
description: Create or update a GitHub pull request through gh when the user requests it. Prepare scoped commits, enforce the repository's optional Changeset check, push the branch, and publish a concise title and body. Respect requests for text only.
disable-model-invocation: true
---

# Git Pull Request

Turn the intended branch changes into a review-ready PR. Default to a concise body and automatic execution through `gh pr create` or `gh pr edit`.

## Scope

An explicit PR request authorizes the necessary scoped commits, normal branch push, and PR creation or update. Announce the target and proceed without routine confirmation. A request for a description, plan, or review alone authorizes only that output.

For text-only requests, perform the relevant read-only inspection and return the text. Skip commits, release-file generation, push, and PR mutations; report unavailable evidence without requiring publishing credentials.

Use the sibling [git-commit](../git-commit/SKILL.md) and [changeset](../changeset/SKILL.md) skills when needed. Resolve them through the installed skill namespace or read their linked instructions if the runtime has no skill invocation tool. If a required sibling is unavailable, report the missing dependency.

This workflow ends at PR creation or update. Rebase, force push, merge, close, versioning, and deployment require separate instructions.

## Establish the target

Before changing files or history, inspect the repository instructions, Git status, current branch, remotes, and upstream. Verify `gh` is installed and authenticated for the target host; report a prerequisite failure without initiating login or installation.

Use structured GitHub output to identify the target repository and any open PR for the exact head repository and branch:

```text
gh repo view --json nameWithOwner,defaultBranchRef
gh pr list --repo <repository> --state open --head <branch> --json number,url,baseRefName,headRefName,headRepository,headRepositoryOwner,isCrossRepository
```

Confirm repository identity against Git remotes, especially with forks. Keep the base repository, base remote, push remote, and head branch explicit throughout. If several matching PRs or remotes leave the destination ambiguous, ask one focused question.

Choose the base in this order:

1. The user's explicit base.
2. The existing PR's base.
3. An explicit repository PR-target convention.
4. The remote repository's default branch.

Branch prefixes do not determine the base. An existing PR retains its base unless the user requests a change.

Fetch the selected base into its remote-tracking ref and resolve its commit. Use that ref as `<base-ref>`. Report fetch or resolution failures rather than treating stale or missing refs as current. A branch being behind its base does not by itself require rebase.

Resolve a named head branch before proceeding. If HEAD is detached or the head would be the same branch in the same repository as the base, resolve the intended source branch with the user.

## Prepare the branch

Read the staged, unstaged, and relevant untracked changes. If intended work remains uncommitted, invoke `git-commit` with that scope and exclusions. Preserve unrelated work. If the request is only to update PR metadata, use the committed branch as it stands unless additional work was explicitly included.

After committing, inspect:

```text
git log --oneline <base-ref>..HEAD
git diff --stat <base-ref>...HEAD
git diff <base-ref>...HEAD
```

Use the three-dot diff to describe the proposed change. Stop if there is no diff to propose. Describe only committed content; report excluded working-tree changes separately.

Run repository-required checks and relevant verification in proportion to the change. Preserve actual results. Do not refactor code, rewrite comments, or repair unrelated failures as part of PR preparation.

## Enforce the optional Changeset gate

Check for `.changeset/config.json` using a filesystem operation. If absent, skip this section entirely; this workflow needs neither Node nor a package manager in that repository.

If present, read the sibling Changeset instructions and run its `scripts/inspect.mjs` from the target repository with `--base <base-ref> --head <head-branch>`. Require an available base, an unambiguous package manager, and the exact `check:changesets` script. Missing or unsupported integration is a blocker, not permission to skip the gate.

Run `check:changesets` using the repository's package-manager argument forwarding and the same base ref and head branch. Read the checker entry point when necessary to establish how it handles refs and working-tree files. Use a branch name for `--head` so branch-specific release rules remain available.

- On success, continue without creating a Changeset merely for its presence.
- On a missing or invalid branch-local Changeset, invoke `changeset` with the same refs and diagnostics.
- On configuration, ref, tooling, or unrelated-file failures, report the blocker. Do not edit release policy to make the check pass.
- On a repository-identified Version PR, run its checker but do not generate new Changesets; release automation owns those files.

After `changeset` returns, inspect its exact changed paths. Delegate only those paths to `git-commit` when the remaining issue is repairable by committing the prepared files. Preserve unrelated staged work according to that skill's contract. Then re-run the same checker yourself.

A successful working-tree check is insufficient if it relied on uncommitted Changeset files or policy changes. Ensure the files used by the checker match the committed branch; commit only intended files through `git-commit`, or stop and explain the mismatch. Do not discard unrelated edits to obtain a clean check.

Continue only after the checker passes for the committed content being proposed. If a repair makes no progress or an unrelated error remains, stop with the diagnostics instead of repeating the generation loop.

## Write for the reviewer

Select the body template before drafting. An explicitly requested template wins. Otherwise query the selected base repository's Git tree through `gh api`, using the resolved base commit, and match template paths case-insensitively in these standard locations:

```text
gh api "repos/<repository>/git/trees/<base-sha>?recursive=1"

PULL_REQUEST_TEMPLATE.md
docs/PULL_REQUEST_TEMPLATE.md
.github/PULL_REQUEST_TEMPLATE.md
.github/PULL_REQUEST_TEMPLATE/*.md
```

Use the repository template when one applicable template is clear. If several templates remain plausible and repository context does not identify one, ask one focused question. Do not choose by filename preference or blend several templates. Read the selected file from that base commit:

```text
gh api -H "Accept: application/vnd.github.raw+json" \
  "repos/<repository>/contents/<template-path>?ref=<base-sha>"
```

Do not use a same-named working-tree file. This keeps the PR aligned with the repository receiving it.

When updating an existing PR, map the final content into the selected repository template while preserving relevant human-written context. If no repository template applies, retain a meaningful existing PR structure. For a new PR, or an existing PR without a meaningful structure, read and use [the team fallback template](assets/PULL_REQUEST_TEMPLATE.md). Do not improvise a different layout.

The team fallback always keeps `Summary`, `Changes`, and `Verification`, in that order relative to the optional sections. Include `Review Points`, `Release`, `Breaking Changes`, `Screenshots`, and `Related Issues` only when supported by the diff or repository evidence, and keep their template order. Remove all guidance comments, placeholder content, empty optional sections, and empty `Automated` or `Manual` subsections before publishing.

Follow the selected template's conventions. With the team fallback, use an English Conventional Commit title with Gitmoji, and concise Korean narrative with English technical terms.

Lead with the concrete problem and resulting behavior. A small PR usually needs only a short summary and verification. Add review points, compatibility or migration notes, and release-unit/bump information only when they help assess the change. Omit empty sections and commit-by-commit inventories.

Record tests as passed only when execution or a matching CI result supports it. Distinguish tests added from tests run; mark unperformed verification honestly.

When updating, rewrite the description around the final diff while preserving relevant issue links, human QA evidence, and reviewer context. Keep labels, reviewers, assignees, and draft status unless the user requests changes. Migrating content into a selected template must not erase relevant human-written material. A template does not justify inventing checked boxes or replacing human verification with guesses.

Write the body as UTF-8 with real newlines to a unique file in the platform's temporary directory. Pass it with `--body-file`; quote the title and other arguments for the active shell. Avoid interpolating Markdown into shell code. Do not create a permanent `PULL_REQUEST.md` unless requested.

## Publish and confirm

Record the local HEAD SHA used for the final diff and checks. Re-check it before publishing; if commits changed, refresh the description and affected checks.

Push only the intended head branch to the resolved push remote with a normal explicit refspec, such as `git push <push-remote> HEAD:refs/heads/<head-branch>`. For metadata-only requests, do not publish additional local commits; base the description on the existing PR's remote head. A rejected push requires diagnosis, not force push. Verify that the remote head SHA equals the inspected SHA.

Re-query the exact head's open PR before creating one. If a PR already exists, update it:

```text
gh pr edit <number> --repo <repository> --title <title> --body-file <temporary-file>
```

Pass `--base <base-branch>` on edit only when the user requested a base change and the diff and checks were refreshed against it.

Otherwise create the PR with explicit target and source:

```text
gh pr create --repo <repository> --base <base-branch> --head <head-selector> --title <title> --body-file <temporary-file>
```

Use the pushed branch as the head selector, qualified by its owner for a supported fork workflow. Add `--draft` when requested. Do not silently fork or choose a different repository if the selected head is unsupported.

If creation times out or returns an uncertain result, query for the PR before retrying. Report partial completion accurately, including a successful push followed by a failed PR operation.

Finally read the PR back with `gh pr view <number> --repo <repository> --json url,title,body,baseRefName,headRefName,headRefOid,isDraft`. Verify the target, content, and head SHA, then remove the temporary body file after success.

Return the PR URL, whether it was created or updated, its base and head, and any material verification gaps. PR publication does not imply CI or QA has passed.
