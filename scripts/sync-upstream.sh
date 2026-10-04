#!/bin/sh
# Track serenhope/9router updates in this fork without losing local commits.
#
# Usage:
#   sh scripts/sync-upstream.sh            # preview: fetch + report what would land
#   sh scripts/sync-upstream.sh --apply    # rebase onto upstream/master and push
#
# Why rebase and not merge: a rebase keeps this fork's own commits as a clean
# stack on top of upstream, so every update is a fast-forward-shaped diff.
# Merging instead leaves a growing pile of merge commits that make the next
# conflict harder to read. `--force-with-lease` on the push means the remote is
# never overwritten if it moved while the rebase was running.
#
# If the rebase stops on a conflict: fix the files, `git add .`, then
# `git rebase --continue`. To abandon: `git rebase --abort`.
# Keep local edits in their own commits, separate from anything else — mixed
# commits turn every future conflict into a hand-resolve.
set -eu

REPO_ROOT=$(git rev-parse --show-toplevel)
UPSTREAM=${UPSTREAM:-upstream}
BRANCH=${BRANCH:-$(git rev-parse --abbrev-ref HEAD)}
REMOTE=${REMOTE:-origin}
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

cd "$REPO_ROOT"

if ! git remote get-url "$UPSTREAM" >/dev/null 2>&1; then
  echo "error: remote '$UPSTREAM' not configured. Add it with:"
  echo "  git remote add $UPSTREAM https://github.com/serenhope/9router.git"
  exit 1
fi

echo "==> fetching $UPSTREAM"
git fetch "$UPSTREAM" --prune

LOCAL_ONLY=$(git rev-list --count "$UPSTREAM/master..HEAD")
INCOMING=$(git rev-list --count "HEAD..$UPSTREAM/master")

echo
echo "branch:  $BRANCH"
echo "local-only commits: $LOCAL_ONLY"
echo "incoming commits:   $INCOMING"
echo

if [ "$INCOMING" -eq 0 ]; then
  echo "Already up to date with $UPSTREAM/master."
  exit 0
fi

echo "--- incoming ($INCOMING) ---"
git log --oneline --no-merges "HEAD..$UPSTREAM/master"
echo "--- local only ($LOCAL_ONLY) ---"
git log --oneline --no-merges "$UPSTREAM/master..HEAD" || true
echo

if [ "$LOCAL_ONLY" -eq 0 ]; then
  echo "No local commits diverge — this will be a clean fast-forward."
else
  echo "Local commits exist on top of upstream: expect a rebase (not a fast-forward)."
  echo "Keep local edits in their own dedicated commits to minimize conflicts."
fi
echo

if [ "$APPLY" -eq 0 ]; then
  echo "Preview only. Re-run with --apply to rebase and push."
  exit 0
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "error: working tree is dirty. Commit or stash first, then re-run."
  git status --short
  exit 1
fi

if [ "$LOCAL_ONLY" -eq 0 ]; then
  echo "==> fast-forwarding $BRANCH to $UPSTREAM/master"
  git merge --ff-only "$UPSTREAM/master"
else
  echo "==> rebasing $BRANCH onto $UPSTREAM/master"
  git rebase "$UPSTREAM/master"
fi

echo "==> pushing to $REMOTE/$BRANCH (--force-with-lease)"
git push --force-with-lease "$REMOTE" "$BRANCH"

echo
echo "Done. Railway auto-deploys on push to the watched branch."
echo "Rebuild locally first if you want to be sure:"
echo "  npm install && npm run build"
