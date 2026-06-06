#!/usr/bin/env bash
# PostToolUse hook: ファイル拡張子に応じてフォーマッタを実行する。
# Claude Code から stdin で受け取る JSON のうち tool_input.file_path を対象にする。
# フォーマッタが未インストールなら静かにスキップ（CI 落ちで止めない）。

set -u

# stdin から tool 情報を読む（Claude Code は JSON を流す）
INPUT=$(cat)

# file_path を抽出（jq があれば優先、無ければ grep+sed）
extract_file_path() {
  if command -v jq >/dev/null 2>&1; then
    echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null
  else
    echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
      | head -1 | sed -E 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/'
  fi
}

FILE=$(extract_file_path)

# 対象ファイルが無ければ何もしない
[[ -z "$FILE" || ! -f "$FILE" ]] && exit 0

# プロジェクトローカルの bin を優先（monorepo/プロジェクト依存のフォーマッタ）
run() {
  if command -v "$1" >/dev/null 2>&1; then
    "$@" >/dev/null 2>&1 || true
    return 0
  fi
  return 1
}

case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.md|*.css|*.scss|*.html|*.yml|*.yaml)
    # プロジェクトに prettier があれば優先
    if [[ -x "./node_modules/.bin/prettier" ]]; then
      ./node_modules/.bin/prettier --write --log-level=silent "$FILE" 2>/dev/null || true
    elif command -v npx >/dev/null 2>&1 && [[ -f package.json ]]; then
      npx --no-install prettier --write --log-level=silent "$FILE" 2>/dev/null || true
    else
      run prettier --write --log-level=silent "$FILE"
    fi
    ;;
  *.py)
    run ruff format "$FILE" || run black --quiet "$FILE"
    ;;
  *.go)
    run gofmt -w "$FILE"
    ;;
  *.rs)
    run rustfmt --quiet "$FILE"
    ;;
  *.rb)
    run rubocop -A --no-color "$FILE"
    ;;
  *.sh)
    run shfmt -w "$FILE"
    ;;
  *.tf)
    run terraform fmt "$FILE"
    ;;
esac

exit 0
