# やまぶきR バイナリ解析レポート（同時打鍵判定の実装）

`yamabuki_r.exe` / `yabuhook_r.dll`（32bit版, 2015-03-23ビルド）を radare2 で逆アセンブルし、
同時打鍵判定の実装を解析した結果。ソースは非公開のため逆アセンブルによる。

## 確定した事実（バイナリから直接確認）

### 1. 判定範囲パラメータ `thumb_shift_range`

- 設定構造体のオフセット **0x3c** に格納（`yamabuki_r.exe` の設定パーサ 0x00404c78 付近）
- **コード上の既定値 = 60**（`push 0x3c` = 60 をデフォルト値として設定読込）
- ただし**配布物 `NICOLA.ypr` の実値は `thumb_shift_range=65`**
  → **zmk-nicola の既定 `range-pct=65` と完全一致**（我々の値は正しかった）
- 値は **0〜100 にクランプ**される（範囲チェック `cmp dword [edi], 0x64` が
  thumb/sync/ex1/ex2 の4系統×計6箇所）→ マニュアルの「%」と整合
- 文字キー同士用の別設定 `sync_shift_range`（既定も65）が独立して存在
  （NICOLAでは不使用）

### 2. タイミング計測（すべて `yabuhook_r.dll` 側）

- 計測ヘルパーは **`fcn.10007c80`**（`get_timestamp`）。使用可否フラグ **`[0x1001895c]`** が立てば
  **QueryPerformanceCounter**（64bit、[out],[out+4]）、無ければ **timeGetTime**（32bit ms）にフォールバック。
- フック本体 `fcn.10006b70` が押鍵ごとにこれを呼び、時刻を状態構造体に記録
  （呼び出し時 `edi+0x20`＝区間始点(文字キー押下=0%基準)、`edi+0x30`＝親指キー押下時刻、
  `edi+0x40`＝区間終点(文字キー解放/次キー=100%) に対応。判定関数の呼び出し `0x10002aab` で確認）。

> 訂正: `yamabuki_r.exe` 側の QueryPerformanceCounter（`fcn.004106da`、entry0から呼ばれる）は
> **打鍵計測ではなく MSVC の `__security_init_cookie`**（GetSystemTimeAsFileTime/ProcessId/ThreadId/
> GetTickCount/QPC を XOR して番兵 `0xbb40e64e` と値＋補数を格納するスタックカナリア初期化）だった。
> **打鍵計測・判定は完全に DLL 側**にあり、exe の QPC とは無関係。

### 3. 判定アーキテクチャ（＝後判定であることの裏付け）

- `yabuhook_r.dll` はキーボードフック。キーイベントを**28バイト単位のイベントキュー**に
  タイムスタンプ付きで記録し、`PostMessageW` で処理側へ送る構造
  （`fcn.10002180` がキューを走査して送信）
- 判定は文字キー押下の瞬間ではなく、**イベントが揃った時点（文字キーの解放/次キー押下）で
  評価**される作り → マニュアルの「押した時点0〜放す/次キー100」および
  **zmk-nicola の%方式（後判定）と同じ設計**

### 4. 比率比較ロジック（＝%判定の本体、特定完了）

以前は「特定できなかった」としていた比率比較を、**`yabuhook_r.dll` の `fcn.10007cc0`**（123バイト、
状態機械 `fcn.100025c0` から93箇所呼ばれる）で特定した。除算は使わず、想定どおり**たすき掛け**。

呼び出し元（例 `0x10002aab`）で乗数として `mov eax, [ecx+0x3c]`＝**config+0x3c＝thumb_shift_range** を渡す
（文字キー同士用は代わりに config+0x48＝sync_shift_range）。timeGetTime 経路（32bit、最も明快）:

```asm
fcn.10007cc0 (0x10007d22〜):
  mov edx, [edx]        ; t0     = 区間始点(文字キー押下, 0%基準)
  mov ecx, [ecx]        ; t_end  = 区間終点(解放/次キー, 100%)
  sub ecx, edx          ; interval = t_end - t0
  imul ecx, eax         ; interval * range           ← range=config+0x3c
  mov eax, [ebx]        ; t_thumb = 親指キー押下時刻
  sub eax, edx          ; dt = t_thumb - t0
  imul eax, eax, 0x64   ; dt * 100                    ← ×100
  cmp ecx, eax          ; (interval*range) vs (dt*100)
  sbb eax, eax          ; eax = (interval*range <  dt*100) ? -1 : 0
  inc eax               ; eax = (interval*range >= dt*100) ?  1 : 0
  ret
```

QPC 経路（0x10007cd0〜）は同じ2つの積を `_allmul`（`fcn.10010c10`）で64bit化し、
`jl→0 / jg→1 / (下位unsigned) jb→0 / else→1` で比較する。**両経路とも式・境界の扱いは同一。**

- **判定式: `dt * 100 ≤ range * interval`（＝ dt/interval ≤ range/100）のとき戻り値 1＝同時打鍵成立。**
- 戻り値1の直後（呼び出し側 `test al,al; je`）で親指シフト文字を発行、0なら通常発行。
- **丸め・同着: 境界は inclusive（≤）。** `cmp;sbb;inc`（および QPC 側の分岐）により、
  **等値 `dt*100 == range*interval`（親指がちょうど range% 地点）では 1 を返す＝同時打鍵に倒れる**。
  マニュアル range.html の「range% **以内**」と一致。

## 実装の限界（正直な報告）

- **ソースコードは同梱されていない**（exe/dllバイナリのみ）。上記のフィールド対応
  （`edi+0x20/0x30/0x40` の 0%基準/親指/100%終点）は、判定関数の呼び出し `0x10002aab` 1経路では
  機械語から確認したが、93呼び出し全経路の時刻記録トレースまでは行っていない。
  ただし**丸め・同着の結論（≤, inclusive）は、どのフィールド割り当てでも `cmp;sbb;inc` から不変**に導かれる。

## 結論

マニュアル記載の仕様（%方式・既定65・後判定）は**バイナリと一致**。判定式まで機械語で確定した:
**`dt*100 ≤ range*interval`、等値は同時打鍵成立側（inclusive）。** 計測・判定は全て `yabuhook_r.dll` 側。

**zmk-nicola との照合（確認済み・完全一致）**: `modules/nicola/src/behavior_nicola.c:236` の
```c
const bool simul = (total <= 0) || (pos * 100 <= total * nc_range_pct);
```
は、正本の `dt*100 ≤ interval*range`（`pos`=dt=親指位置、`total`=interval、境界 `<=` inclusive）と
**式・境界とも完全一致**。既定値も65で一致。**両者を機械語／ソース両面で突き合わせ、
zmk-nicola の%方式は正本の忠実な再実装であることを確認した**（修正不要）。

## 再現手順

```bash
unzip YamabukiR.zip
r2 -q -c 'aaa; pdf @ fcn.10007cc0' YamabukiR/yabuhook_r.dll        # 比率比較の本体
r2 -q -c 'aaa; pd 12 @ 0x10002aab' YamabukiR/yabuhook_r.dll        # range=config+0x3c を渡す呼び出し
r2 -q -c 'aaa; pdf @ fcn.10007c80' YamabukiR/yabuhook_r.dll        # 時刻取得(QPC/timeGetTime)
grep thumb_shift_range YamabukiR/NICOLA.ypr                        # 配布デフォルト=65
```

## 関連: LLM4Decompile でのデコンパイル試行

同じ関数群に ASM→擬似C復元（LLM4Decompile）を当てるお試しを
[llm4decompile-trial.md](llm4decompile-trial.md) で実施（Issue #14）。結果は degenerate 出力で、
この比率比較の解明には**逆アセンブル（本レポート）の方が確実**だった。
