#!/usr/bin/env python3
"""objdump の逆アセンブル出力を LLM4Decompile 用に正規化する。

LLM4Decompile-End 系（llm4decompile-6.7b-v1.5 など）は、objdump が出す
「アドレス列 / 16進バイト列 / # コメント」を取り除いた命令ストリームを入力に取る。
このスクリプトは PE/ELF いずれのバイナリでも、指定アドレス範囲の 1 関数を抽出して
その正規化済み ASM を標準出力に書き出す。

使い方:
    python extract_asm.py <binary> <start_addr> <stop_addr> [--name NAME]

例（やまぶきR 64bit の判定/計測関数 fcn.140004fc0, 179バイト）:
    python extract_asm.py YamabukiR/yabu_r64.exe 0x140004fc0 0x140005073 \
        --name judge_qpc > inputs/fcn_140004fc0_qpc.asm

出力形式（先頭に関数ラベル、以降は命令のみ）:
    <judge_qpc>:
    sub rsp, 0x28
    call 0x...
    ...
"""
import argparse
import re
import subprocess
import sys

# objdump の1命令行:  "  140004fc0:\t48 83 ec 28          \tsub    $0x28,%rsp"
# 先頭にアドレス、タブ区切りで16進バイト、タブ区切りで mnemonic operands。
LINE_RE = re.compile(r"^\s*[0-9a-fA-F]+:\t[0-9a-fA-F ]+\t(.*)$")


def normalize(binary: str, start: int, stop: int) -> list[str]:
    """objdump を呼び、[start, stop) の命令を正規化命令の配列で返す。"""
    out = subprocess.run(
        [
            "objdump",
            "-d",
            f"--start-address={hex(start)}",
            f"--stop-address={hex(stop)}",
            binary,
        ],
        capture_output=True,
        text=True,
        check=True,
    ).stdout

    insns: list[str] = []
    for line in out.splitlines():
        m = LINE_RE.match(line)
        if not m:
            continue
        insn = m.group(1)
        # 末尾の "# 0x...." コメント（RIP相対の解決先など）を除去
        insn = re.sub(r"\s*#.*$", "", insn)
        # 連続空白を1つに畳んで整形
        insn = re.sub(r"\s+", " ", insn).strip()
        if insn:
            insns.append(insn)
    return insns


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("binary")
    ap.add_argument("start", help="開始アドレス (例 0x140004fc0)")
    ap.add_argument("stop", help="終了アドレス（この手前まで）")
    ap.add_argument("--name", default="func", help="出力の関数ラベル名")
    args = ap.parse_args()

    start = int(args.start, 0)
    stop = int(args.stop, 0)
    if stop <= start:
        print("error: stop は start より大きくしてください", file=sys.stderr)
        return 2

    insns = normalize(args.binary, start, stop)
    if not insns:
        print("error: 命令を抽出できませんでした（アドレス範囲/バイナリを確認）", file=sys.stderr)
        return 1

    print(f"<{args.name}>:")
    for insn in insns:
        print(insn)
    print(f"\n; {len(insns)} instructions from {args.binary} [{hex(start)}, {hex(stop)})", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
