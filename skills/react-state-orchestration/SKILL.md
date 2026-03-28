---
name: react-state-orchestration
description: Clean architecture patterns for TanStack Query v5 + Zustand 5 in React/Next.js applications. Use this skill when writing, reviewing, or refactoring state management code — especially when touching server data fetching, Zustand stores, or async mutations. Triggers on tasks involving React Query hooks, Zustand selectors, optimistic updates, or cache management.
license: MIT
metadata:
  author: bingbong
  version: "1.0.0"
  date: March 2026
  abstract: Architectural patterns for separating server state (React Query) from client state (Zustand). Establishes React Query as the single source of truth for all server-fetched data, Zustand as purely client-only state, and provides concrete helper patterns — adapter hooks, cache helpers, optimistic updates with rollback — for building predictable, cache-coherent React applications without sync bugs.
---

# React Query + Zustand Clean Architecture Patterns

State management architecture for React/Next.js applications using TanStack Query v5 and Zustand 5.

## The Boundary

```
React Query cache  ─── server state (single source of truth)
useState           ─── local form / ephemeral component state
Zustand            ─── client-only UI state (NO server mirrors)
```

**The anti-pattern this replaces:**
```
API → React Query → useEffect hydration → Zustand items[] → Components
        fetch              mirror               store          read
```

This pattern creates two sources of truth, requires `sync*ToStore()` indirection,
and causes stale-state bugs when components read from Zustand instead of the cache.

## When to Apply

Apply these patterns when:
- Writing or reviewing `useQuery` / `useMutation` hooks
- Writing or reviewing Zustand store slices
- Implementing optimistic updates with rollback
- Reading server data inside async functions (stale closure risk)
- Deciding whether a piece of data belongs in RQ cache or Zustand
- Refactoring `useEffect` hydration that writes to Zustand

## Pattern Index

| Priority | Pattern | Impact | Reference File |
|----------|---------|--------|---------------|
| 1 | State boundary — what goes where | CRITICAL | `references/core-principle.md` |
| 2 | `staleTime: Infinity` + `gcTime` strategy | HIGH | `references/stale-time-gc.md` |
| 3 | Adapter hook with `select` optimization | HIGH | `references/adapter-hook.md` |
| 4 | Cache helpers — imperative read/write | HIGH | `references/cache-helpers.md` |
| 5 | Optimistic update + automatic rollback | HIGH | `references/optimistic-updates.md` |
| 6 | Zustand session slice for client-only state | MEDIUM | `references/zustand-session-slice.md` |
| 7 | Anti-patterns to avoid | CRITICAL | `references/anti-patterns.md` |

## Quick Reference

### Reading server data in async functions
```typescript
// WRONG — stale closure from Zustand mirror
const post = useAppStore.getState().posts.find(p => p.id === postId);

// CORRECT — always fresh from React Query cache
const post = getEntityFromCache(queryClient, postId);
```

### Optimistic update with rollback
```typescript
await withOptimisticUpdate(
  queryClient,
  postId,
  (prev) => ({ ...prev, tags }),   // 1. update cache immediately
  () => updatePost({ postId, tags }), // 2. persist in background
  // auto-rollback to snapshot on error
);
```

### Component: select only what you need
```typescript
// Re-renders only when title changes, not on any field change
const { data: title } = usePostData(postId, {
  select: (d) => d.title,
});
```

### Zustand: client-only state only
```typescript
// WRONG — server data mirror
store.addPost(postFromServer);        // called in useEffect after fetch
store.updatePost(id, serverResponse); // called after mutation success

// CORRECT — transient client state only
store.setDraftContent(postId, content); // local editor state
store.setActiveView('editor');          // UI navigation state
```

## References

- TanStack Query v5 Docs: https://tanstack.com/query/v5/docs
- Zustand 5 Docs: https://zustand.docs.pmnd.rs/
- "Does React Query replace Redux/Zustand?": https://tanstack.com/query/v5/docs/framework/react/guides/does-this-replace-client-state-managers
