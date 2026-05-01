---
title: Adapter Hook with select Optimization
impact: HIGH
tags: react-query, adapter, select, performance, re-render
---

## Adapter Hook with select Optimization

When the raw API response shape differs from what components need, use an adapter hook
with a `select` function. This avoids transforming data inside components and eliminates
the temptation to mirror the transformed shape in Zustand.

### The pattern

```text
useGetPost        (raw query — owns the cache entry)
      ↓
normalizePost     (pure transform fn — module-level for referential stability)
      ↓
usePostData       (adapter hook — exposes NormalizedPost or a selected subset)
```

**Implementation:**

```typescript
// Pure transform — defined at module level, NOT inside the hook.
// Module-level reference is stable across renders, which keeps React Query's
// select memoization working correctly.
export function normalizePost(raw: RawPost): Post {
  return {
    id: raw.id,
    title: raw.title,
    body: raw.content.body,
    tags: raw.metadata?.tags ?? [],
    createdAt: new Date(raw.created_at),
    authorId: raw.author.id,
  };
}

// Generic adapter hook with optional sub-selection
export function usePostData<TData = Post>(
  postId: string | undefined,
  options?: { select?: (data: Post) => TData },
) {
  return useGetPost(postId, {
    select: (raw) => {
      const post = normalizePost(raw);
      return (options?.select ? options.select(post) : post) as TData;
    },
  });
}
```

### select optimization — prevent unnecessary re-renders

React Query's `select` uses referential equality (`Object.is`). If the selected value
hasn't changed, the component does NOT re-render even if other fields in the cache entry changed.

**Without select — re-renders on any field change:**

```typescript
const { data: post } = usePostData(postId);
// Renders when tags change, body changes, author changes, etc.
// even if this component only displays the title.
```

**With select — re-renders only when title changes:**

```typescript
const { data: title } = usePostData(postId, {
  select: (p) => p.title,
});
```

### Stable vs. unstable selects

React Query compares the selected result with `Object.is`. Primitives (string, number,
boolean) work automatically. For objects and arrays, return the same reference when the
underlying data hasn't changed — don't construct a new object inside `select`.

```typescript
// Stable — returns the same array reference if tags hasn't changed
select: (p) => p.tags;

// Unstable — creates a new object on every render → always re-renders
select: (p) => ({ tags: p.tags, count: p.tags.length });
// Fix: destructure in the component body or wrap with useMemo
```

### Applying the pattern to the raw query hook

```typescript
export function useGetPost<TData = RawPost>(
  postId: string | undefined,
  options?: { select?: (data: RawPost) => TData },
) {
  return useQuery({
    enabled: !!postId,
    queryKey: ["post", postId],
    queryFn: () => fetchPost(postId!),
    select: options?.select,
    staleTime: Infinity,
  });
}
```
