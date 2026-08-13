# nicola-compare — やまぶきR実挙動 vs zmk-nicola 判定の突き合わせ

「式は一致しているのに、実際の打鍵挙動がズレる気がする」を客観的に切り分けるデバッグツール。
同じ文章を打ち、**やまぶきRが実際に出した判定結果**と、**zmk-nicola の判定ロジック（忠実移植）を
同一タイムスタンプ列で再生した結果**を、1打鍵ずつ突き合わせて食い違いを可視化する。

判定式そのものは `dt*100 ≤ range*interval`（inclusive）で両者一致を確認済み
（[../../docs/reference/yamabuki-r/binary-analysis.md](../../docs/reference/yamabuki-r/binary-analysis.md)）。
なのでズレるとしたら式ではなく、**区間終端トリガ／時刻測定／エッジケース**のどれか。これを炙り出す。

## 構成

| ファイル | 役割 | 実行環境 |
|---|---|---|
| `capture-yamabuki.ps1` | 生キー入力(QPC時刻)＋やまぶきR出力文字を JSONL 記録 | **Windows**（やまぶきR起動中） |
| `compare.py` | zmk判定を忠実移植して同じ入力を再生し、実挙動と差分表示 | どこでも（Python3） |

## 使い方

### 1. 捕捉（Windows・やまぶきR ON）
```powershell
powershell -ExecutionPolicy Bypass -File capture-yamabuki.ps1 -Out session.jsonl
```
開いた白窓に**比較したい文章を普通に打つ**。各キーは一度は「親指を絡めない単独」でも打っておくと、
非シフト字の自動学習が効いて全打鍵を自動判定できる。打ち終えたら Esc か窓を閉じる。

> 出力文字は既定でテキスト欄の WM_CHAR から拾う。やまぶきRが KEYEVENTF_UNICODE 注入で
> 出す構成でも、フックが拾う VK_PACKET(uni) から回収する保険を入れてある。
> どちらでも出力が0件なら構成が特殊なので相談を。

### 2. 突き合わせ
```bash
python3 compare.py session.jsonl --range 65 --lthumb 0x1D --rthumb 0x1C
```
- `--range`   thumb_shift_range（既定65）
- `--lthumb`  左親指のVK（既定 0x1D=無変換）
- `--rthumb`  右親指のVK（既定 0x1C=変換）。やまぶきRの親指キー設定に合わせる。

### 出力例
```
  #   key     pos   total    pct  zmk      やまぶき  出力  一致?
  0     K                         SINGLE   SINGLE   く    ok
  1     K      30     100    30%  SHIFT(L) SHIFT    ぐ    ok
  2     K      80     120    67%  SINGLE(L) SHIFT   ぐ    ★NG   ← ここが実挙動とのズレ
== 判定一致: 3 / 食い違い(★NG): 1 / 学習不能(?): 0
```
`★NG` の行の pos/total/pct を見れば、ズレの原因（下記）を切り分けられる。

## Claude が直接分析する回路（コピペ不要）

結果を貼り付けなくても Claude が読み取って分析できるように、捕捉後に localhost 配信する。

1. Windows で（やまぶきR ON、Chromeは Claude in Chrome で接続済み）:
   ```powershell
   powershell -ExecutionPolicy Bypass -File capture-yamabuki.ps1
   ```
   窓に文章を打つ → 閉じる → `配信中: http://localhost:8777/` と表示される。
2. Claude に **「localhost:8777 を読んで分析して」** と一言伝えるだけ。
3. Claude が接続済みChromeで `http://localhost:8777/data` を開いて生 session を取り込み、
   VM上の `compare.py` に流して `★NG` 箇所を特定し、原因（下記）まで所見を返す。

> なぜブラウザ単独で完結できないか: やまぶきRはOSレベル(WH_KEYBOARD_LL)で物理キーを飲み込んで
> 別文字を注入するため、ブラウザからは「出力結果」しか見えず**生の物理キー時刻が取れない**。
> だから生入力の捕捉にOSフック(このPS1)が要る。配信で Claude 側へ橋渡しする。

`-NoServe` を付ければ配信せずファイル保存のみ。`-Port` で待受ポート変更。

## ズレの主な原因（式一致でも起きる）

1. **区間終端トリガの差** — 100%点を「文字キー解放」で取るか「次キー押下」で取るか、どちらが先か。
   zmk移植は両者の先着（behavior_nicola.c と同じ）。実機ファームのスキャン順で差が出ることがある。
2. **時刻測定の差** — やまぶきRはOSのキーイベント時刻（QPC/ms）、zmk実機はファーム内スキャン時刻。
   デバウンス・USB/BLE遅延で pos/total の実測値自体がズレる。→ pos/total が両者で違うなら原因はこれ。
3. **エッジケース** — 親指先行、ロールオーバー、連続シフト、3キー同時など。

## 仕組みと前提

- **zmk側**: `compare.py` の `run_zmk_model()` が behavior_nicola.c の %方式(nc_mode==1)を移植。
  文字→親指=判定保留、区間終端(解放/次キーの先着)で `dt*100 ≤ range*interval` を評価、親指先行は即シフト。
- **やまぶき側の判定分類**: レイアウト表を持たず、「区間中に親指が一切関与しない打鍵」の出力を
  各物理キーの非シフト字として**自動学習**し、以後の出力がそれと一致=SINGLE / 違う=SHIFT と分類。
  あるキーがそのような単独打鍵で一度も現れないと、その行は `?`（学習不能）になる。
- **仮定**: 出力は「1文字キー=1かな」で入力順に対応。濁点合成や記号で崩れる場合は簡易版として割り引いて見る。
- **既知の限界**: 実機ファーム側のタイミングそのものは再現していない（移植は「同じ入力なら同じ判定か」を
  純粋に見るもの）。実機のスキャン時刻由来のズレを見たいときは、実機の `set log 1` ログと本ツールの
  出力を並べて比較する（次の拡張候補）。
