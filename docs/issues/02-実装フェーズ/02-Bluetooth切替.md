# 02-Bluetooth切替

> 種別: Issue / 親: [02-実装フェーズ](00-readme.md)
> 依存: [01-環境構築フェーズ/02-現行キーマップのZMK移植](../01-環境構築フェーズ/02-現行キーマップのZMK移植.md)

## 🎯 目的
複数の機器（PC/スマホ等）を BLE プロファイルで切り替えられるようにし、
NICOLA 改造後も切替が正常に動くことを確認する。

## 📚 背景（ZMK標準対応）
- ZMK は標準で BLE プロファイル5つを持ち、`&bt BT_SEL 0..4` / `BT_NXT` / `BT_PRV` / `BT_CLR` で操作できる
- 有線/無線出力の切替は `&out OUT_USB / OUT_BLE / OUT_TOG`
- 純正ファームで USER00〜06 が担っていた無線制御はこれらで置換する（キーマップ移植issueで配置済みの想定）

## ✅ 作業項目
- [ ] レイヤー9相当に `&bt BT_SEL 0-2` / `BT_CLR` / `&out OUT_TOG` を配置（移植issueの確認）
- [ ] 実機で2台以上に登録し、切替→再接続を検証
- [ ] NICOLA 有効状態でも切替が機能する（回帰なし）ことを確認

## 🏁 完了条件
- 複数機器を登録し、キー操作で接続先を切り替えられる
- NICOLA 有効状態でも切替が機能する（回帰なし）

## 🔗 参照
- ZMK Bluetooth behavior: https://zmk.dev/docs/keymaps/behaviors/bluetooth
- 出力切替: https://zmk.dev/docs/keymaps/behaviors/outputs
