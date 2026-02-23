# TypeScript Indentation Investigation

## The Problem

In `.tsx` files (typescriptreact filetype), newlines after block openings (`{`, `({`,
`() => {`) consistently indent +2 spaces more than expected. Example:

```typescript
  const [treeSelection, setTreeSelection] = useResourceTreeSelection({
      // lands here (6 spaces, expected 4)
    service: rts,         // manually corrected to 4
  })
  const treeRootItem = useMemo(() => {
      // lands here (6 spaces, expected 4)
    return {
        // lands here (8 spaces, expected 6)
```

## Environment

- Neovim 0.11+, installed at `/opt/nvim`
- nvim-treesitter, lazy.nvim
- LSP: vtsls (TypeScript), biome, eslint
- Completion: blink.cmp
- `options.lua` sets `shiftwidth=2`, `tabstop=2`, `expandtab=true`
- **But**: `shiftwidth` is overridden to **4** in TSX buffers by something else
  (confirmed: `:echo shiftwidth()` → 4, `:verbose set shiftwidth?` → 4)

## Root Cause (Session 3)

`GetTypescriptIndent()` is working correctly. For a line ending in `{` it returns:

```
indent(GetMSL(lnum)) + shiftwidth()
```

With `shiftwidth()` = 4 and base indent = 2: `2 + 4 = 6`. Mathematically correct given
the actual shiftwidth. The indentation looks wrong because `shiftwidth` is 4 when the user
expects 2.

**Diagnostic that found it** (Session 3):
- `<Esc>o` from normal mode produced identical wrong result → blink.cmp ruled out
- `:set cindent? smartindent? autoindent? indentexpr?` → `nocindent nosmartindent autoindent GetTypescriptIndent()` → settings correct
- `:echo shiftwidth()` → **4** (expected 2) → shiftwidth overridden in TSX buffers

**Why options.lua doesn't win:** Neovim 0.9+ has built-in EditorConfig support
(`$VIMRUNTIME/plugin/editorconfig.lua`). If the project has a `.editorconfig` with
`indent_size = 4` for TypeScript files, it overrides `shiftwidth` after options.lua runs.

## Pending

Run `:verbose set shiftwidth?` and check the "Last set from" line to identify the source.
Fix: either update `.editorconfig`, or add a buffer autocmd to force `shiftwidth=2` for
typescriptreact (though respecting the project config is usually correct).

---

## Historical Investigation

### What We Learned About nvim-treesitter Branches

#### `main` branch (what was installed)
- **Parser manager only** — no auto-highlight, no auto-indent, no FileType autocmds
- `setup()` only accepts `install_dir`; `ensure_installed`, `indent`, `highlight` are **silently ignored**
- Queries stored in `runtime/queries/` — lazy.nvim does NOT add this to rtp automatically
  - Symptom: `vim.treesitter.query.get("typescript", "indents")` returns nil
- `ensure_installed` equivalent (`install()`) re-runs on every launch without proper detection
- Designed to be wrapped by a framework (e.g. LazyVim), not used standalone
- **Verdict: wrong branch for a standalone config**

#### `master` branch (correct for standalone use)
- Full module system via `require("nvim-treesitter.configs").setup({...})`
- `ensure_installed` works properly
- `indent = { enable = true }` registers FileType autocmds automatically
- Frozen/locked but stable — correct choice for independent configs

### Load Order Discovery

`$VIMRUNTIME/indent/typescript.vim` fires **AFTER** user FileType autocmds but **BEFORE**
`after/indent/` files. Therefore:

- **FileType autocmd** → sets indentexpr → overridden by `$VIMRUNTIME/indent/typescript.vim` ❌
- **`after/indent/typescript.lua`** → fires last, wins ✓

### What Was Tried and Ruled Out

1. **treesitter indent on `main` branch** — silently ignored, never active
2. **treesitter indent on `master` branch** — active but wrong results (6-8 spaces), known open bugs
3. **Disabled treesitter indent for JS/TS** — fell back to `GetTypescriptIndent()`, still wrong
4. **blink.cmp preselect** — `<Esc>o` produced identical wrong results, ruling out blink.cmp entirely
5. **LSP format-on-type** — Neovim 0.11 does not auto-wire `textDocument/onTypeFormatting`

### `GetTypescriptIndent()` Code Analysis (Session 2)

For a line ending with `useResourceTreeSelection({` (indent = 2):

1. Closing bracket check → no match (new line is empty)
2. `s:Match(lnum, s:block_regex)` → matches `{` at end of line
3. Returns `indent(s:GetMSL(lnum, 0)) + shiftwidth()`

With `shiftwidth()` = 2 this gives 4 (correct). With `shiftwidth()` = 4 this gives 6
(what was observed). The function itself is correct — it was being called with the
wrong `shiftwidth` all along.

### blink.cmp Accept Mechanism (Session 3, for reference)

`cmp.accept()` returns `true` synchronously and schedules actual text insertion via
`vim.schedule`. With `preselect = true`, Enter always accepts the first completion when
the menu is visible. This was investigated as a potential cause but ruled out by `<Esc>o`
reproducing the same indent value.

The `preselect = false` change in `completion.lua` and `select_and_accept` for Tab were
applied based on this wrong hypothesis and can be reverted if the shiftwidth fix resolves
the indentation — though `preselect = false` is independently recommended by blink.cmp
docs for the `enter` preset to avoid accidentally accepting completions on Enter.
