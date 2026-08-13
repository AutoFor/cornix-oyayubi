# 現行キーマップ（Vial エクスポート）

- **現行（マスター）**: [keymap-20260706-203100.vil](keymap-20260706-203100.vil) — 2026-07-06 取得、カスタマイズ済。
  ロールバック・ZMK移植はこちらを使う
- 旧バックアップ: [keymap-20260702-161754.vil](keymap-20260702-161754.vil) — 2026-07-02 取得（参考用。以下の内容とは大きく異なる）
- 対象: Cornix（分割・エンコーダ2個・レイヤー10枚 / Vial protocol 6）
- 用途: 親指シフト（NICOLA）実装前の現行レイアウトの記録。ZMK移植のマスター資料。

## レイヤー構成（実使用は 0〜4。5〜9 は空）

### レイヤー0（ベース / QWERTY・JIS）

```
左手                                     右手
Tab     Q    W    E    R    T         Y    U    I    O    P    @[
BSpace  A    S    D    F    G         H    J    K    L    ;    Enter
TD4     Z    X    C    V    B  (Mute) N    M    ,    .    /    Delete
TD2  RAlt LAlt TD3  Space TD0      TD1  変換  変換  全角  TO(3) PrtScr
```

- 右手 (Mute) 相当位置はエンコーダ2押し込み = マウス中クリック（KC_BTN3）
- 左小指ホームが **BSpace**、Shift は TD4（下段左端）
- `全角` = KC_GRAVE（JIS では半角/全角・IME切替）

### レイヤー1（TD0: 数字・カーソル）

```
Esc     1    2    3    4    5         6    7    8    9    0    -
BSpace  --   F2   ¥    '    -         ←    ↓    ↑    →    +;   Enter
TD4     --   --   --   S+7& S+2"      Home PgDn PgUp End  --   S+ろ_
TD2   --  LAlt LCtrl Space TO(0)    OSM(Win) TO(4) --  --  --  --
```

### レイヤー2（TD1: 記号）

```
--      --   --  TO(0) --   --        --   --  S+8(  S+9)  --   --
--      --   --   --   --   --        ]    NUHS# --   --   --   --
TD4     --   --   --   --   --        S+]} S+NUHS~ --  --   --   --
TD2   --   --  LCtrl  --  TD6       --   --   --  USER00 USER01 USER02
```

- USER00〜02: Cornix独自キー（無線系）。ユーザー判断で詳細メモは省略（ZMKでは `&bt`/`&out` に置換）

### レイヤー3（TO(3): ファンクション）

```
--      F1   F2   F3   F4   F5        （右手ほぼ空）
--      F6   F7   F8   F9   F10
--      --   --   --   F11  F12
--    --  LAlt  --   --  TO(0)
```

### レイヤー4（TO(4): 素のQWERTY・通常修飾キー）

標準的な QWERTY。LShift/LCtrl/LAlt/LGui が通常位置、右手に CapsLock。
（ゲーム・他人用のプレーンモードと推測）

## タップダンス（Vial: [tap, hold, double_tap, tap_hold, term]）

| TD | タップ | 長押し | ダブルタップ | 判定 | 配置 |
|----|--------|--------|-------------|------|------|
| TD(0) | TO(1) | MO(1) | - | 100ms | 左親指端 |
| TD(1) | OSL(2) | MO(2) | TO(2) | 150ms | 右親指端 |
| TD(2) | Esc | Esc | Win | 150ms | 左下段/親指列端 |
| TD(3) | OSM(Ctrl) | Ctrl | - | 250ms | 左親指 |
| TD(4) | OSM(Shift) | Shift | - | 200ms | 左下段端 |
| TD(5) | OSM(Alt) | Alt | - | 250ms | **未配置** |
| TD(6) | OSL(0) | MO(0) | TO(0) | 250ms | レイヤー2 |

**OSM（ワンショットモディファイア）多用が特徴。** ZMK では `&sk`（sticky key）＋
hold-tap の組み合わせで再現する。

**注意**: NICOLA の親指キー実装時は左親指の Space / TD0、右親指の TD1・変換キーと
競合するため配置調整が必要。

## コンボ・マクロ（7/6版で大幅整理済み）

- コンボ: **LAlt + Esc → M5** の1個のみ
- M0: Alt+Space（レイヤー1などから参照なし・待避中？）
- M5: テキスト `te` 入力

## エンコーダ

全レイヤー共通: エンコーダ1 = 音量（VOLD/VOLU）＋押し込み Mute、
エンコーダ2 = マウスホイール（WH_U/WH_D）＋押し込み 中クリック。

## Vial settings（参考）

`{'2': 200, '6': 1000, '7': 250, '18': 20, '19': 20, '22': 1, '23': 0, '26': 0, '27': 120}`
（グレース期間・タッピング関連。ZMK では hold-tap の `tapping-term-ms` 等で個別調整）
