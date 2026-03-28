---
title: Cache Helpers — Imperative Read and Write
impact: HIGH
tags: react-query, setQueryData, getQueryData, async, stale-closure
---

## Cache Helpers — Imperative Read and Write

React hooks cannot be called inside async functions. When event handlers or async flows
need to read or write server state, use imperative cache helpers instead of accessing
a Zustand mirror.

### The stale closure problem

```typescript
// WRONG — reads from a Zustand mirror; snapshot may lag the actual cache
async function handleSave() {
  const post = useAppStore.getState().posts.find((p) => p.id === postId);
  await savePost(post); // might persist stale data
}
```

Even `getState()` returns the last-synced Zustand snapshot. If the React Query cache was
updated (e.g., by another mutation or window focus refetch) but the Zustand hydration
`useEffect` hasn't run yet, the snapshot is outdated.

### getEntityFromCache — imperative read

```typescript
// hooks/use-entity-cache.ts

export function getEntityFromCache<T>(
  queryClient: QueryClient,
  queryKey: unknown[],
): T | undefined {
  return queryClient.getQueryData<T>(queryKey);
}

// Or with a built-in normalizer for your domain:
export function getPostFromCache(
  queryClient: QueryClient,
  postId: string,
): Post | undefined {
  const raw = queryClient.getQueryData<RawPost>(["post", postId]);
  if (!raw) return undefined;
  return normalizePost(raw);
}
```

Usage in async functions:

```typescript
async function handleSave() {
  const post = getPostFromCache(queryClient, postId); // always reflects latest cache
  await savePost(post);
}
```

### setEntityInCache — imperative write

Updates the cache directly. Triggers all `useQuery` subscribers synchronously,
so components re-render immediately — no network round-trip required.

```typescript
export function setEntityInCache<T>(
  queryClient: QueryClient,
  queryKey: unknown[],
  updater: (prev: T) => T,
): void {
  queryClient.setQueryData<T>(queryKey, (old) => (old ? updater(old) : old));
  // no-op if the cache entry doesn't exist yet
}

// Domain-specific convenience wrapper:
export function setPostInCache(
  queryClient: QueryClient,
  postId: string,
  updater: (prev: RawPost) => RawPost,
): void {
  setEntityInCache<RawPost>(queryClient, ["post", postId], updater);
}
```

Usage:

```typescript
// Immediately reflect a tag change in all subscribed components
setPostInCache(queryClient, postId, (prev) => ({
  ...prev,
  metadata: { ...prev.metadata, tags },
}));
```

### When to use each helper

| Situation                                          | Use                                                  |
| -------------------------------------------------- | ---------------------------------------------------- |
| Read server data inside an async function          | `getPostFromCache`                                   |
| Write server data without a network request        | `setPostInCache`                                     |
| Write + persist to server + auto-rollback on error | `withOptimisticUpdate` (see `optimistic-updates.md`) |
| Invalidate after a successful mutation             | `queryClient.invalidateQueries`                      |
