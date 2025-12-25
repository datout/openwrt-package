#!/usr/bin/env bash
set -euo pipefail

BRANCH="${1:?branch required}"       # 例如：Lede
LIST_FILE="${2:?list file required}" # 例如：sources/Lede.list

# 关键：把 list 先拷贝到 /tmp，避免切到目标分支后 list 不见
TMP_LIST="/tmp/${BRANCH}.list"
cp "$LIST_FILE" "$TMP_LIST"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" || true' EXIT

echo "==> Sync branch: $BRANCH from $LIST_FILE"
echo "==> Using tmp list: $TMP_LIST"

git fetch origin --prune

# 目标分支：存在就切换；不存在就 orphan
if git show-ref --verify --quiet "refs/remotes/origin/${BRANCH}"; then
  git checkout -B "$BRANCH" "origin/${BRANCH}"
else
  git checkout --orphan "$BRANCH"
fi

# 清空（保留 .git）
find . -mindepth 1 -maxdepth 1 ! -name ".git" -exec rm -rf {} + || true

# 逐行读取（从 /tmp）
while IFS= read -r line; do
  # trim 左侧空白，避免 "  # comment" 这种被当成有效行
  line="${line#"${line%%[![:space:]]*}"}"
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^# ]] && continue
# 非 http 开头的行一律跳过（防止说明文字/乱行导致 git clone）
[[ "$line" =~ ^https?:// ]] || { echo "     (skip invalid line) $line"; continue; }

  url="$(echo "$line" | awk '{print $1}')"
  ref="$(echo "$line" | awk '{print $2}')"
  subdirs="$(echo "$line" | cut -d' ' -f3-)"
  name="$(basename "$url" .git)"

  echo "  -> $name ($ref): $subdirs"
  repo_dir="$TMP/$name"
  rm -rf "$repo_dir"

  git clone --depth 1 -b "$ref" "$url" "$repo_dir" >/dev/null

  for d in $subdirs; do
    if [[ -e "$repo_dir/$d" ]]; then
      rsync -a --delete --exclude ".git" "$repo_dir/$d" "./$d"
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

git checkout main || true
