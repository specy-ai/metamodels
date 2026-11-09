# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

The core of Specy: the five languages (`.prd`, `.sysreq`, `.domain`, `.arch`, `.synth`), their metamodels in prose, their EBNF grammars, the JSON Schemas of their JSON/YAML forms, the Langium parsers with the `specy` CLI and LSP server, the tree-sitter grammars, the metamodel diagrams and the example corpus. The other Specy repositories build on it as a sibling checkout: `skills` (the Claude Code plugin), `app` (the navigator), `website` (specy.ai) and `synthy` (synthetic data) all expect this repository at `../metamodels` unless `SPECY_METAMODELS` says otherwise. No skill, app or site code lives here.

## Build Commands

```bash
./build.sh                             # every component whose tooling is present: langium, tree-sitters, diagrams
./build.sh langium                     # one component

# Build the Langium parsers + the specy CLI, validate every example, run the round-trip tests, bundle for the browser
./src/langium/specy-domain/build.sh    # requires: node 20+ and npm

# Convert / validate any model in any encoding (builds the CLI on first use)
./specy.sh convert examples/ecommerce/v2/orders.domain --to markdown
./specy.sh validate examples/url-shortener/url-shortener.prd

# Build tree-sitter parsers + run smoke tests against examples/
./src/tree-sitters/build.sh            # requires: tree-sitter CLI
./src/tree-sitters/sync-nvim.sh        # register the parsers in Neovim (see TREE-SITTER.md)

# Regenerate the generated metamodel diagrams (repo root specy-*-metamodel.svg, EA-metamodel.svg)
./src/diagrams/build.sh                # requires: python3 + network on first run (fonts, fontTools)
```

## Source of Truth

- **Grammars**: `src/grammars/*.ebnf` are the canonical grammars (`domain.ebnf`, `architecture.ebnf`, `prd.ebnf`, `sysreq.ebnf`, `data-operation.ebnf`, `synth.ebnf`). The tree-sitter grammars under `src/tree-sitters/` and the Langium grammars under `src/langium/specy-domain/src/language/` are faithful translations and must be updated with them. The `skills` repo copies the EBNF files into the skills that need them at build time.
- **Metamodels**: `src/metamodels/*.md` document each layer's concepts and constraints (`DOMAIN-METAMODEL.md` for the v3 domain model, `SOFTWARE-ARCHITECTURE-METAMODEL.md` for `.arch`, incl. its level 0, `SYNTH-METAMODEL.md` for `.synth` scenarios written against a `.domain`, `PRODUCT-REQ-METAMODEL.md`, `SYSTEM-REQ-METAMODEL.md`, `DATA-OPERATION-METAMODEL.md`, the draft `ENTERPRISE-ARCHITECTURE-METAMODEL.md`). They are published verbatim on specy.ai (`website/scripts/sync-metamodels.sh`), so their heading texts are stable anchors: add headings, do not rename them.
- **Schemas**: `src/schemas/*.schema.json` are the JSON Schemas of the five model documents stored as JSON or YAML (`domain-model`, `prd`, `sysreq`, `architecture`, `synth-scenario`); each `$id` (`https://specy.ai/schemas/<name>/1.json`) carries the format's major version and the website serves them there (`website/scripts/sync-schemas.sh`). `synth-scenario.schema.json` describes a `.synth` scenario as a document; synthy vendors a copy (`npm run sync:fixtures` there) and its `test/schema.test.ts` pins the loader and the schema together, so change the schema, the normalizer (`src/langium/specy-domain/src/cli/synth-model.ts`) and synthy's loader together. A rate's predicate is written in one spelling by both tools (`ratePredicate` in synth-model.ts, `renderPredicate` in synthy's `src/scenario/predicate.ts`): keep them equal. The schemas are embedded into the Langium package by `scripts/embed-schemas.mjs` (`npm run schemas`, run by the build and before the tests).
- **Model formats**: `src/metamodels/MODEL-FORMATS.md` is the contract of the four encodings of every model (DSL, JSON, YAML, Markdown) and of the Markdown conventions each language's reader understands and writer produces. The converters live in `src/langium/specy-domain/src/formats/` (one codec per language on a shared kit; see its README.md), behind the `specy` CLI (`specy convert`, `specy validate`; root wrapper `./specy.sh`) and the browser bundle. Reading JSON, YAML or Markdown always ends in the Langium parser (the Markdown reader transpiles to DSL), so there is one set of semantics. `test/formats.test.ts` round-trips every example file through the three other encodings and must stay green; `jsonDiff` in it names what differs. The JSON of `.domain` and `.synth` is consumed by synthy: additive changes only, with a `PARSER_VERSION` bump (`src/cli/version.ts`).
- **Examples**: `examples/` contains complete Specy projects (business-loan, url-shortener, ride-now, ecommerce, retail-media, conformance) used as documentation, as the acceptance corpus of every parser build and as fixtures by the other repos (`skills` copies `examples/ecommerce/v2/orders.*` into the synth-design skill; synthy regenerates its parsed fixtures from every `.domain` here). Examples are fictional: no client names, no people, no e-mail addresses.

## Langium Parsers

Five Langium grammars in `src/langium/specy-domain/src/language/` (`specy-domain`, `specy-synth`, `specy-prd`, `specy-sysreq`, `specy-architecture`) on one shared service set (`specy-module.ts`), so a `.synth` resolves into its `.domain`. The new grammars import the domain grammar for the shared terminals and prefix their rules (`Prd…`, `Req…`, `Arch…`): the five generate one `src/generated/ast.ts`. A grammar change goes with the EBNF in `src/grammars/` and the tree-sitter grammar; `npm run langium:generate` then `npx tsc`; every example must validate (`./specy.sh validate <file>`) and the round-trip tests must pass. `npm run build:browser` writes `out/browser/specy-domain-langium.js` (IIFE, `window.SpecyDomainLangium`), which the `app` repo vendors.

## Tree-Sitter Parsers

Five parsers in `src/tree-sitters/`: specy-domain, specy-prd, specy-sysreq, specy-architecture, specy-synth. `src/tree-sitters/build.sh` generates, builds, and smoke-tests them against files in `examples/`. `src/tree-sitters/sync-nvim.sh` registers them in Neovim (see `TREE-SITTER.md`); re-run it when a parser is added.

## Metamodel Diagrams

`specy-DDD-metamodel.svg` is hand-built. `specy-PRD-metamodel.svg`, `specy-SysReq-metamodel.svg`, `specy-Arch-metamodel.svg`, `specy-DataOp-metamodel.svg` and `EA-metamodel.svg` are generated by `src/diagrams/build.sh` from declarative specs (`src/diagrams/prd_metamodel.py`, `sysreq_metamodel.py`, `arch_metamodel.py`, `dataop_metamodel.py`, `ea_metamodel.py`) rendered by `metamodel_diagram.py` in the DDD diagram's style; every node carries a `data-anchor` naming the heading of the matching metamodel section (used by the specy.ai site to make nodes clickable). Edit the specs, not the SVGs. The website syncs the SVGs from this repo root.

## Specy v3 Domain DSL

The current domain DSL (v3) uses a hierarchical structure:
```
organization > context (with context map) > module > entities/aggregates/values/...
```

Key v3 constructs: entity (with `identity`, `duplicate detection`, `states { machine }`), aggregate, value, command, query, event, external/error/temporal events, three service types (domain/application/infrastructure), reaction (reactive rule: `triggered-by` event / `effects` command), invariant (with enforcement), precondition/postcondition on operations, agreement/reconciliation, interface.

A context map entry is written by a context about itself: inside `X`, `downstream Y : ACL` means X is downstream of Y and protects itself with an ACL.

## Specy Software Architecture DSL (`.arch`)

A `.arch` file has one of two roots:
```
architecture  > system (one, in focus) > container > component     // C4 levels 1–3, Thrift-typed contracts, ports, connectors, channels, deployment
organization  > area / phase / person / externalSystem / system / dependency > flow   // level 0: the system landscape
```

Level 0: a `system` states its purpose (`::`), product (`technology`), `area`, `used-by`, the concepts it `masters` (source of truth) and `handles`, and its `hotspot`s. `dependency A -> B` reads "A depends on B" — the direction of the need, not of the call — with context-map patterns (`CS | Conformist | ACL` downstream, `OHS` upstream, `SharedKernel | PublishedLanguage | Partnership` both; `Partnership` is written on both dependencies of a mutual pair) and a `criticality`. A `flow` carries numbered domain concepts (`carries X as Y`, `to` when data goes to the upstream side) with a mechanism `over "…" manual | automated`, once or per `phase`. Concept names resolve against the `domain-source`(s) (`Context.Concept` when ambiguous; `// NOTE:` acknowledges a name with no domain element yet). The worked example is `examples/retail-media/`; the Specy app (`../app`) renders both roots.

## DSL Conventions

- Type names: `PascalCase`. Field names and enum values: `camelCase`
- Operation labels: string literals in business language, not identifiers
- Every definition may carry a `// source: path/to/file.ext` comment for traceability
- `// UNCLEAR:` — grammar genuinely cannot express the condition (business-critical)
- `// NOTE:` — infrastructure concern omitted or gap flagged; at `.arch` level 0 it also acknowledges a concept name that has no domain element yet

## Design Review Panels

- `CORE_TEAM.md` — 7-panellist review for language/grammar changes (Simplicity, DDD Fidelity, Readability, Machine Reasoning, Cross-File Coherence, Skill Experience, Provocateur); `/review <proposal>` applies it
- `VISION_TEAM.md` — the vision brainstorm panel; `/vision <question>` applies it and proposes updates to `VISION.md`
- `CONSTRUCT_CRITERIA.md` — the grid deciding whether a construct deserves a place in a language
- Both panels follow: Present → Respond → Rebut → Synthesise → Verdict

## Downstream Checks After a Change

- A grammar or metamodel change: rebuild the `skills` plugin (`../skills/src/skills/build.sh`, it copies from here) and commit its `dist/`.
- A schema or parser-output change: `npm run sync:fixtures` in `../synthy`, then its tests; `../website/scripts/sync-schemas.sh`.
- A metamodel prose or diagram change: `../website/scripts/sync-metamodels.sh`, then deploy the site.
- A browser-bundle change: copy `out/browser/specy-domain-langium.js` to `../app/vendor/`.
