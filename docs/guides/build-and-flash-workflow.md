# ビルド&書き込みワークフロー（ZMK運用の基本フロー）

作成日: 2026-07-06
Vial を失った代わりの「キーマップ変更 → ビルド → 書き込み」の定常フロー。

## 全体像

```
[VM/どこでも]                [GitHub Actions]           [Windows PC]
config/cornix.keymap 編集 → push → 自動ビルド(UF2生成) → flash-cornix.ps1 実行
  (AutoFor/zmk-keyboard-cornix                            ↓ 最新UF2を自動DL
   oyayubi ブランチ)                                       ↓ UF2ドライブ自動検出
                                                          → 左右に書き込み完了
```

## リポジトリ構成

- **AutoFor/zmk-keyboard-cornix**（hitsmaxft からの fork）
  - `main`: upstream 同期用。直接触らない
  - **`oyayubi`**: 自分のキーマップを載せる作業ブランチ。`config/cornix.keymap` を編集
- **AutoFor/cornix-oyayubi**（このリポジトリ）: ドキュメント・バックアップ・ツール

## 手順

### 0. NICOLA設定だけならWeb設定ツールが最速

**https://autofor.github.io/zmk-keyboard-cornix/**

- **⚡USB直結モード**（2026-07-08〜）: 左手をUSB接続して「USBで接続」→ スライダーが
  **その場で反映・キーボード内に保存**（ビルド・書き込み不要）。対象: 判定窓/判定範囲/連続シフト。
  仕組み: cornix_nicola_cfg シールドのCDC + zmk-nicola の設定コンソール
  （プロトコル: `get` / `set timeout 60` / `set cont 1` / `reset`）
- **GitHubモード**: 親指シフトキー変更や恒久化はこちら。コミット→自動ビルド→ `.\flash-cornix.ps1`。
  初回にGitHub PAT (classic, repoスコープ) が必要
- 注意: USB直結で調整した値はキーボード内保存で、gitのkeymap既定値とは別管理。
  最適値が決まったらGitHubモードでも同じ値にしておくと、`reset`や再ペアリング後もズレない

### 1. キーマップを変更する

`AutoFor/zmk-keyboard-cornix` の `oyayubi` ブランチで `config/cornix.keymap` を編集して push。

```bash
cd ~/ghq/github.com/AutoFor/zmk-keyboard-cornix   # VM上
git checkout oyayubi
# 編集...
git commit -am "keymap: xxx" && git push
```

push で GitHub Actions が自動ビルドを開始する（`config/*` の変更で発火）。
発火しない場合は手動で:

```bash
gh workflow run build.yml --repo AutoFor/zmk-keyboard-cornix --ref oyayubi
```

ビルド状況: https://github.com/AutoFor/zmk-keyboard-cornix/actions （約5〜6分）

### 2. Windows PC で書き込む

初回のみ: `winget install GitHub.cli` → `gh auth login`

```powershell
# このリポジトリの tools/flash-cornix.ps1 を実行
.\flash-cornix.ps1              # 左右両方
.\flash-cornix.ps1 -Side left   # 左手のみ（キーマップ変更は左手だけの書き換えでOKなことが多い）
```

スクリプトが自動でやること:
1. `oyayubi` ブランチの最新成功ビルドのアーティファクトをダウンロード
2. 「左手をブートローダモードにしてください」と案内 → リセットダブルタップ
3. UF2ドライブを **`INFO_UF2.TXT` の `Model: cornix` で自動検出**（D:/E:/F: どこでも可）
4. UF2 をコピー → 自動再起動を確認 → 右手も同様

### 3. 動作確認とロールバック

- 新キーマップが期待どおりか確認
- 壊れた場合: `firmware/stock/` の純正UF2（V1.12 または v1.8実機ダンプ）を
  手動でUF2ドライブへコピーすれば即復旧

## トラブルシューティング: BLEが繋がらない（2026-07-06 実績あり）

書き込み直後は**キーボード側に古いペアリング鍵が残る**ため、以下の症状が出ることがある:
- 既存の「Cornix」がずっと未接続 / 新規スキャンに出ない / 出るがペアリング失敗

**対処（実績のある順）:**
1. Windows側で「Cornix」を削除
2. **空きプロファイルへ切替**: 右手下段いちばん左（記号レイヤーキー）を押しながら、
   右端PrtScrのひとつ左を押す（= `&bt BT_SEL 1`）。記号レイヤーの右下3キーが BT_SEL 0/1/2
3. Windows「デバイスの追加」→ Cornix → ペアリング
4. それでもダメなら: `cornix_reset.uf2` を左右両方に焼いて設定初期化 → 通常UF2を焼き直し
   → 左右同時電源オンで1分待つ → ペアリング

関連キー配置（移植キーマップ）:
- NICOLA切替キー（Base #46「親」・右手親指行内から3番目。2026-07-22に旧・全角キーの位置へ移動）: **レイヤー切替専用**
  - Base #46: タップで `&to L_NICOLA`。NICOLA側の同位置は `&to L_BASE`。タップダンス・IME連動は廃止
  - IMEには一切関与しない。ウィンドウ切替直後にIME状態がズレる問題を切り分けるため、レイヤー切替とIME切替を別キーに分離した
- 半角/全角キー（Base #12・左手中段外から1番目。2026-07-22に旧BSpcの位置へ移動）: **IME切替専用**
  - `&kp NICOLA_ZENKAKU_KEY`（`config/cornix.keymap` 冒頭のdefineで環境ごとに差し替え、既定はWindows(JIS)向けGRAVE）
  - レイヤーには一切関与しない。ウィンドウ切替直後などIMEがズレたら手動でこのキーを押して直す運用
- BSpc（Base #11。旧「@[」の位置へ移動）: 押し出された「@」はNumNav #11へ
  （NICOLAレイヤーの非かなキーは常に&transでBaseと同一挙動を維持=必須ルール。例外は切替キーとBSpc）
- デバッグビルド: `.\flash-cornix.ps1 -DebugFw` で左手をUSBログ付き版にできる。
  左手をUSB接続し、Chromeで https://googlechromelabs.github.io/serial-terminal/ を開き
  「USB Serial Device (COMx)」に115200で接続するとZMKのログが流れる。
  （デバッグ版はStudioのUSB接続と排他。戻すには通常の `.\flash-cornix.ps1`）
- NICOLA設定: `config/cornix.keymap` 冒頭の `&nc { ... }` ブロックで調整
  - `NICOLA_TIMEOUT_MS 50`: 同時打鍵判定窓（ms）。ms方式(先判定・即出力)で有効。
    2026-07-08にデバッグログ実測で決定（意図した同時打鍵≤34ms・ロールオーバー誤爆=67ms → 中間の50ms）
  - `NICOLA_RANGE_PCT 65`: 同時打鍵判定範囲（%）。やまぶきR風%方式(後判定)で有効
  - `NICOLA_CONTINUOUS 0`: 連続シフト（1=オン, 0=オフ。既定オフ。オンにすると
    親指を押しっぱなしで後続の文字にもシフトがかかり続ける）

### NICOLA判定方式の切替（2026-07-08夜〜: ページから実行時切替に統合）

**両方式が1つのファーム(oyayubi)に同居**し、Web設定ツールのUSB直結モードの
ラジオボタン（またはコンソールの `set mode 0/1`）でその場で切替・保存できる。

- ms方式(mode=0, 既定): 固定窓・先判定・即出力。`timeout-ms` が有効
- %方式(mode=1): やまぶきR正本準拠・後判定。`range-pct` が有効
- 正本: [docs/reference/yamabuki-r/](../reference/yamabuki-r/README.md)

> 旧構成（oyayubi-pct / range-pct ブランチでの分離）は廃止。ブランチは履歴として残るが
> 今後のキーマップ変更は oyayubi のみでよい（pctへのmerge作業は不要）。
  - `left-thumb = <SPACE>` / `right-thumb = <INT4>`: 親指シフトキー（単独タップは
    そのキー自身を送出。変更時はNICOLAレイヤーの `&nc SPACE`/`&nc INT4` も合わせる）
- NICOLAレイヤーの@キー(P右隣): NICOLA-J規格どおり単独=、(読点)
- 記号レイヤー(L2)右下3キー: BT_SEL 0 / 1 / 2（プロファイル切替）
- Fnレイヤー(L3)右手上段: BT_CLR / USB強制 / BLE強制（&out）
  - ⚠️ USB強制を押すとBLEに出力されなくなる。戻すにはBLE強制（Iの位置）

## ZMK Studio（GUIでキーマップをリアルタイム変更）

書き込みなしでキー配置をGUIで変更できる（変更は即反映・キーボード内に保存）。

- `CONFIG_ZMK_STUDIO=y` はボードdefconfigで最初から有効（ロックも無効・アンロック操作不要）
- **WindowsのWeb版（https://zmk.studio）はUSB接続のみ**。BLE接続が使えるのは
  デスクトップアプリ版（Windows/macOS/Linux）とLinuxのWeb版だけ
- USB接続用の `studio-rpc-usb-uart` スニペットは 2026-07-07 に左手ビルドへ追加済み
  （それ以前のファームではUSB接続も不可 → 焼き直しが必要）

接続方法（どちらか）:
1. **USB（推奨・確実）**: 左手をUSB-Cケーブルで接続 → Chrome/Edge で https://zmk.studio → USB
2. **Bluetooth**: [デスクトップアプリ版](https://github.com/zmkfirmware/zmk-studio/releases) をインストールして接続

### ⚠️ 重要: Studioの変更は .keymap より優先される

Studio での変更はキーボード内のフラッシュに保存され、**以後 UF2 を焼き直しても
その位置は Studio の設定が勝ち続ける**。運用ルール:

- ちょい変更 → Studio、恒久変更 → `config/cornix.keymap` に反映して push & 焼き直し
- keymap 側を正としたいときは、Studio の「Restore Stock Settings」で
  キーボード内の上書きを消してから確認する
- `&nc`（NICOLA）は 2026-07-07 に Studio 対応済み: behavior名「NICOLA」で表示され、
  パラメータは「う を ゔ (A)」のような **かな付きラベル**（単独/左親指/右親指の順）で選べる
- 自作ホールドタップ等その他のカスタムビヘイビアは Studio から新規割当不可だが、
  既存の割当はそのまま動く

## 補足

- **書き込みは常に左右セットで行う**（`.\flash-cornix.ps1` のデフォルト）。
  Actions ビルドは毎回 ZMK 本体(main)の最新を取り込むため、左だけ焼くと左右でZMK版がズレて
  **右手が無反応になる**ことがある（2026-07-06 実際に発生。右手も同ビルドで焼いて解消）
- GUI で編集したい場合は [ZMK Keymap Editor](https://nickcoutsos.github.io/keymap-editor/) で
  fork の `oyayubi` ブランチを開く方法もある（要GitHub連携）
- upstream (hitsmaxft) の更新を取り込む: `main` を sync してから `oyayubi` に rebase/merge
