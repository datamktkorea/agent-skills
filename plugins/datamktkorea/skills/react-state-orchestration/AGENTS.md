# React Query + Zustand Patterns

## Structure

```text
react-query-zustand-patterns/
  SKILL.md       # Main skill file — read this first
  AGENTS.md      # This navigation guide
  CLAUDE.md      # Alias for AGENTS.md
  references/    # Detailed rule files
```

## Usage

1. Read `SKILL.md` for the core principle and pattern index
2. Read specific `references/` files for detailed rules and code examples
3. Reference files are loaded on demand — read only what is relevant to the task

Architectural patterns for separating server state (React Query) from client state (Zustand).
Applicable to any React or Next.js application using TanStack Query v5 + Zustand 5.

## When to Apply

Apply these patterns when:

- Writing or reviewing React Query hooks or Zustand stores
- Implementing optimistic updates
- Reading server data inside async functions (stale closure risk)
- Deciding where state lives: cache vs. Zustand vs. useState

## Reference Files

| File                                  | Content                                                       |
| ------------------------------------- | ------------------------------------------------------------- |
| `references/core-principle.md`        | State boundary — decision rules for what goes where           |
| `references/stale-time-gc.md`         | `staleTime: Infinity` + `gcTime` strategy                     |
| `references/adapter-hook.md`          | Adapter hook pattern + `select` optimization                  |
| `references/cache-helpers.md`         | `getEntityFromCache`, `setEntityInCache` helpers              |
| `references/optimistic-updates.md`    | `withOptimisticUpdate` — snapshot, write, rollback            |
| `references/zustand-session-slice.md` | Client-only transient state in Zustand                        |
| `references/anti-patterns.md`         | Patterns to avoid — mirrors, sync functions, missing rollback |
