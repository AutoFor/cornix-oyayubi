#!/usr/bin/env python3
"""compare.py — やまぶきR実挙動 vs zmk-nicola 判定の1打鍵突き合わせ。

capture-yamabuki.ps1 が出した session.jsonl を読み、同一のキー入力タイムスタンプ列に対して
  (A) zmk-nicola の %方式判定（behavior_nicola.c の忠実移植）を再生 → SHIFT/SINGLE を算出
  (B) やまぶきRが実際に出した文字 → SHIFT/SINGLE を分類（下記の自動学習で）
を1文字ずつ整列し、食い違いを pos/total/pct 付きで表示する。

(B) の分類はレイアウト表を持ち込まず自動学習する:
「その打鍵の区間中に親指キーが一切関与しなかった打鍵」は入力上あきらかに単独なので、
そのときの出力文字を各物理キーの『非シフト字』として学習し、以後の出力がそれと一致すれば
SINGLE、違えば SHIFT と判定する。全キーが最低1回はあきらかな単独で現れる文章が望ましい。

使い方:
  python compare.py session.jsonl --range 65 --lthumb 0x1D --rthumb 0x1C
既定の親指キー: 左=無変換(VK_NONCONVERT 0x1D) 右=変換(VK_CONVERT 0x1C)。やまぶきR設定に合わせて上書き。
"""
import argparse
import json
import sys

# 文字キーとみなす VK（かなを生む可能性のあるキー）。親指・修飾・制御は除外して扱う。
CHAR_VKS = set(range(0x30, 0x3A)) | set(range(0x41, 0x5B)) | {
    0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, 0xC0,           # ; = , - . / `
    0xDB, 0xDC, 0xDD, 0xDE, 0xE2,                       # [ \ ] ' <>(JIS)
}


def vk_label(vk):
    if 0x41 <= vk <= 0x5A:
        return chr(vk)
    if 0x30 <= vk <= 0x39:
        return chr(vk)
    names = {0x1C: "変換", 0x1D: "無変換", 0x20: "Space", 0xBA: ";", 0xBB: "=",
             0xBC: ",", 0xBD: "-", 0xBE: ".", 0xBF: "/", 0xC0: "`",
             0xDB: "[", 0xDC: "\\", 0xDD: "]", 0xDE: "'", 0xE2: "\\_"}
    return names.get(vk, f"VK_{vk:02X}")


def load(path):
    raw, out_native, out_inj = [], [], []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            e = json.loads(line)
            if e.get("src") == "raw":
                if e.get("inj", False):
                    # 注入イベント = やまぶきRの出力。KEYEVENTF_UNICODE(VK_PACKET)なら
                    # uni にコード単位が載る（WM_CHAR経路が使えない場合の保険）
                    if e.get("kind") == "down" and e.get("uni"):
                        out_inj.append({"t": e["t"], "src": "out", "ch": e["uni"]})
                else:
                    raw.append(e)          # 生の物理入力のみ判定に使う
            elif e.get("src") == "out":
                out_native.append(e)
    # WM_CHAR(native)があればそれを、無ければ注入VK_PACKET由来を使う（二重計上回避）
    out = out_native if out_native else out_inj
    raw.sort(key=lambda e: e["t"])
    out.sort(key=lambda e: e["t"])
    return raw, out


def run_zmk_model(raw, lthumb, rthumb, range_pct):
    """behavior_nicola.c の %方式(nc_mode==1)を忠実移植し、文字キーごとの判定を返す。

    返り値: 文字キー押下順の list。各要素 = dict(vk, t_down, decision, thumb, pos, total, pct)
      decision: 'SINGLE' / 'SHIFT'
      thumb:    'L' / 'R' / None
    """
    results = []
    # 保留中の文字キー（%方式は同時に1文字を判定対象に持つ設計）
    pending = None      # dict(vk, c_ts, idx, judge, judge_ts)  judge: 0/'L'/'R'
    l_held = r_held = False

    def resolve(end_ts):
        nonlocal pending
        if pending is None or pending["judge"] == 0:
            return
        total = end_ts - pending["c_ts"]
        pos = pending["judge_ts"] - pending["c_ts"]
        simul = (total <= 0) or (pos * 100 <= total * range_pct)
        results[pending["idx"]].update(
            decision="SHIFT" if simul else "SINGLE",
            thumb=pending["judge"],
            pos=round(pos, 1), total=round(total, 1),
            pct=(round(pos * 100.0 / total, 1) if total > 0 else 0.0),
        )
        pending = None

    for e in raw:
        vk, t, kind = e["vk"], e["t"], e["kind"]
        is_l = (vk == lthumb)
        is_r = (vk == rthumb)
        is_char = (vk in CHAR_VKS) and not is_l and not is_r

        if kind == "down":
            if is_l or is_r:
                if is_l:
                    l_held = True
                else:
                    r_held = True
                # 文字保留中で未判定なら、この親指を判定対象に（＝文字→親指の順）
                if pending is not None and pending["judge"] == 0:
                    pending["judge"] = "L" if is_l else "R"
                    pending["judge_ts"] = t
            elif is_char:
                # 次キー押下 = 前の保留文字の区間終端
                if pending is not None and pending["judge"] != 0:
                    resolve(t)
                elif pending is not None and pending["judge"] == 0:
                    # 前の文字が親指なしのまま次キー → 単独確定
                    results[pending["idx"]].update(decision="SINGLE", thumb=None,
                                                   pos=None, total=None, pct=None)
                    pending = None
                idx = len(results)
                results.append(dict(vk=vk, t_down=t, decision=None, thumb=None,
                                    pos=None, total=None, pct=None))
                if l_held or r_held:
                    # 親指先行（押しっぱなし中に文字）→ 即シフト確定
                    results[idx].update(decision="SHIFT", thumb="L" if l_held else "R",
                                        pos=0.0, total=None, pct=0.0)
                    pending = None
                else:
                    pending = dict(vk=vk, c_ts=t, idx=idx, judge=0, judge_ts=0)
        elif kind == "up":
            if is_l:
                l_held = False
            elif is_r:
                r_held = False
            elif is_char and pending is not None and pending["vk"] == vk:
                if pending["judge"] != 0:
                    resolve(t)                      # 文字キー解放 = 区間終端
                else:
                    results[pending["idx"]].update(decision="SINGLE", thumb=None,
                                                   pos=None, total=None, pct=None)
                    pending = None
    # 打ち終わり時点で未解決の保留があれば単独扱い
    if pending is not None and results[pending["idx"]]["decision"] is None:
        results[pending["idx"]]["decision"] = "SINGLE"
    return results


def learn_unshifted(raw, results, lthumb, rthumb):
    """区間中に親指が一切関与しなかった打鍵を『あきらかな単独』とみなし、
    その物理キーの非シフト字を後で out と突き合わせて学習するための印を返す。
    ここでは各文字打鍵が『あきらか単独か』のフラグだけ立てる（out整列後に字を確定）。"""
    # 親指の押下/解放区間を作る
    holds = []  # (start, end) 親指が押されていた区間
    stack = {}
    for e in raw:
        if e["vk"] in (lthumb, rthumb):
            if e["kind"] == "down":
                stack[e["vk"]] = e["t"]
            elif e["kind"] == "up" and e["vk"] in stack:
                holds.append((stack.pop(e["vk"]), e["t"]))
    # 各文字打鍵の区間 [t_down, 次の何かのイベント] に親指holdが重なるか
    downs = [r["t_down"] for r in results]
    for i, r in enumerate(results):
        start = r["t_down"]
        end = downs[i + 1] if i + 1 < len(downs) else start + 1e9
        overlap = any(hs < end and he > start for (hs, he) in holds)
        r["clean_single"] = not overlap
    return results


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("session")
    ap.add_argument("--range", type=int, default=65, help="thumb_shift_range (%%), 既定65")
    ap.add_argument("--lthumb", type=lambda x: int(x, 0), default=0x1D, help="左親指VK 既定0x1D(無変換)")
    ap.add_argument("--rthumb", type=lambda x: int(x, 0), default=0x1C, help="右親指VK 既定0x1C(変換)")
    args = ap.parse_args()

    raw, out = load(args.session)
    if not raw:
        print("入力イベントが空です。session.jsonl を確認してください。", file=sys.stderr)
        return 1

    results = run_zmk_model(raw, args.lthumb, args.rthumb, args.range)
    learn_unshifted(raw, results, args.lthumb, args.rthumb)

    # 出力文字を文字打鍵順に整列（1打鍵=1かな を仮定）
    out_chars = [chr(e["ch"]) for e in out if e["ch"] not in (0x0D, 0x0A, 0x08, 0x1B)]
    for i, r in enumerate(results):
        r["out"] = out_chars[i] if i < len(out_chars) else "?"

    # あきらか単独の出力を各キーの非シフト字として学習
    unshifted = {}
    for r in results:
        if r.get("clean_single") and r["out"] != "?":
            unshifted.setdefault(r["vk"], r["out"])

    # やまぶきR実判定を分類（out が非シフト字と一致=SINGLE、違えば SHIFT）
    for r in results:
        base = unshifted.get(r["vk"])
        if base is None or r["out"] == "?":
            r["yama"] = "?"      # 学習不能（このキーがあきらか単独で一度も出ていない）
        else:
            r["yama"] = "SINGLE" if r["out"] == base else "SHIFT"

    # 表示
    print(f"# session: {args.session}  range={args.range}%  "
          f"Lthumb={vk_label(args.lthumb)} Rthumb={vk_label(args.rthumb)}")
    print(f"# 入力打鍵 {len(results)} / 出力文字 {len(out_chars)}")
    print()
    hdr = f"{'#':>3} {'key':>5} {'pos':>7} {'total':>7} {'pct':>6}  {'zmk':<7} {'やまぶき':<8} {'出力':<4} {'一致?':<4}"
    print(hdr)
    print("-" * len(hdr))
    mism = 0
    unknown = 0
    for i, r in enumerate(results):
        # pos/total は捕捉のマイクロ秒。ms に換算して表示
        pos = "" if r["pos"] is None else f"{r['pos']/1000:.0f}"
        total = "" if r["total"] is None else f"{r['total']/1000:.0f}"
        pct = "" if r["pct"] is None else f"{r['pct']:.0f}%"
        zmk = r["decision"] + (f"({r['thumb']})" if r["thumb"] else "")
        yama = r["yama"]
        if yama == "?":
            mark = "?"
            unknown += 1
        elif (r["decision"] == "SHIFT") == (yama == "SHIFT"):
            mark = "ok"
        else:
            mark = "★NG"
            mism += 1
        print(f"{i:>3} {vk_label(r['vk']):>5} {pos:>7} {total:>7} {pct:>6}  "
              f"{zmk:<7} {yama:<8} {r['out']:<4} {mark:<4}")

    print()
    print(f"== 判定一致: {len(results)-mism-unknown} / 食い違い(★NG): {mism} / 学習不能(?): {unknown}")
    if mism:
        print("★NG 行が、式が一致していても実挙動がズレる箇所。pos/total/pct を見て")
        print("  『区間終端トリガの差』『時刻測定の差』『エッジケース』のどれかを切り分ける。")
    if unknown:
        print("? 行は、そのキーが『親指の関与しない単独打鍵』で一度も現れず非シフト字を学習できなかった。")
        print("  各キーを一度は単独で打つ文章にすると解消する。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
