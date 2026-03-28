---
title: Anti-Patterns to Avoid
impact: CRITICAL
tags: anti-patterns, zustand, react-query, sync, hydration
---

## Anti-Patterns to Avoid

These patterns appear frequently in codebases that grew from simple examples.
Each one creates subtle bugs that are hard to reproduce.

---

### 1. Zustand as a server data mirror

**Wrong:**

```typescript
// useEffect copies server data into Zustand after React Query succeeds
useEffect(() => {
  if (post) {
    store.addPost(post); // ❌ duplicates server data in Zustand
  }
}, [post]);

// Component reads from Zustand instead of the cache
const post = useAppStore((s) => s.posts.find((p) => p.id === postId));
```

**Why it fails:** Two sources of truth. The `useEffect` can miss updates (stale deps), run
after a re-render, or be skipped during concurrent rendering. Components reading from Zustand
may silently show data that diverges from the actual cache.

**Correct:** Read directly from React Query cache via `usePostData(postId)`.

---

### 2. sync\*ToStore() indirection functions

**Wrong:**

```typescript
function syncTagsToStore(result: TagResult) {
  store.updatePost(postId, { tags: result.tags });
}
function syncStatusToStore(result: StatusResult) {
  store.updatePost(postId, { status: result.status });
}
// ... one function per data type, all mirroring the cache into Zustand
```

**Why it fails:** Every new data type requires another sync function. These are easy to
forget when adding new mutations, causing silent data divergence between the cache and Zustand.

**Correct:** Use `setEntityInCache` / `setPostInCache` directly inside event handlers or
result-application hooks.

---

### 3. Reading Zustand in async functions for server data

**Wrong:**

```typescript
async function handleSave() {
  // Stale closure — Zustand snapshot may lag behind the React Query cache
  const post = useAppStore.getState().posts.find((p) => p.id === postId);
  await savePost(post); // might persist outdated data
}
```

**Why it fails:** `getState()` returns the last-synced Zustand snapshot, which can lag if
the hydration `useEffect` hasn't run yet or if the cache was updated by another mutation.

**Correct:**

```typescript
async function handleSave() {
  const post = getPostFromCache(queryClient, postId); // always reflects current cache
  await savePost(post);
}
```

---

### 4. Writing server response back to Zustand after a mutation

**Wrong:**

```typescript
const mutation = useMutation({
  mutationFn: updatePost,
  onSuccess: (data) => {
    store.updatePost(data.id, data); // ❌ maintains a redundant Zustand copy
  },
});
```

**Why it fails:** Same root cause as #1. Any divergence between the mutation response and
what React Query would return (e.g., server-computed fields) goes unnoticed.

**Correct:**

```typescript
const mutation = useMutation({
  mutationFn: updatePost,
  onSettled: (_data, _error, variables) => {
    // Invalidate → React Query refetches → all subscribers update automatically
    queryClient.invalidateQueries({ queryKey: ["post", variables.postId] });
  },
});
```

---

### 5. Optimistic update without rollback

**Wrong:**

```typescript
async function handleTagsChange(tags: string[]) {
  setPostInCache(queryClient, postId, (prev) => ({ ...prev, tags }));
  await updatePost({ postId, tags }); // if this throws, the cache is permanently wrong
}
```

**Why it fails:** On network error or server rejection, the cache now shows data that was
never actually saved. The user sees a lie.

**Correct:** Use `withOptimisticUpdate`, which snapshots before writing and restores on error.

```typescript
await withOptimisticUpdate(
  queryClient,
  ["post", postId],
  (prev) => ({ ...prev, tags }),
  () => updatePost({ postId, tags }),
);
```
