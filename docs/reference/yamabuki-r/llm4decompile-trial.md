# やまぶきR LLM4Decompile お試し（Issue #14）

`yabu_r64.exe`（64bit）の関数を **LLM4Decompile 6.7b-v1.5** で擬似Cに復元してみるお試し。
既存の [binary-analysis.md](binary-analysis.md)（radare2 逆アセンブル）が
「比率比較の単一命令を特定できなかった」と残した課題に、デコンパイルで手掛かりが出るか確認するのが狙い。
**本格運用はしない。** ツールが動くか・可読なCが出るか・判定ロジックの痕跡が見えるか、の3点を見る。

## 方針（2026-07-10 決定）

- **対象は 64bit `yabu_r64.exe`**。LLM4Decompile は x86-64 Linux 中心の学習なので、
  32bit より 64bit のほうがアーキ一致で出力品質が上がる（ただし MSVC/PE は分布外で粗くはなる）。
- モデル実行は **Google Colab 無料枠 (T4)**。手元VMは GPU なしのため。
- 前処理（objdump 正規化）はローカルで実施し、抽出済みASMを `tools/decompile/inputs/` に固定。

## 手順（再現方法）

1. `tools/decompile/llm4decompile_yamabuki.ipynb` を Colab で開く。
2. ランタイムを **T4 GPU** にして上から実行（`transformers` 導入 → モデルDL → デコンパイル）。
3. 出力Cを本ファイルの各欄に貼る。
4. （任意）同ノートの Opus 4.8 比較セルで見比べる。

抽出コマンドは [tools/decompile/README.md](../../../tools/decompile/README.md) を参照。

## 対象関数

| 入力ASM | 関数 | サイズ | 位置づけ |
|---|---|---|---|
| `fcn_140001b30.asm` | 小リーフ関数 | 103B | 感触確認（まず動くか） |
| `fcn_140004fc0_security_cookie.asm` | `__security_init_cookie` | 179B | **精度検証**（正解が公知） |
| `fcn_140001000_msgloop.asm` | GetMessageW メッセージループ | 477B | **本命**（判定側の処理） |

### なぜ `__security_init_cookie` を入れたか

64bit で QueryPerformanceCounter を呼ぶのは、当初「タイミング計測」と当たりを付けた
`fcn.140004fc0` だったが、逆アセンブルを読むと定数 `0x2b992ddfa232` を使う
MSVC の **スタックカナリア初期化（`__security_init_cookie`）** だった。判定ロジックではない。
ただし**この関数は正解ソースが公開されている**ため、LLM4Decompile の復元精度を
厳密に採点できる格好の基準になる。そのため精度検証用として残した。

## 実行環境（2026-07-10 実施）

- Google Colab 無料枠 **Tesla T4 (16GB)**、`cuda: True` 確認。
- **1回目クラッシュ**: `torch_dtype=float16` + `.cuda()` は全重み(約13.5GB)を一度CPU RAMに載せてから
  GPUへ移すため、Colabの約13GB RAMを使い切り「セッションがクラッシュ」。
- **対策で成功**: `BitsAndBytesConfig(load_in_4bit=True)` + `device_map='auto'` +
  `low_cpu_mem_usage=True` に変更 → CPU RAMを使わずGPUへ直接ロード。**63秒でロード完了**、
  3関数とも生成完走（`DONE_ALL`）。
- ノートブック側にもこの4bit・OOM対策を反映済み（`llm4decompile_yamabuki.ipynb`）。

## 結果（実際の出力）

**3関数すべてで degenerate（反復的で無効な）出力**になった。生の出力には byte-BPE の
スペース記号（`Ġ` が `G` に見える）が残るが、スペースに直すと下記のとおり。

### 1. 小リーフ関数 `fcn.140001b30`（sanity_leaf）

```c
void sanity_leaf(void){ struct leaf_s I1; struct leaf_s I2; struct leaf_s I3;
                        struct leaf_s I4; struct leaf_s I5; struct leaf_s I6; ... }
```
所感: **中身の復元は失敗**。埋め込んだ関数名ラベル `sanity_leaf` に引きずられ、
意味のない `struct leaf_s` 宣言を延々反復するだけ。元の呼び出し列は一切反映されず。

### 2. `__security_init_cookie` `fcn.140004fc0`（精度検証）

```c
void security_init_cookie(void){ struct cookie_s cookie;
    cookie.cookie_version = COOKIE_VERSION;
    cookie.cookie_magic   = COOKIE_MAGIC;
    cookie.cookie_magic2  = COOKIE_M...  /* 反復して途切れる */ }
```
正解（採点基準）: QueryPerformanceCounter 等の値を XOR で混ぜてカナリア種を作り、
既定値 `0x2b992ddfa232` と一致したら差し替えて `__security_cookie`＋その補数に格納する。

所感: 名前が「cookie」なので `cookie_version`/`cookie_magic` を並べた点だけ雰囲気は合うが、
**これは関数名ラベルからの連想であって逆アセンブルの復元ではない**。XORでの種生成という
本質ロジックは全く出ていない。精度は実質ゼロ。

### 3. メッセージループ `fcn.140001000`（本命・判定の手掛かり）

```c
void msgloop_judge(void){ struct msg_info msg; struct msg_info *pmsg;
    int I; int J; int K; int L; int M; int N; ... }
```
所感: **判定ロジックの痕跡は得られず**。`msg`/`pmsg` と `int` 変数の反復のみで、
GetMessageW ループも range% 比較も現れない。binary-analysis.md の未解決課題は前進せず。

### （任意）Opus 4.8 比較

未実施（今回は LLM4Decompile 単体の感触確認を優先）。

## 結論

- **パイプラインは通った**: ASM抽出 → Colab T4 → 4bitロード(63s) → 生成、まで自動で完走。
  T4無料枠でも 6.7B を動かす手順（4bit・GPU直ロードでOOM回避）は確立できた。
- **が、この題材では実用にならなかった**: 出力は3関数とも degenerate で、
  埋め込んだ関数名ラベルを反復するだけ。実ロジックの復元はゼロ。
- **原因（推定）**:
  1. **分布外入力** — LLM4Decompile は gcc/Linux ELF 中心の学習。対象は MSVC/Windows PE で
     呼び出し規約もツールチェーンも異なり、モデルが「読めていない」。
  2. **関数名ラベルの混入** — 入力ASMの `<name>:` ラベルが名前ベースの hallucination を誘発した。
     次に試すならラベルを汎用名（`func`）にすべき。
  3. 4bit量子化も劣化に寄与しうる（ただし主因は 1）。
- **示唆**: 少なくとも素の LLM4Decompile-6.7B では、やまぶきR(PE)の判定ロジック解明に使えない。
  binary-analysis.md の結論どおり、**radare2 逆アセンブル＋手作業**の方が確実。
  次の一手があるとすれば「ラベル無し入力で再試行」「Ghidra疑似CをRefモデルに与える」
  「Opus 4.8 に同じASMを渡して比較」あたり。

---

関連: [binary-analysis.md](binary-analysis.md)（radare2解析） / [README.md](README.md)（正本の位置づけ） /
[tools/decompile/](../../../tools/decompile/)（本実験のスクリプト・ノートブック）
