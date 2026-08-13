# Attribution & Licensing / 帰属とライセンス

This repository combines components under different open-source licenses. When built and
distributed **as firmware (a combined work)**, the whole is distributed under **GPL-3.0-or-later**
(this is the safe combination: Apache-2.0 is one-way compatible with GPL-3.0, and the NICOLA
engine's `GPL-2.0-or-later` may be used as GPL-3.0). Individual files retain their own licenses
as noted below.

このリポジトリは複数のライセンスの成果物を組み合わせています。**ファームとして結合・配布する
場合、全体は GPL-3.0-or-later** で配布されます（Apache-2.0 → GPL-3.0 は互換、NICOLAエンジンの
`GPL-2.0-or-later` は GPL-3.0 として利用可、という安全な組み合わせ）。各ファイルは下記の
個別ライセンスを保持します。

## Components / 構成要素

| Path | Source / Upstream | License |
|---|---|---|
| `modules/nicola/` | NICOLA (親指シフト) 同時打鍵判定エンジン。ロジックは **eswai** の `qmk_firmware .../nicola` を移植、モジュール構造は **eswai/zmk-naginata** に倣う | **GPL-2.0-or-later** (`modules/nicola/LICENSE`) |
| `boards/`, `config/` (keyboard/ZMK base), `Justfile`, `flake.*` | **hitsmaxft/zmk-keyboard-cornix** 由来の ZMK 設定・ボード定義 | Apache-2.0 (`LICENSE`) |
| `docs/reference/yamabuki-r/` | 親指シフトエミュレータ「やまぶきR」の配布物と解析。**参照(正本)であり本プロジェクトのコードではない** | 各配布物の権利者に帰属（再配布は同梱条件に従う） |
| `tools/`, `docs/` (本プロジェクト作成分) | このリポジトリ独自 | GPL-3.0-or-later |

west.yml で取り込む外部モジュール（`zmk`, `zmk-helpers`(urob), `zmk-rgbled-widget`,
`zmk-dongle-display`(englmaxi) 等）は、それぞれ各リポジトリのライセンスに従います。

## Credits / 謝辞

- **[hitsmaxft/zmk-keyboard-cornix](https://github.com/hitsmaxft/zmk-keyboard-cornix)** — Cornix の ZMK キーボード定義・ビルド構成の基盤。
- **[eswai](https://github.com/eswai)** — NICOLA 同時打鍵判定ロジック（qmk nicola）と zmk-naginata の behavior 方式。本プロジェクトの親指シフトエンジンの元。
- **やまぶきR** — 同時打鍵(%)判定仕様の正本として参照（`docs/reference/yamabuki-r/`）。

## Note on redistribution / 再配布の注意

`docs/reference/yamabuki-r/` の配布物（やまぶきR）や `firmware/stock/`・`rmkfw/` のベンダ
ファームは第三者の著作物です。公開・再配布の可否は各配布条件に従ってください。本プロジェクトの
オープンソース化にあたり、権利が不明瞭なものは公開前に除外・リンク参照へ切り替えることを推奨します。
