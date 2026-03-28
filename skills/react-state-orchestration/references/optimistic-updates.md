---
title: Optimistic Update with Automatic Rollback
impact: HIGH
tags: react-query, optimistic-update, rollback, setQueryData, ux
---

## Optimistic Update with Automatic Rollback

Show the user the result of their action immediately while the server saves in the background.
If the save fails, automatically revert to the previous cache state.

### withOptimisticUpdate helper

A reusable helper that co-locates the snapshot, optimistic write, persist, and rollback steps.

```typescript
// hooks/use-entity-cache.ts

export async function withOptimisticUpdate<T>(
  queryClient: QueryClient,
  queryKey: unknown[],
  updater: (prev: T) => T,
  persistFn: () => Promise<void>,
): Promise<void> {
  // 1. Snapshot the current cache entry
  const previous = queryClient.getQueryData<T>(queryKey);

  // 2. Apply the optimistic update immediately
  queryClient.setQueryData<T>(queryKey, (old) => (old ? updater(old) : old));

  try {
    // 3. Persist to the server
    await persistFn();
  } catch (error) {
    // 4. Rollback on error
    if (previous !== undefined) {
      queryClient.setQueryData<T>(queryKey, previous);
    }
    throw error; // caller handles toast / user notification
  }
}
```

### Usage

```typescript
async function handleTagsChange(tags: string[]) {
  try {
    await withOptimisticUpdate(
      queryClient,
      ["post", postId],
      (prev) => ({ ...prev, metadata: { ...prev.metadata, tags } }), // optimistic
      () => updatePost({ postId, tags }), // persist
    );
  } catch {
    toast.error("Failed to save. Changes reverted.");
  }
}
```

### Manual rollback (without the helper)

When you need more control — e.g., rolling back multiple query keys at once:

```typescript
async function handleUpdate() {
  // 1. Cancel in-flight queries to avoid overwriting the optimistic update
  await queryClient.cancelQueries({ queryKey: ["post", postId] });

  // 2. Snapshot
  const previousPost = queryClient.getQueryData(["post", postId]);
  const previousList = queryClient.getQueryData(["posts"]);

  // 3. Optimistic writes
  queryClient.setQueryData(["post", postId], (old) => ({ ...old, ...changes }));
  queryClient.setQueryData(["posts"], (old: Post[]) =>
    old.map((p) => (p.id === postId ? { ...p, ...changes } : p)),
  );

  try {
    await persist();
  } catch {
    // 4. Rollback all affected keys
    queryClient.setQueryData(["post", postId], previousPost);
    queryClient.setQueryData(["posts"], previousList);
    toast.error("Failed to save");
  }
}
```

### Rules

1. **Always snapshot before writing** — call `getQueryData` before any `setQueryData`.
2. **Re-throw after rollback** — the caller owns the user-facing error message (toast, alert, etc.).
3. **Prefer co-located helpers over `onMutate`/`onError`** — `useMutation`'s lifecycle callbacks
   scatter snapshot/rollback across three functions. The `withOptimisticUpdate` helper keeps
   all four steps in one place and is easier to follow.
4. **Invalidate after success** — call `invalidateQueries` in `onSettled` so the cache is
   eventually reconciled with the server, even if the optimistic update was correct.

```typescript
useMutation({
  mutationFn: updatePost,
  onSettled: (_data, _error, variables) => {
    queryClient.invalidateQueries({ queryKey: ["post", variables.postId] });
  },
});
```
