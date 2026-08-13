# 02-現行キーマップのZMK移植

> 種別: Issue / 親: [01-環境構築フェーズ](00-readme.md)
> 依存: [01-ZMKフォークとActionsビルド](01-ZMKフォークとActionsビルド.md)

## 🎯 目的
現行の Vial キーマップ（[docs/keymap/README.md](../../keymap/README.md) に記録済み）を
ZMK の `.keymap` に移植し、日常使用できる状態にする。
**方針: まずNICOLA優先・最小限。** ベースレイヤー＋主要レイヤーを先に通し、
コンボ/マクロの完全再現は動いてから段階的に行う。

## 📋 移植対象（現行 → ZMK）

| 現行（Vial） | ZMK での実現 |
|--------------|--------------|
| レイヤー 0/1/2/7/9 | keymap の layer 定義 |
| TD(0) Space/MO(1), TD(2) Enter/MO(2), TD(3) かな/MO(9) | `hold-tap`（balanced / tap-preferred を実測で選ぶ） |
| コンボ11個（S+D→`(` 等） | `combos` ノード |
| マクロ11個（SQL入力・Win操作等） | `macros` ノード |
| USER00〜06（Cornix独自の無線制御） | ZMK標準 `&bt BT_SEL/BT_CLR` / `&out` に置換 |
| エンコーダ（音量/ホイール） | `sensor-bindings` |

## ✅ 作業項目
- [ ] ステップ1（最小）: レイヤー0/1/2 ＋ hold-tap 3個 ＋ エンコーダ
- [ ] ステップ2: レイヤー7/9、`&bt`/`&out` キー配置
- [ ] ステップ3（後回し可）: コンボ11個・マクロ11個
- [ ] 各ステップごとに Actions ビルド → 実機確認
- [ ] JIS記号（`LS(N8)`→`(` 等）の出力確認（OS側配列は JIS のまま）

## 🏁 完了条件
- ステップ1〜2 が実機で動き、日常入力に支障がない
- （ステップ3は別途完了させる。NICOLA実装を優先してよい）

## 🔗 参照
- 現行キーマップ記録: [docs/keymap/README.md](../../keymap/README.md) / 元ファイル: `docs/keymap/keymap-20260706-203100.vil`（カスタマイズ済・移植のマスター）
- ZMK keymap: https://zmk.dev/docs/keymaps / hold-tap: https://zmk.dev/docs/keymaps/behaviors/hold-tap
- JISレイアウト例: https://github.com/meronmks/zmk-keyboard-cornix/tree/JIS_MODE_LAYOUT
