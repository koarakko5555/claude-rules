# claude-rules

Claude Code 用のハーネステンプレート。プロジェクト共通の **開発ルール・スラッシュコマンド・フック** を一式まとめ、`scripts/setup.sh` で任意のリポジトリに展開する。

各プロジェクトで `.claude/` を一から書く代わりに、このテンプレートをコピーして上書き運用する。

## 何が入っているか

```
.
├── CLAUDE.md                  # セッション開始時に自動読込されるプロジェクト規約（テンプレート）
├── .claude/
│   ├── rules/                 # ドメイン固有の規約（CLAUDE.md から参照）
│   │   ├── coding.md          # コーディング規約（コメント方針・スコープ・セキュリティ）
│   │   └── git.md             # Git 規約（コミット・ブランチ・PR の切り方）
│   ├── commands/              # スラッシュコマンド定義
│   │   ├── commit.md          # /commit  変更をステージング・コミット（メッセージ自動生成）
│   │   ├── debug.md           # /debug   根本原因を特定して直す（対症療法を禁止）
│   │   ├── draft.md           # /draft   要件ヒアリング→計画→承認→実装→レビューの一気通貫
│   │   ├── init.md            # /init    コードベースを解析して CLAUDE.md を初期化
│   │   ├── refine.md          # /refine  会話を振り返り .claude/ の更新候補を提案
│   │   └── review.md          # /review  main からの差分をコードレビュー
│   ├── hooks/
│   │   ├── session-context.sh # SessionStart: 現在の git 状態をコンテキストに注入
│   │   └── format.sh          # PostToolUse: 編集ファイルを拡張子に応じて自動フォーマット
│   └── settings.json          # 権限（allow/deny）とフック配線
└── scripts/
    └── setup.sh               # テンプレートを対象リポジトリの .claude/ に展開
```

## 使い方

### 1. テンプレートを配置

このリポジトリを `~/claude-rules` に置く（場所を変える場合は `CLAUDE_RULES_DIR` で指定）。

```bash
git clone <this-repo> ~/claude-rules
```

### 2. 対象プロジェクトで展開

セットアップしたいリポジトリのルートで実行する。

```bash
cd /path/to/your-project
bash ~/claude-rules/scripts/setup.sh
```

- `~/claude-rules/.claude/` をカレントの `.claude/` にコピーする（`plans/` は除外、フックは実行権限を維持）。
- `CLAUDE.md` は **カレントのプロジェクトを解析して自動生成** する。`package.json` / `pyproject.toml` / `Cargo.toml` などからプロジェクト名・説明・スタック・主要ディレクトリ・実行コマンドを検出してテンプレートに埋め込む。
- 既存ファイルはデフォルトでスキップする。上書きするには `--force`。

```bash
# 既存の .claude/ や CLAUDE.md を上書き
bash ~/claude-rules/scripts/setup.sh --force

# テンプレートの場所を変えている場合
CLAUDE_RULES_DIR=/path/to/claude-rules bash /path/to/claude-rules/scripts/setup.sh
```

展開後、生成された `CLAUDE.md` の「プロジェクト概要」と「重要な前提知識」を必要に応じて手で埋める。

## 含まれる規約の要点

- **コーディング** (`.claude/rules/coding.md`): コメントは WHY のみ／スコープ厳守（ついでのリファクタ禁止）／後方互換シムを残さない／injection 系を作り込まない。
- **Git** (`.claude/rules/git.md`): 命令形コミット・件名 ≤72 文字／PR はできる限り細かく（1 PR = 1 論理変更、理想 ≤300 行）／main への force push 禁止／`git add -A` を避ける。

## フックの挙動

| フック | タイミング | 動作 |
| --- | --- | --- |
| `session-context.sh` | SessionStart | ブランチ・未コミット変更・直近コミット・upstream 差分・進行中の plan をコンテキストに注入 |
| `format.sh` | PostToolUse (Write/Edit) | 編集ファイルを拡張子に応じて prettier / ruff / gofmt / rustfmt などで自動整形（未インストールなら静かにスキップ） |

`settings.json` には読み取り系コマンドの allow リストと、`git push --force` / `sudo rm` などの deny リストを定義済み。

## カスタマイズ

ルール・コマンド・フックはすべてプレーンな Markdown / シェルスクリプト。プロジェクト固有の方針はこのテンプレート側を編集してから展開するか、展開後に各プロジェクトの `.claude/` を直接編集する。ユーザー個別設定は `.claude/settings.local.json`（gitignore 済み）に置く。