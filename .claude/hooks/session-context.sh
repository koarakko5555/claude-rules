#!/usr/bin/env bash
# SessionStart hook: 現在の git 状態を Claude のコンテキストに注入する。
# stdout に出力した内容はセッション開始時のシステム情報として読み込まれる。

set -u

# git リポジトリでなければ何もしない
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(detached)")
UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo "(none)")

echo "## Git Context (auto-injected at session start)"
echo ""
echo "- **Branch**: \`$BRANCH\` → upstream: \`$UPSTREAM\`"

# 未コミット変更のサマリ
MODIFIED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [[ "$MODIFIED" != "0" ]]; then
  echo "- **Uncommitted**: $MODIFIED files"
  echo ""
  echo "\`\`\`"
  git status --short 2>/dev/null | head -20
  if [[ "$MODIFIED" -gt 20 ]]; then
    echo "... and $((MODIFIED - 20)) more"
  fi
  echo "\`\`\`"
else
  echo "- **Uncommitted**: clean"
fi

# 直近5コミット
echo ""
echo "**Recent commits**:"
echo "\`\`\`"
git log --oneline -5 --color=never 2>/dev/null || echo "(no commits yet)"
echo "\`\`\`"

# upstream との差分（ahead/behind）
if [[ "$UPSTREAM" != "(none)" ]]; then
  AHEAD_BEHIND=$(git rev-list --left-right --count "@{u}...HEAD" 2>/dev/null || echo "")
  if [[ -n "$AHEAD_BEHIND" ]]; then
    BEHIND=$(echo "$AHEAD_BEHIND" | awk '{print $1}')
    AHEAD=$(echo "$AHEAD_BEHIND" | awk '{print $2}')
    if [[ "$AHEAD" != "0" || "$BEHIND" != "0" ]]; then
      echo ""
      echo "- **vs upstream**: ahead $AHEAD, behind $BEHIND"
    fi
  fi
fi

# 進行中の plan（.claude/plans/ 直下、completed/ は除外）
if [[ -d ".claude/plans" ]]; then
  ACTIVE_PLANS=$(find .claude/plans -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$ACTIVE_PLANS" != "0" ]]; then
    echo ""
    echo "- **Active plans**: $ACTIVE_PLANS in \`.claude/plans/\`"
    find .claude/plans -maxdepth 1 -name '*.md' -type f 2>/dev/null \
      | head -5 | sed 's|^|  - |'
  fi
fi

exit 0
