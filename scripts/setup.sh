#!/usr/bin/env bash
set -euo pipefail

RULES_DIR="${CLAUDE_RULES_DIR:-$HOME/claude-rules}"
TARGET_DIR="$(pwd)/.claude"
FORCE=false

# 引数パース
for arg in "$@"; do
  case "$arg" in
    --force|-f) FORCE=true ;;
    --help|-h)
      echo "使い方: setup.sh [--force]"
      echo "  $RULES_DIR から Claude Code 用ファイルをカレントディレクトリの .claude/ にコピーします。"
      echo "  CLAUDE.md はカレントディレクトリの内容を解析して自動で埋めます。"
      echo "  --force  既存ファイルを上書きします。"
      exit 0
      ;;
  esac
done

# コピー元の存在確認
if [[ ! -d "$RULES_DIR" ]]; then
  echo "エラー: コピー元ディレクトリが存在しません: $RULES_DIR"
  echo "  CLAUDE_RULES_DIR を設定するか、$HOME/claude-rules を用意してください。"
  exit 1
fi

echo "コピー元 : $RULES_DIR"
echo "コピー先 : $TARGET_DIR"
echo ""

mkdir -p "$TARGET_DIR/commands" "$TARGET_DIR/rules" "$TARGET_DIR/hooks" "$TARGET_DIR/plans/completed"

# ---------------- プロジェクト情報の自動検出 ----------------

# package.json などから値を抽出する素朴な JSON 抜き出し
extract_json_string() {
  local file="$1" key="$2"
  grep -m1 "\"$key\"[[:space:]]*:" "$file" 2>/dev/null \
    | sed -E "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/"
}

detect_project_name() {
  local name
  if [[ -f package.json ]]; then
    name=$(extract_json_string package.json name)
    [[ -n "$name" ]] && { echo "$name"; return; }
  fi
  if [[ -f pyproject.toml ]]; then
    name=$(grep -m1 -E '^name[[:space:]]*=' pyproject.toml 2>/dev/null \
      | sed -E 's/^name[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/')
    [[ -n "$name" ]] && { echo "$name"; return; }
  fi
  if [[ -f Cargo.toml ]]; then
    name=$(grep -m1 -E '^name[[:space:]]*=' Cargo.toml 2>/dev/null \
      | sed -E 's/^name[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/')
    [[ -n "$name" ]] && { echo "$name"; return; }
  fi
  basename "$(pwd)"
}

detect_description() {
  local desc
  if [[ -f package.json ]]; then
    desc=$(extract_json_string package.json description)
    [[ -n "$desc" ]] && { echo "$desc"; return; }
  fi
  if [[ -f pyproject.toml ]]; then
    desc=$(grep -m1 -E '^description[[:space:]]*=' pyproject.toml 2>/dev/null \
      | sed -E 's/^description[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/')
    [[ -n "$desc" ]] && { echo "$desc"; return; }
  fi
  echo "TODO: プロジェクトの目的・ドメインを1〜3行で記述"
}

detect_stack() {
  local stacks=()
  [[ -f package.json ]]                                  && stacks+=("Node.js")
  [[ -f pyproject.toml || -f requirements.txt || -f setup.py ]] && stacks+=("Python")
  [[ -f go.mod ]]                                        && stacks+=("Go")
  [[ -f Cargo.toml ]]                                    && stacks+=("Rust")
  [[ -f Gemfile ]]                                       && stacks+=("Ruby")
  [[ -f composer.json ]]                                 && stacks+=("PHP")
  [[ -f deno.json || -f deno.jsonc ]]                    && stacks+=("Deno")
  [[ -f bun.lockb || -f bun.lock ]]                      && stacks+=("Bun")
  [[ -f Dockerfile ]]                                    && stacks+=("Docker")
  if [[ ${#stacks[@]} -eq 0 ]]; then
    echo "(未検出 — 手動で記入してください)"
  else
    local IFS=", "
    echo "${stacks[*]}"
  fi
}

detect_top_dirs() {
  local dirs
  dirs=$(find . -maxdepth 1 -type d \
    -not -path . \
    -not -name '.git' \
    -not -name '.claude' \
    -not -name 'node_modules' \
    -not -name '.venv' -not -name 'venv' \
    -not -name 'dist' -not -name 'build' \
    -not -name 'target' \
    -not -name '__pycache__' \
    -not -name '.next' -not -name '.turbo' \
    2>/dev/null | sed 's|^\./|  - `|' | sed 's|$|/`|' | sort)
  if [[ -z "$dirs" ]]; then
    echo "  - (検出なし)"
  else
    echo "$dirs"
  fi
}

detect_run_commands() {
  # package.json scripts（"scripts" ブロック内のキー/値だけを抜く）
  if [[ -f package.json ]]; then
    local scripts
    scripts=$(awk '
      /"scripts"[[:space:]]*:[[:space:]]*\{/ { in_scripts=1; next }
      in_scripts && /^[[:space:]]*\}/        { in_scripts=0 }
      in_scripts                              { print }
    ' package.json 2>/dev/null \
      | grep -E '"[a-zA-Z0-9_:-]+"[[:space:]]*:[[:space:]]*"' \
      | sed -E 's/^[[:space:]]*"([a-zA-Z0-9_:-]+)"[[:space:]]*:[[:space:]]*"([^"]*)".*/  - `npm run \1` — \2/' \
      | head -8)
    if [[ -n "$scripts" ]]; then
      printf '```\n%s\n```' "$scripts"
      return
    fi
  fi
  # Makefile targets
  if [[ -f Makefile ]]; then
    local targets
    targets=$(grep -E '^[a-zA-Z_-]+:' Makefile 2>/dev/null \
      | grep -v '^\.PHONY' \
      | head -8 \
      | sed -E 's/^([a-zA-Z_-]+):.*/  - `make \1`/')
    if [[ -n "$targets" ]]; then
      printf '```\n%s\n```' "$targets"
      return
    fi
  fi
  printf '```bash\n# 起動・テスト・ビルドコマンドをここに記述\n```'
}

# ---------------- コピー処理 ----------------

copy_file() {
  local src="$1" dst="$2"
  if [[ -e "$dst" && "$FORCE" == false ]]; then
    echo "  skip  (既存) $(basename "$dst")  — 上書きするには --force"
  else
    cp "$src" "$dst"
    echo "  copy  $dst"
  fi
}

# settings.json
[[ -f "$RULES_DIR/settings.json" ]] && copy_file "$RULES_DIR/settings.json" "$TARGET_DIR/settings.json"

# commands/
if [[ -d "$RULES_DIR/commands" ]]; then
  for f in "$RULES_DIR/commands/"*.md; do
    [[ -e "$f" ]] || continue
    copy_file "$f" "$TARGET_DIR/commands/$(basename "$f")"
  done
fi

# rules/
if [[ -d "$RULES_DIR/rules" ]]; then
  for f in "$RULES_DIR/rules/"*.md; do
    [[ -e "$f" ]] || continue
    copy_file "$f" "$TARGET_DIR/rules/$(basename "$f")"
  done
fi

# hooks/ — フックスクリプトは実行権限を付けてコピー
if [[ -d "$RULES_DIR/hooks" ]]; then
  for f in "$RULES_DIR/hooks/"*.sh; do
    [[ -e "$f" ]] || continue
    dst="$TARGET_DIR/hooks/$(basename "$f")"
    copy_file "$f" "$dst"
    [[ -f "$dst" ]] && chmod +x "$dst"
  done
fi

# CLAUDE.md — 検出値を埋めてから書き出す
CLAUDE_MD_DST="$(pwd)/CLAUDE.md"
if [[ -f "$RULES_DIR/CLAUDE.md" ]]; then
  if [[ -e "$CLAUDE_MD_DST" && "$FORCE" == false ]]; then
    echo "  skip  (既存) CLAUDE.md  — 上書きするには --force"
  else
    project_name=$(detect_project_name)
    project_description=$(detect_description)
    stack=$(detect_stack)
    top_dirs=$(detect_top_dirs)
    run_commands=$(detect_run_commands)

    template=$(<"$RULES_DIR/CLAUDE.md")
    template="${template//\{\{PROJECT_NAME\}\}/$project_name}"
    template="${template//\{\{PROJECT_DESCRIPTION\}\}/$project_description}"
    template="${template//\{\{STACK\}\}/$stack}"
    template="${template//\{\{TOP_DIRS\}\}/$top_dirs}"
    template="${template//\{\{RUN_COMMANDS\}\}/$run_commands}"

    printf '%s\n' "$template" > "$CLAUDE_MD_DST"
    echo "  gen   $CLAUDE_MD_DST  (project: $project_name, stack: $stack)"
  fi
fi

echo ""
echo "完了。CLAUDE.md の「重要な前提知識」と「プロジェクト概要」を必要に応じて編集してください。"
