#!/usr/bin/env bash
set -euo pipefail

usage() {
  local cmd="${0#./}"
  cat <<EOF
Usage:
  ${cmd} [--main-only]
  ${cmd} --branch <branch> [--base <ref>] [--push]

What it does:
  1. Fetch origin and upstream.
  2. Fast-forward local main to upstream/main.
  3. Push main to origin.
  4. Optionally rebase a patch branch onto a base ref.

Defaults:
  - If run from a non-main branch, that branch is rebased by default.
  - The default rebase base is main.
  - Use --push to push the rebased branch with --force-with-lease.

Examples:
  ${cmd} --main-only
  ${cmd} --branch codex/fork-tooling --base main --push
  ${cmd} --branch codex/work/thread-id-isolation --base main --push
EOF
}

die() {
  echo "fork-sync: $*" >&2
  exit 1
}

branch=""
base_ref="main"
push_branch=0
main_only=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch|-b)
      [[ $# -ge 2 ]] || die "--branch requires a value"
      branch="$2"
      shift 2
      ;;
    --base)
      [[ $# -ge 2 ]] || die "--base requires a value"
      base_ref="$2"
      shift 2
      ;;
    --push)
      push_branch=1
      shift
      ;;
    --main-only)
      main_only=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

git remote get-url origin >/dev/null 2>&1 || die "missing origin remote"
git remote get-url upstream >/dev/null 2>&1 || die "missing upstream remote"

if ! git diff --quiet || ! git diff --cached --quiet; then
  die "working tree is dirty; commit, stash, or discard local changes before syncing"
fi

current_branch="$(git branch --show-current)"
[[ -n "$current_branch" ]] || die "detached HEAD is not supported"

if [[ "$main_only" -eq 0 && -z "$branch" && "$current_branch" != "main" ]]; then
  branch="$current_branch"
fi

echo "==> Fetching remotes"
git fetch upstream --prune
git fetch origin --prune

echo "==> Syncing main from upstream/main"
git switch main
git merge --ff-only upstream/main
git push origin main

if [[ "$main_only" -eq 1 || -z "$branch" || "$branch" == "main" ]]; then
  if [[ "$current_branch" != "main" && "$main_only" -eq 1 ]]; then
    git switch "$current_branch"
  fi
  echo "==> Done"
  exit 0
fi

if ! git show-ref --verify --quiet "refs/heads/$branch"; then
  if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    git switch -c "$branch" --track "origin/$branch"
  else
    die "branch not found locally or on origin: $branch"
  fi
else
  git switch "$branch"
fi

echo "==> Rebasing $branch onto $base_ref"
git rebase "$base_ref"

if [[ "$push_branch" -eq 1 ]]; then
  echo "==> Pushing $branch with --force-with-lease"
  git push --force-with-lease -u origin "$branch"
fi

echo "==> Done"
