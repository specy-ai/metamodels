#!/usr/bin/env bash
# =============================================================================
# Root build orchestrator for the Specy metamodels.
#
# Builds every component of the repo by delegating to the per-component build
# scripts, then prints a one-line-per-component summary:
#
#   langium       src/langium/specy-domain/build.sh — generate+compile, validate every example,
#                                                     round-trip tests, browser bundle   [needs node + npm]
#   tree-sitters  src/tree-sitters/build.sh         — generate+build parsers, smoke-test [needs tree-sitter CLI]
#   diagrams      src/diagrams/build.sh             — regenerate the metamodel diagrams  [needs python3]
#
# Components whose required external tooling is missing are SKIPPED with a
# warning (not a failure). A component that runs but errors makes this script
# exit non-zero.
#
# Usage:
#   ./build.sh                         # build everything available
#   ./build.sh langium                 # build only the named component(s)
#   ./build.sh langium tree-sitters    # build a subset
#   ./build.sh -h | --help
# =============================================================================

set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; RESET='\033[0m'

ALL_COMPONENTS=(langium tree-sitters diagrams)

usage() {
  cat <<EOF
Specy metamodels build orchestrator.

Usage: ./build.sh [component...]

Components (default: all):
  langium        Generate + compile the Langium parsers, validate examples, test, bundle.  [needs node + npm]
  tree-sitters   Generate + build the tree-sitter parsers and run smoke tests.             [needs tree-sitter CLI]
  diagrams       Regenerate the generated metamodel diagrams at the repo root.             [needs python3]

Behavior:
  - A component whose required tool is missing is skipped with a warning.
  - A component that runs but fails makes this script exit non-zero.
EOF
}

# have <cmd...> — true only if every named command is on PATH
have() { for c in "$@"; do command -v "$c" >/dev/null 2>&1 || return 1; done; return 0; }

# Per-component results: STATUS_<component> is "OK" | "FAIL" | "SKIP", REASON_<component>
# says why it was skipped. Plain variables, not associative arrays, because macOS ships
# bash 3.2. Hyphens in component names become underscores.
set_result() { local v="${1//-/_}"; printf -v "STATUS_$v" '%s' "$2"; printf -v "REASON_$v" '%s' "${3:-}"; }
skip() { set_result "$1" SKIP "$2"; printf "${YELLOW}    skipped: %s${RESET}\n" "$2"; }

run_langium() {
  printf "${BOLD}==> langium${RESET}\n"
  if ! have node npm; then
    skip langium "node and/or npm not on PATH"
    return
  fi
  if "$ROOT/src/langium/specy-domain/build.sh"; then
    set_result langium OK
  else
    set_result langium FAIL
  fi
}

run_tree-sitters() {
  printf "${BOLD}==> tree-sitters${RESET}\n"
  if ! have tree-sitter; then
    skip tree-sitters "tree-sitter CLI not on PATH"
    return
  fi
  if "$ROOT/src/tree-sitters/build.sh"; then
    set_result tree-sitters OK
  else
    set_result tree-sitters FAIL
  fi
}

run_diagrams() {
  printf "${BOLD}==> diagrams${RESET}\n"
  if ! have python3; then
    skip diagrams "python3 not on PATH"
    return
  fi
  if "$ROOT/src/diagrams/build.sh"; then
    set_result diagrams OK
  else
    set_result diagrams FAIL
  fi
}

# --- parse args -------------------------------------------------------------
components=()
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    langium|tree-sitters|diagrams) components+=("$arg") ;;
    *) printf "${RED}Unknown component: %s${RESET}\n\n" "$arg" >&2; usage >&2; exit 2 ;;
  esac
done
[[ ${#components[@]} -eq 0 ]] && components=("${ALL_COMPONENTS[@]}")

# --- run --------------------------------------------------------------------
printf "${BOLD}Building Specy metamodels → %s${RESET}\n\n" "$ROOT"
for c in "${components[@]}"; do
  "run_$c"
  echo ""
done

# --- summary ----------------------------------------------------------------
printf "${BOLD}Summary${RESET}\n"
fail=0
for c in "${components[@]}"; do
  status="STATUS_${c//-/_}"; reason="REASON_${c//-/_}"
  case "${!status:-FAIL}" in
    OK)   printf "  ${GREEN}%-14s OK${RESET}\n" "$c" ;;
    SKIP) printf "  ${YELLOW}%-14s SKIPPED${RESET} (%s)\n" "$c" "${!reason:-}" ;;
    *)    printf "  ${RED}%-14s FAILED${RESET}\n" "$c"; fail=1 ;;
  esac
done

exit "$fail"
