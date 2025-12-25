#!/usr/bin/env bash
set -euo pipefail

BRANCH="${1:?branch required}"       # e.g. Lede
LIST_FILE="${2:?list file required}" # e.g. sources/Lede.list

# Copy list to /tmp first (avoid missing after checkout target branch)
TMP_LIST="/tmp/${BRANCH}.list"
cp "$LIST_FILE" "$TMP_LIST"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" || true' EXIT

echo "==> Sync branch: $BRANCH from $LIST_FILE"
echo "==> Using tmp list: $TMP_LIST"

git fetch origin --prune

# Checkout existing branch or create orphan
if git show-ref --verify --quiet "refs/remotes/origin/${BRANCH}"; then
  git checkout -B "$BRANCH" "origin/${BRANCH}"
else
  git checkout --orphan "$BRANCH"
fi

# Clean worktree (keep .git)
find . -mindepth 1 -maxdepth 1 ! -name ".git" -exec rm -rf {} + || true

while IFS= read -r line; do
  # trim leading spaces
  line="${line#"${line%%[![:space:]]*}"}"
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^# ]] && continue
  [[ "$line" =~ ^https?:// ]] || { echo "     (skip invalid line) $line"; continue; }

  url="$(echo "$line" | awk '{print $1}')"
  ref="$(echo "$line" | awk '{print $2}')"
  subdirs="$(echo "$line" | cut -d' ' -f3-)"
  name="$(basename "$url" .git)"

  # default: if subdirs empty, sync repo root
  if [[ -z "${subdirs// }" ]]; then
    subdirs="."
  fi

  echo "  -> $name ($ref): $subdirs"

  repo_dir="$TMP/$name"
  rm -rf "$repo_dir"

  # clone with retry
  cloned=false
  for t in 1 2 3; do
    if git clone --depth 1 -b "$ref" "$url" "$repo_dir" >/dev/null 2>&1; then
      cloned=true
      break
    fi
    echo "     (clone retry $t/3) $name ..."
    rm -rf "$repo_dir"
    sleep $((t*t + 2))
  done
  $cloned || { echo "     (skip repo) clone failed: $url#$ref"; continue; }

  for d in $subdirs; do
    if [[ "$d" == "." ]]; then
      # sync entire repo root into ./<repo_name>
      target="$name"
      mkdir -p "./$target"
      rsync -a --delete --exclude ".git" "$repo_dir/" "./$target/"
    elif [[ -e "$repo_dir/$d" ]]; then
      rsync -a --delete --exclude ".git" "$repo_dir/$d/" "./$d/"
    else
      echo "     (skip missing) $d"
    fi
  done
done < "$TMP_LIST"

mkdir -p relevance
date -u +"last_sync_utc=%Y-%m-%dT%H:%M:%SZ" > relevance/last_sync.txt

git add -A
if git diff --cached --quiet; then
  echo "==> No changes for $BRANCH"
else
  git commit -m "sync: $BRANCH ($(date -u +%F))"
fi

ok=false
for i in 1 2 3 4 5; do
  echo "==> push try $i/5"
  if git push -f origin "$BRANCH"; then
    ok=true
    break
  fi
  sleep $((i*i + 2))
done

$ok || (echo "::error ::push failed for $BRANCH" && exit 1)

# back to main
git checkout main || true