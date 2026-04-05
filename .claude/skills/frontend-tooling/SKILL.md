---
name: frontend-tooling
description: Personal frontend tooling conventions — Yarn Berry, Biome, node:test, TypeScript with native type-stripping. Use when working on JS/TS projects, configuring tooling, writing tests, or running linters/formatters.
---

# Frontend Tooling Standards

## Package Management

- Yarn Berry (v4+), `nodeLinker: node-modules` — no PnP
- Corepack is available and used; `packageManager` field in `package.json` pins the version
- Use `yarn`, not `npm`/`pnpm`, unless strictly necessary
- Yarn Berry CLI differs from npm — e.g. `yarn npm audit`, `yarn npm info` for registry queries; `yarn dlx` not `npx`

## Linting & Formatting: Biome

- Biome is the sole linter and formatter — no ESLint, no Prettier
- Biome conflates lint fixes and formatting; `biome format` alone misses sort/organise actions
- Correct invocations:
  - **Lint (check only):** `biome check --enforce-assist=true`
  - **Format (apply fixes):** `biome check --fix --enforce-assist=true`
- `--enforce-assist=true` enforces key/import sorting as errors during lint and applies them during format
- `--fix` implies `--write`; do not pass both
- Wire Biome at monorepo root; it handles the whole tree

## TypeScript

- Target TS ≥6; use TS 6-compatible tsconfig syntax
- Erasable syntax only: const-object "enums" over `enum`, no legacy decorators, no namespace-value merging; `erasableSyntaxOnly: true` in tsconfig
- Imports use `.ts` extensions; `allowImportingTsExtensions: true` for non-bundled workspaces
- `verbatimModuleSyntax: true`

## Testing

- `node:test` for fast unit tests — preferred starting point for all non-UI code
- Node.js native type-stripping runs `.ts` tests directly — no tsx, ts-node, or esbuild needed
- Assume modern Node.js (≥22.18); `--experimental-strip-types` is not needed
- Invoke via `node --test` with a glob, e.g. `node --test src/**/*.test.ts`

## Code Style

- Always use block syntax (`{}`) for `if`/`else`/`for`/`while` — no braceless one-liners. Adding or removing statements in braceless blocks requires restructuring; braces keep diffs minimal and refactoring fast.
- Prefer syntax that minimises diff noise on future edits: trailing commas, multi-line parameter lists when >2 params.
