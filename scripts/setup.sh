#!/usr/bin/env bash
set -euo pipefail

# テンプレートリポジトリの場所（CLAUDE_RULES_DIR で上書き可）
RULES_DIR="${CLAUDE_RULES_DIR:-$HOME/claude-rules}"
TARGET_DIR="$(pwd)/.claude"
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --force|-f) FORCE=true ;;
    --help|-h)
      echo "使い方: setup.sh [--force]"
      echo "  $RULES_DIR/.claude/ をカレントディレクトリの .claude/ にコピーします。"
      echo "  CLAUDE.md はカレントディレクトリの内容を解析して自動生成します。"
      echo "  --force  既存ファイルを上書きします。"
      exit 0
      ;;
  esac
done

# コピー元 .claude/ の存在確認
SRC_CLAUDE="$RULES_DIR/.claude"
if [[ ! -d "$SRC_CLAUDE" ]]; then
  echo "エラー: $SRC_CLAUDE が存在しません"
  echo "  CLAUDE_RULES_DIR を設定するか、$HOME/claude-rules を用意してください。"
  exit 1
fi

echo "コピー元 : $SRC_CLAUDE"
echo "コピー先 : $TARGET_DIR"
echo ""

# ---------------- プロジェクト情報の自動検出 ----------------

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

# .claude/ 全体を rsync 的にコピー（plans/ は除外、フックは実行権限維持）
mkdir -p "$TARGET_DIR/plans/completed"

copy_file() {
  local src="$1" dst="$2"
  if [[ -e "$dst" && "$FORCE" == false ]]; then
    echo "  skip  (既存) ${dst#$(pwd)/}  — 上書きするには --force"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "  copy  ${dst#$(pwd)/}"
  fi
}

# .claude/ 配下を辿ってコピー（plans/ は除外）
while IFS= read -r src; do
  rel="${src#$SRC_CLAUDE/}"
  [[ "$rel" == plans/* || "$rel" == plans ]] && continue
  dst="$TARGET_DIR/$rel"
  copy_file "$src" "$dst"
done < <(find "$SRC_CLAUDE" -type f)

# フックスクリプトに実行権限
find "$TARGET_DIR/hooks" -type f -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true

# CLAUDE.md — 検出値を埋めて生成
CLAUDE_MD_SRC="$RULES_DIR/CLAUDE.md"
CLAUDE_MD_DST="$(pwd)/CLAUDE.md"
if [[ -f "$CLAUDE_MD_SRC" ]]; then
  if [[ -e "$CLAUDE_MD_DST" && "$FORCE" == false ]]; then
    echo "  skip  (既存) CLAUDE.md  — 上書きするには --force"
  else
    project_name=$(detect_project_name)
    project_description=$(detect_description)
    stack=$(detect_stack)
    top_dirs=$(detect_top_dirs)
    run_commands=$(detect_run_commands)

    template=$(<"$CLAUDE_MD_SRC")
    template="${template//\{\{PROJECT_NAME\}\}/$project_name}"
    template="${template//\{\{PROJECT_DESCRIPTION\}\}/$project_description}"
    template="${template//\{\{STACK\}\}/$stack}"
    template="${template//\{\{TOP_DIRS\}\}/$top_dirs}"
    template="${template//\{\{RUN_COMMANDS\}\}/$run_commands}"

    printf '%s\n' "$template" > "$CLAUDE_MD_DST"
    echo "  gen   CLAUDE.md  (project: $project_name, stack: $stack)"
  fi
fi

echo ""
echo "完了。CLAUDE.md の「重要な前提知識」と「プロジェクト概要」を必要に応じて編集してください。"
