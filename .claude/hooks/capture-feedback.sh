#!/usr/bin/env bash
# UserPromptSubmit hook: ユーザーの訂正発言を ~/.claude/feedback/log.jsonl に記録し、Claude に再発防止を促す。
# 記録は /retro スキルがルールへ昇格させる。

set -u

INPUT=$(cat)
PROMPT=$(jq -r '.prompt // empty' <<<"$INPUT" 2>/dev/null)
[[ -z "$PROMPT" ]] && exit 0

PATTERN='違う|ちがう|やめて|そうじゃな|守れて|間違|勝手に|言ったよね|聞いてない|余計|求めてない'
grep -qE "$PATTERN" <<<"$PROMPT" || exit 0

LOG_DIR="$HOME/.claude/feedback"
mkdir -p "$LOG_DIR"
jq -c --arg ts "$(date -u +%FT%TZ)" \
  '{ts: $ts, source: "user", cwd, session_id, transcript_path, prompt}' \
  <<<"$INPUT" >>"$LOG_DIR/log.jsonl"

echo "[feedback-capture] この発言はユーザーの訂正の可能性がある。直前の自分の行動がどのルール・期待に反したかを特定して対応すること。再発し得るなら memory に feedback として保存すること。"
exit 0
