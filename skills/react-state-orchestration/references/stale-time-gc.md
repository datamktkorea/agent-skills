---
title: staleTime and gcTime Strategy
impact: HIGH
tags: react-query, staleTime, gcTime, cache, performance
---

## staleTime and gcTime Strategy

Choosing the right cache lifetime settings prevents unnecessary network requests while
still freeing memory for unused data.

### Default config (global QueryClient)

```typescript
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60 * 1000, // 1 min — suitable for most list/read queries
      gcTime: 5 * 60 * 1000, // 5 min — default React Query value
      retry: 1,
    },
  },
});
```

### Per-query override for single-editor resources

Resources that only one user edits at a time (e.g., a document or settings record
during an active editing session) should never background-refetch. Use `staleTime: Infinity`
to disable it.

**Incorrect (default staleTime causes unwanted refetches):**

```typescript
useQuery({
  queryKey: ["post", postId],
  queryFn: () => fetchPost(postId),
  // staleTime: 60s — React Query refetches on window focus,
  // potentially overwriting optimistic cache updates mid-edit.
});
```

**Correct (`staleTime: Infinity`, keep default `gcTime`):**

```typescript
useQuery({
  queryKey: ["post", postId],
  queryFn: () => fetchPost(postId),
  staleTime: Infinity, // never background-refetch; invalidateQueries drives refresh
  // gcTime: default (5 min) — cache is freed 5 min after last subscriber unmounts
});
```

### When to use `staleTime: Infinity`

Use when ALL of the following are true:

- Only one user (or one session) edits the resource at a time
- You control all mutation paths and can call `invalidateQueries` after every save
- Background refetch would race with or overwrite optimistic updates

### Force a refresh explicitly after save

```typescript
useMutation({
  mutationFn: updatePost,
  onSettled: (_data, _error, variables) => {
    // Explicit invalidation after save — this is the only way the cache refreshes
    queryClient.invalidateQueries({ queryKey: ["post", variables.postId] });
  },
});
```

### gcTime and memory management

`gcTime` controls how long an _inactive_ cache entry (zero mounted subscribers) is kept in memory.

- Keep the default (5 min) so navigating back to a page feels instant.
- Do NOT set `gcTime: Infinity` — this causes unbounded memory growth in apps with many unique query keys.
- For large list queries you don't expect the user to revisit, a shorter `gcTime` (e.g., 1–2 min) is appropriate.
