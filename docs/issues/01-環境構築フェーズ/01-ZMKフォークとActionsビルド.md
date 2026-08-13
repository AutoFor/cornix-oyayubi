# 01-ZMKフォークとActionsビルド

> 種別: Issue / 親: [01-環境構築フェーズ](00-readme.md)
> 依存: [フェーズ0 実機検証](../../guides/phase0-zmk-flash-verification.md)

## 🎯 目的
`hitsmaxft/zmk-keyboard-cornix` を fork し、GitHub Actions で自分の UF2 をビルド・
実機で動作させる（ZMK開発の最小ループを確立する）。

## ✅ 作業項目
- [ ] `hitsmaxft/zmk-keyboard-cornix` を GitHub 上で fork
  - JIS運用を重視する場合は `meronmks/zmk-keyboard-cornix`（JIS_MODE_LAYOUT ブランチ）も比較検討
- [ ] `build.yaml` / `config/west.yml` の構成を把握（対象ボード: cornix_left / cornix_right、dongle は使わない）
- [ ] 未改造のまま Actions を実行し、UF2 が生成されることを確認
- [ ] 生成 UF2 を左右に書き込み、既製リリースと同等に動くことを確認
- [ ] 純正Vialファームに戻す手順の再確認（フェーズ0手順書のロールバック節）

## 🏁 完了条件
- fork リポジトリの Actions が成功し UF2 が得られる
- その UF2 で左右分割・無線・有線が動く

## 🔗 参照
- https://github.com/hitsmaxft/zmk-keyboard-cornix （README のビルド手順 / Releases）
- ZMK ユーザーセットアップ: https://zmk.dev/docs/user-setup
