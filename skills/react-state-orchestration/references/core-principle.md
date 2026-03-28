---
title: State Boundary — What Goes Where
impact: CRITICAL
tags: architecture, react-query, zustand, state-management
---

## State Boundary — What Goes Where

Every piece of state must have exactly one owner. Mixing ownership creates sync bugs.

| State type                        | Owner                  | Examples                                      |
| --------------------------------- | ---------------------- | --------------------------------------------- |
| Server data (fetched from API/DB) | React Query cache      | post detail, user profile, item list          |
| Derived server data               | `select` in `useQuery` | flattened fields, computed values             |
| Optimistic mutations              | `setQueryData`         | pre-save UI updates                           |
| Transient client state            | Zustand                | editor draft content, in-progress uploads     |
| UI state                          | Zustand                | active view, modal open/closed, sidebar state |
| Form / local ephemeral            | `useState`             | input values, unsubmitted drafts              |

### Decision rule

Before adding state, ask: _"Does this come from the server or will it ever be saved to the server?"_

- **Yes** → React Query cache is the source of truth. Components read from `useQuery`. Mutations write with `setQueryData` or `invalidateQueries`.
- **No** → Zustand (if shared across components) or `useState` (if local to one component).

**Incorrect (Zustand as server mirror):**

```typescript
// useEffect copies server data into Zustand after fetch
useEffect(() => {
  if (postData) {
    store.addPost(postData); // ❌ writes server data into Zustand
  }
}, [postData]);

// Component reads from Zustand instead of cache
const post = useAppStore((s) => s.posts.find((p) => p.id === postId));
```

**Correct (React Query as single source of truth):**

```typescript
// No hydration useEffect — component reads directly from cache
const { data: post } = usePostData(postId);

// Mutations update the cache, not Zustand
setEntityInCache(queryClient, postId, (prev) => ({
  ...prev,
  tags,
}));
```

### Why the mirror pattern fails

1. **Two sources of truth diverge** — network errors, race conditions, or missed `useEffect` deps leave Zustand stale.
2. **Sync indirection** — every mutation needs a matching `sync*ToStore()` call. These are easy to forget.
3. **Stale closures** — async functions that close over Zustand state read values that were current at render, not at call time.
4. **Over-rendering** — Zustand subscriptions trigger even when the changed key is unrelated to the subscriber.
