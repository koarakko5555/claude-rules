---
name: init
description: コードベースを解析して CLAUDE.md を初期化する
allowed-tools:
  - Bash
  - Read
  - Edit
---

実際のコードベースを読んで、それを反映した CLAUDE.md を生成してください。

手順:
1. `find . -maxdepth 3 -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*'` でディレクトリ構成を把握。
2. `package.json` / `pyproject.toml` / `go.mod` / `Cargo.toml` などから技術スタックを特定。
3. メインのエントリポイントと主要ディレクトリを特定。
4. 既存の CLAUDE.md があれば読み込む。
5. CLAUDE.md を更新: **プロジェクト概要** / **アーキテクチャ** / **実行方法** セクションを埋める。既存の記述で明らかに古くないものは保持する。

コードから確認できない情報を勝手に推測して書かないこと。
