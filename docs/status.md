# cornix-oyayubi 現状整理

最終更新: 2026-07-07

## 🎯 ゴール
**Cornix LP（Jezail Funder の無線分割キーボード）で親指シフト（NICOLA配列）を実装する。**

満たしたい挙動（first.md より）:
1. シフトキーを押している間に押されたキーにシフトをかける
2. 同時押しでもシフトがかかる
3. 同時押し後も押し続ける間はシフト状態を維持する

## 🧭 実装方針

**ZMK路線に転換（2026-07-02 決定）。** 詳細な根拠は [方針分析レポート](reports/nicola-policy-analysis.md)。

- ベース: **hitsmaxft/zmk-keyboard-cornix**（Cornix用ZMKボード定義。分割BLEの実機動作実績あり）
- NICOLA実装: **eswai/zmk-naginata**（QMK nicola.c 作者本人のZMK同時押しかな入力モジュール）の
  構造を流用し、`nicola.c` のロジックを移植した `zmk-nicola` モジュールを作る
- 暫定運用: 純正ファームのまま Windows に紅皿/やまぶきR を導入すれば今日から練習可能

### 方針の変遷

| 時期 | 方針 | 結果 |
|------|------|------|
| 2026-06-07 | QMK自前ビルド | ✗ nRF52840 BLE を QMK が非対応のため断念 |
| 2026-06-07〜08 | RMK自前ビルド | ⚠️ 停滞。右手BLEペリフェラルを左centralが発見できない（[調査レポート](reports/cornix-split-ble-right-hand-investigation.md)） |
| 2026-07-02 | **ZMK + zmk-naginata改造** | ✅ 採用。既製ボード定義でBLE問題を回避、NICOLA移植の最短ルート |

## 🔍 これまでの調査資産

### ハード/ファーム情報

| 項目 | 内容 |
|------|------|
| **MCU** | nRF52840（BLE内蔵） |
| **標準ファーム** | RMKベースのVial対応品（v1.8、[公式配布](https://docs.channel.io/jezailfunderjp/ja/articles/Cornix-ファームウェア-bf1534b6)） |
| **ブートローダ** | Adafruit nRF UF2（ダブルタップリセットでUF2ドライブ出現） |
| **接続** | USB-C 有線 / BLE 無線（左半分がマスター） |

### RMK調査で確認済みの事実（ZMK路線でも有効）
- 右手マトリクス配線・ピン設定は正常（standalone診断で読み取り成功）
- 左half単体はUSB HIDとして動作
- ~~未解決: 右手のBLEアドバタイズが左から見えない~~ → **フェーズ0で解決（2026-07-06）**:
  ZMK既製UF2（v2.6.8）で右手BLE・PC接続・USB有線すべて動作。ハード正常、RMK問題はコード側と確定

### バックアップ資産（2026-07-06 確保、[firmware/stock/](../firmware/stock/README.md)）
- 純正 V1.12.zip（公式配布、左右UF2入り）
- **v1.8 実機吸い出し**（CURRENT.UF2 左右分。v1.8は配布終了のため貴重）
- カスタマイズ済Vialキーマップ: `docs/keymap/keymap-20260706-203100.vil`（ロールバック・ZMK移植のマスター）

### CornixHub 全148キーマップの分析（2026-07-02）
- 親指シフト/NICOLA/薙刀式の先行事例は **ゼロ**（Vialのみでは要件③が実現不能の裏付け）
- データ: [docs/keymap/cornixhub/](keymap/cornixhub/index.md) / 現行キーマップの記録: [docs/keymap/README.md](keymap/README.md)

### 参考コード（親指シフトロジック）
- **`eswai/qmk_firmware`** crkbd用 `nicola.c`: `process_nicola()` / `ncl_type()` / タイマーレス同時押し判定（`ncl_keycount > 1`）
- 配列テーブルは `.t`（単独）/`.l`（左シフト）/`.r`（右シフト）の3分岐
- **`eswai/zmk-naginata`**: 上記作者によるZMK behaviorモジュール（移植の型として使う）

## 📋 フェーズ計画

| フェーズ | 内容 | 状態 |
|---------|------|------|
| 0. 実機検証 | ZMK既製UF2で右手無線動作を確認（[手順書](guides/phase0-zmk-flash-verification.md)） | ✅ **完了（2026-07-06）右手BLE動作、ZMK路線GO確定** |
| 1. 環境構築 | ZMKフォーク・Actionsビルド・現行キーマップ移植（[issues/01](issues/01-環境構築フェーズ/00-readme.md)） | ✅ **完了（2026-07-06）** fork=[AutoFor/zmk-keyboard-cornix](https://github.com/AutoFor/zmk-keyboard-cornix) `oyayubi`ブランチ。移植キーマップを実機書き込み・USB入力確認済み。運用フロー: [ビルド&書き込み手順](guides/build-and-flash-workflow.md)＋`tools/flash-cornix.ps1` |
| 2. 実装 | zmk-nicola モジュール（最小PoC→全表）＋BLE/電池/キーマップ運用（[issues/02](issues/02-実装フェーズ/00-readme.md)） | ✅ **完了（2026-07-07）実機で親指シフト入力の動作を確認**。[AutoFor/zmk-nicola](https://github.com/AutoFor/zmk-nicola) 全配列表実装。連続シフト(要件③)は参照実装になく独自拡張で対応。細かい打鍵感の調整は使いながら随時 |
| 3. 検証 | 全部入りE2E（[issues/03](issues/03-検証フェーズ/00-readme.md)） | ドラフト |

> 旧RMK前提のissueドラフトは 2026-07-02 にZMK前提へ改訂（旧版はgit履歴参照）。
> RMK scaffold（Cargo.toml / src/central.rs 等）は本リポジトリには未コミット。必要になれば調査レポートを参照。
