---
name: code-cleanup
description: Remove AI-generated code patterns ("slop") from a branch. Use when asked to clean up AI-generated code, remove slop, fix AI coding style issues, or make AI-written code look human-written. Triggers on phrases like "remove slop", "clean up AI code", "fix AI style", or "make this look human-written".
---

# Code Cleanup

Remove AI-generated patterns from code changes while preserving intentional functionality.

## Workflow

1. Get the diff: `git diff master...HEAD` (or specified base branch)
2. For each changed file, compare new code against the file's existing style
3. Remove identified slop patterns
4. Report a 1-3 sentence summary of changes, with
  ✅ Files Cleaned (12)
   -filelist-
  👀 Read But Clean (3)
  -filelist-
  ❌ Not Yet Checked (29)
  -filelist-
5. Continue working through "Not Yet Checked" files
6. If there are no files left, report a summary of your activities to the user

## Slop Patterns to Remove

**Unnecessary comments**
- Obvious comments (`// increment counter`, `// return the result`)
- Comments explaining what code does rather than why
- Commented-out code — delete it, git has it
- TODOs with no owner or ticket (`// TODO: fix this later`)
- `@param` / `@returns` that only restate the TypeScript signature
- Section dividers inconsistent with file style

In `apps/backend`, apply the repo's commenting standard rather than judging
case by case: `docs/backend-commenting.md`. It sets a default of no comment
with a short list of exceptions (non-obvious why, a workaround with its cause,
a cross-file invariant, a type assertion, external spec/vendor behaviour, an
entity predicate's business rule, test scenario setup). Read it before
stripping comments from backend files — some of what looks like narration is a
listed exception, and entity predicates are *required* to carry JSDoc.

**Defensive overkill**
- Try/catch blocks around code that can't throw or is already in trusted paths
- Null checks where values are guaranteed
- Type guards that duplicate existing validation

**Type escapes**
- Casts to `any` to bypass type errors
- `@ts-ignore` / `@ts-expect-error` without justification
- Overly loose generic types (`Record<string, any>`)

**Style inconsistencies**
- Naming conventions that differ from the file (camelCase vs snake_case)
- Brace/spacing style that doesn't match surrounding code
- Import organization that breaks file patterns

**Drizzle artifacts to revert**
- Changes to `_journal.json` files (migration journal)
- Changes to Drizzle snapshot files (`meta/*_snapshot.json`)
- Auto-generated migration files that weren't intentionally created
- Revert these with: `git checkout master -- <file>` or remove from staging

**Duplicate hooks/utilities**
- Multiple files with the same name serving similar purposes—consolidate to one
- Read-only hooks when a CRUD hook already exists for the same entity
- Delete the simpler duplicate, update imports to use the complete version

**Redundant error handling**
- `onError` handlers in mutations when QueryClient already handles errors globally via `MutationCache.onError`
- Duplicate toast notifications that the global handler already shows
- Check App.tsx or QueryClient setup before adding per-mutation error handlers

**Manual cache invalidation**
- Direct `queryClient.invalidateQueries()` calls when `useOptimism` hook is available
- Use `useOptimism` functions instead:
  - `optimisticalltyAddToList` for create operations
  - `optimisiticallyUpdateObjectInList` for updates
  - `optimisticallyRemoveFromList` + `revertOptimisticUpdate` for optimistic deletes
  - `syncCacheWithServer` for post-mutation sync

**One-off mutations duplicating existing hooks**
- Components creating mutations that already exist in nearby hooks
- A "bulk" action hook can handle single items—use it instead of creating a new mutation
- Look for existing `use*Actions` or `use*Mutations` hooks before creating inline mutations

## Guidelines

- Preserve functionality—only remove stylistic slop
- When uncertain, match the existing file's conventions
- Keep the summary brief: what categories of slop were found and removed
