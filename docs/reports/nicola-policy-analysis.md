# 親指シフト（NICOLA）実装 方針分析レポート

作成日: 2026-07-02

## 結論

**ZMK路線を本命とする。** hitsmaxft/zmk-keyboard-cornix（Cornix用ZMKボード定義・動作実績あり）の上に、
eswai/zmk-naginata（QMK nicola.c 作者本人によるZMK同時押しかな入力モジュール）の構造を流用して
NICOLA behavior を実装する。移行期間は OS側エミュレータ（紅皿/やまぶきR）で暫定運用できる。

RMK路線（従来方針）は右手BLEペリフェラル発見失敗（[調査レポート](cornix-split-ble-right-hand-investigation.md)）が
未解決のまま停滞しており、ZMKの既製ボード定義でこのブロッカーを丸ごと回避できることが決め手。

## 満たすべき3要件（status.md より）

1. シフトキーを押している間に押されたキーにシフトをかける
2. 同時押しでもシフトがかかる
3. 同時押し後も押し続ける間はシフト状態を維持する

## 分析1: CornixHub 全投稿の横断調査

CornixHub（https://cornixhub.com/）の公開API から、キーマップ付き投稿 **全148件** を取得し分析した
（データ: [docs/keymap/cornixhub/](../keymap/cornixhub/index.md)）。

| 項目 | 件数 |
|------|------|
| キーマップ付き投稿 | 148 |
| 親指シフト / NICOLA / 薙刀式 / 同時押しかな入力への言及 | **0** |
| LANG1（かなキー）使用 | 91 |
| タップダンス使用 | 89 |
| USERキー（Cornix独自無線制御）使用 | 140 |

### 示唆

- **Cornixでの親指シフト先行事例は存在しない**。コピーできるキーマップはなく、自作が必要
- 91件がかなキーを使う日本語ユーザーだが、全員がレイヤー/タップダンスの範囲にとどまっている
- Vialの標準機能（タップダンス・コンボ）は「キーを離した時点での解決」しか表現できず、
  要件③「押し続ける間シフト維持」を実現できない。148件に実例がないことはこの制約の裏付け
- → **Vialのみ路線は不成立**

## 分析2: ファームウェア路線の再評価

### 前提（既存調査より）

- Cornix LP: nRF52840 / 標準ファームはRMKベースのVial対応品 / Adafruit nRF UF2 ブートローダ
- QMK: nRF52840 BLE 非対応のため断念済み
- RMK自前ビルド: 左central USB動作・右手マトリクス読み取りまでは成功したが、
  **右手ペリフェラルのBLEアドバタイズを左が発見できず停滞**（2026-06-08 調査）

### 新事実（2026-07-02 Web調査）

1. **eswai/zmk-naginata が存在する**
   - QMK `nicola.c` / `naginata.c` の作者（eswai氏）本人による ZMK カスタム behavior モジュール
   - 「QMK薙刀式のコードをほぼそのまま使用」して移植済み（作者ブログ）
   - 導入は `#include <behaviors/naginata.dtsi>` ＋ ビルド時 `ZMK_EXTRA_MODULES` 指定
   - → NICOLA も同じモジュール構造で `nicola.c` を移植すれば実現できる。
     主作業は「配列テーブルと判定ロジックの差し替え」であり、ゼロからの behavior 開発ではない
2. **hitsmaxft/zmk-keyboard-cornix が存在する**
   - Cornix 用 ZMK ボード定義（cornix_left / cornix_right / dongle 構成）、GitHub Actions ビルド、リリースUF2配布
   - meronmks の JIS_MODE_LAYOUT 等フォーク多数 = **実機で ZMK 分割BLE が動いている実績**
   - → RMK で詰まっている右手BLE問題を既製ボード定義で回避できる

### 路線比較

| 路線 | 3要件 | 無線分割 | 工数 | リスク・備考 |
|------|-------|---------|------|------|
| **A. ZMK + zmk-naginata改造（採用）** | ◎ nicola.c移植 | ◎ 実績あり | 中 | Vial GUI喪失（ZMK Studio / keymapファイルで代替）。現行キーマップの再構築が必要 |
| B. RMK継続 | ◎ 設計済み | ✗ BLE発見問題が未解決 | 大 | ブロッカー解決の見通しなし |
| C. Vialのみ | ✗ 要件③不可 | ◎ 現状維持 | 小 | 実現不能（分析1で裏付け） |
| D. OS側エミュ（紅皿/やまぶきR） | ◎ ソフト側で解決 | ◎ 現状維持 | 極小 | PC毎に導入必要。**暫定運用に採用** |

### ZMK路線のトレードオフ（受容する制約）

- Vial GUI でのリアルタイム編集ができなくなる（keymapファイル＋GitHub Actions、または ZMK Studio で代替）
- 現行キーマップ（[docs/keymap/README.md](../keymap/README.md) に記録済み）の移植作業が発生
  - タップダンス4個 → ZMK hold-tap / tap-dance
  - コンボ11個 → ZMK combos
  - マクロ11個 → ZMK macros
  - USER00〜06（Cornix独自無線制御）→ ZMK標準の `&bt` / `&out` behavior で代替
- 純正ファームへはいつでも戻せる（UF2ブートローダ / 公式配布あり）ため、失敗リスクは低い

## 実行計画

フェーズ構成は [docs/issues/](../issues/) を参照。要点:

- **フェーズ0（最初にやる）**: hitsmaxft のリリースUF2をそのまま焼いて右手無線動作を確認
  → ハード正常性と RMK問題の切り分けが同時にできる（手順: [phase0手順書](../guides/phase0-zmk-flash-verification.md)）
- **フェーズ1**: ZMKフォーク＋Actionsビルド＋現行キーマップ移植
- **フェーズ2**: zmk-naginata をベースに `zmk-nicola` モジュール実装（最小PoC→全表）
- **フェーズ3**: E2E検証
- **併走**: 純正ファームのまま紅皿/やまぶきRで親指シフト練習を開始可能

## 参考リンク

- eswai/zmk-naginata: https://github.com/eswai/zmk-naginata
- ZMK薙刀式解説（作者ブログ）: https://eswai.hatenablog.com/entry/2023/10/01/122115
- hitsmaxft/zmk-keyboard-cornix: https://github.com/hitsmaxft/zmk-keyboard-cornix
- JIS対応フォーク: https://github.com/meronmks/zmk-keyboard-cornix/tree/JIS_MODE_LAYOUT
- QMK nicola.c（移植元）: eswai/qmk_firmware `keyboards/crkbd/keymaps/nicola/`
- Cornix 純正ファームウェア配布: https://docs.channel.io/jezailfunderjp/ja/articles/Cornix-ファームウェア-bf1534b6
- CornixHub（分析データ取得元）: https://cornixhub.com/
