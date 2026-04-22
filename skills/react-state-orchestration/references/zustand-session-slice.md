---
title: Zustand Session Slice for Client-Only State
impact: MEDIUM
tags: zustand, client-state, transient, session, prop-drilling
---

## Zustand Session Slice for Client-Only State

Some data is generated or transformed on the client and never stored in the database
in that form (e.g., rich-text editor content, rendered previews, unsaved drafts).
This data is legitimately client-only and belongs in Zustand — not in React Query cache,
and not prop-drilled through the component tree.

### When to use a Zustand slice instead of React Query

Use Zustand for data that:

- Is produced client-side (e.g., editor state, rendered output, computed previews)
- Is transient — can be discarded when the user navigates away
- Does NOT need to be persisted to the server in its current form
- Is needed by multiple components deep in the tree (avoiding prop drilling)

### Example: document editing session

```typescript
// store/editor-session.ts

interface EditorSessionStore {
  // Transient editor state — NOT server mirrors
  draftContent: Record<string, JSONContent>; // rich-text editor state per document ID
  previewHtml: Record<string, string[]>; // client-rendered HTML per document ID
  setDraftContent: (docId: string, content: JSONContent) => void;
  setPreviewHtml: (docId: string, html: string[]) => void;

  // Baseline for change detection — also client-only
  savedSnapshot: Record<string, JSONContent>;
  setSavedSnapshot: (docId: string, content: JSONContent) => void;

  // UI state — always client-only
  activeView: "editor" | "preview" | "settings";
  sidebarOpen: boolean;
  setActiveView: (view: "editor" | "preview" | "settings") => void;
  setSidebarOpen: (open: boolean) => void;
}

export const useEditorStore = create<EditorSessionStore>()(
  devtools((set) => ({
    draftContent: {},
    previewHtml: {},
    setDraftContent: (docId, content) =>
      set((s) => ({ draftContent: { ...s.draftContent, [docId]: content } })),
    setPreviewHtml: (docId, html) =>
      set((s) => ({ previewHtml: { ...s.previewHtml, [docId]: html } })),

    savedSnapshot: {},
    setSavedSnapshot: (docId, content) =>
      set((s) => ({ savedSnapshot: { ...s.savedSnapshot, [docId]: content } })),

    activeView: "editor",
    sidebarOpen: true,
    setActiveView: (view) => set({ activeView: view }),
    setSidebarOpen: (open) => set({ sidebarOpen: open }),
  })),
);
```

### Combining React Query + Zustand at the component boundary

When a component needs both server data and client-side transient state,
merge them in the component — not inside the store or a shared hook.

```typescript
// PostEditor.tsx

const { data: post } = usePostData(postId); // server data from RQ cache
const draftContent = useEditorStore(
  // client-only transient state
  (s) => s.draftContent[postId],
);
const previewHtml = useEditorStore((s) => s.previewHtml[postId]);

// Combine at the component boundary — keeps each store's responsibility clear
const editorProps = post ? { ...post, draftContent, previewHtml } : undefined;
```

### What NOT to put in the session slice

```typescript
// WRONG — these come from the server; use React Query + setEntityInCache instead
editingTitle:   string;   // → usePostData(id, { select: (p) => p.title })
editingTags:    string[]; // → setPostInCache when user edits tags
editingStatus:  string;   // → setPostInCache when status changes
```

### Reset session state on navigation

Clear transient state when the user leaves the editing session to prevent memory leaks
and stale data appearing on re-entry:

```typescript
useEffect(() => {
  return () => {
    store.setDraftContent(docId, null);
    store.setPreviewHtml(docId, []);
  };
}, [docId]);
```
