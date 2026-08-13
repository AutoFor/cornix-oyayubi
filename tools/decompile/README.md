# LLM4Decompile お試しツール (Issue #14)

やまぶきR (`yabu_r64.exe`, 64bit) の関数を LLM4Decompile で擬似Cに復元してみるためのツール一式。
本格運用ではなく感触を掴むお試し。背景と結果は
[docs/reference/yamabuki-r/llm4decompile-trial.md](../../docs/reference/yamabuki-r/llm4decompile-trial.md)。

## 構成

| ファイル | 役割 |
|---|---|
| `extract_asm.py` | objdump 出力を LLM4Decompile 用に正規化（アドレス列・16進バイト・コメント除去） |
| `inputs/*.asm` | 抽出済みの入力ASM（3関数）。ノートブックにも直書きしてあるので単体でも動く |
| `llm4decompile_yamabuki.ipynb` | Google Colab (T4) 用ノートブック。モデル実行はこちら |

## 実行環境

- **逆アセンブルの下ごしらえ**（`extract_asm.py`）はローカルで動く（objdump が要る）。
- **モデル実行**は 6.7B のため GPU 必須 → **Google Colab 無料枠 (T4 16GB)** で `.ipynb` を開いて上から実行。
  手元VMは GPU なし・RAM 少で不可。

## ASM の抽出（対象を増やしたいとき）

```bash
# YamabukiR.zip を展開して exe を取り出し
unzip ../../docs/reference/yamabuki-r/YamabukiR.zip 'YamabukiR/yabu_r64.exe'

# 関数の開始・終了アドレスは radare2 で調べる:
#   r2 -q -c 'aaa; afl' YamabukiR/yabu_r64.exe | sort
# 例: fcn.140001000 (メッセージループ, 477B) を抽出
python3 extract_asm.py YamabukiR/yabu_r64.exe 0x140001000 0x1400011dd \
    --name msgloop_judge > inputs/fcn_140001000_msgloop.asm
```

## 対象関数（現状3つ）

| 入力 | 関数 | 位置づけ |
|---|---|---|
| `inputs/fcn_140001b30.asm` | 小リーフ関数 (103B) | 感触確認（まず動くか） |
| `inputs/fcn_140004fc0_security_cookie.asm` | `__security_init_cookie` (179B) | 精度検証（正解が公知のMSVC CRT）。QueryPerformanceCounter でカナリア種を作る定番処理 |
| `inputs/fcn_140001000_msgloop.asm` | GetMessageW メッセージループ (477B) | 本命候補。フックからPostMessageWされたキーイベントの処理側。判定ロジックの手掛かりを探す |

> `__security_init_cookie` は正解ソースが公開されているため、復元Cの正しさを厳密に採点できる基準になる。
> 同時打鍵の比率判定そのものの厳密な特定は、既存の
> [binary-analysis.md](../../docs/reference/yamabuki-r/binary-analysis.md) が残した未解決課題であり、
> この実験でメッセージループのCを読んで手掛かりが出るかを見る。
