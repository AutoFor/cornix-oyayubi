QMKでの親指シフト（NICOLAなど）実装事例はかなり豊富にあります。 [note](https://note.com/flyingwaffling/n/n6ae3ba810f8a)

## 代表的な実装事例（QMK）

- **自作・分割キーボードへの実装（Corne, keyball, Split65 など）**  
  - Corne V4 Cherry で QMK firmware による親指シフトを実装した詳細な解説記事。 [note](https://note.com/brave_nerine6819/n/n6c61c633f82b)
  - keyball44 での QMK 親指シフト実装（トラックボール＋マウスクリック制御も含めた高度な例）。 [note](https://note.com/brave_nerine6819/n/nc9e906b410e9)
  - Epomaker Split65 に NICOLA 配列を移植した事例（DFU への入り方から nicola 配列移植までの手順付き）。 [note](https://note.com/flyingwaffling/n/n6ae3ba810f8a)

- **フルキーボード／キット系（XD60, guide68, GK68 など）**  
  - XD60 キット を使って親指シフトキーボードを作成した記事（矢印キー付き構成、QMK での配列定義を解説）。 [qiita](https://qiita.com/keyoshizawa/items/4217ae6cdc4b860fd9fc)
  - guide68 キットでの親指シフト化（分割式は親指シフトに最適という観点で設計プロセスを説明）。 [qiita](https://qiita.com/keyoshizawa/items/5cacef940a2a990b5c86)
  - SKYLOONG GK68（QMK & VIA 対応）を QMK で親指シフト化した事例（MS-IME と組み合わせて使用）。 [note](https://note.com/ja7rhk/n/n129eb9cb04a3)

- **汎用的な QMK 実装（他キーボードへ移植しやすいコード）**  
  - 「【親指シフト】QMKで動くニコラ」では、QMK 上で動作する NICOLA 実装を公開しており、QMK が読めれば他キーボードへの移植も容易と説明されています。 [oookaworks.seesaa](https://oookaworks.seesaa.net/article/467889668.html)
  - 「QMKで自作キーボードを親指シフト/薙刀式へ拡張する」では、親指シフトに加えて薙刀式も QMK に実装した例を示しており、同時押し処理などの設計方針が参考になります。 [eswai.hatenablog](https://eswai.hatenablog.com/entry/2019/12/09/001009)

- **QMK 親指シフトのみを深掘りした実装記録**  
  - 「qmkで親指シフトの実装をしました。」では、  
    - シフトキーを押している間に押されたキーにシフトをかける  
    - 同時押しでもシフトがかかる  
    - 同時押し後も押し続ける間はシフト状態を維持する  
    …という、実用上欲しくなる挙動を満たす実装を詳しく解説しています。 [note](https://note.com/vast_mint8468/n/n9bddff0fe801)

## どの事例から読むと効率が良いか

- **QMK での「親指シフトロジック」そのものを知りたい**  
  - qmk での実装記事（） [note](https://note.com/vast_mint8468/n/n9bddff0fe801)
  - QMK で動く NICOLA 実装（） [oookaworks.seesaa](https://oookaworks.seesaa.net/article/467889668.html)
  - QMK＋親指シフト＋薙刀式の拡張記事（） [eswai.hatenablog](https://eswai.hatenablog.com/entry/2019/12/09/001009)

- **特定キーボード向けに設定をパクりたい・参考にしたい**  
  - Corne V4, keyball44 系なら [note](https://note.com/brave_nerine6819/n/n6c61c633f82b)
  - 60%〜65% キーボードやキット系なら XD60 / guide68 / GK68 の記事 [note](https://note.com/ja7rhk/n/n129eb9cb04a3)
  - 分割＋NICOLA 配列なら Split65 の記事 [note](https://note.com/flyingwaffling/n/n6ae3ba810f8a)

- **OS側ソフト vs QMK側実装の比較観点**  
  - Corne V4 の記事では、やまぶきRや紅皿など OS 側エミュレータに頼らず、ファームウェア側で親指シフトを実現するメリット（OS非依存・接続したら即使用可など）も整理されています。 [note](https://note.com/brave_nerine6819/n/n6c61c633f82b)

## 参考になりそうなコード・アイデア

- QMK の `keymap.c` における NICOLA 配列定義と、  
  - 「同時押しの判定タイミング」  
  - 「シフトキー長押し vs タップ」  
 などをどう分岐させているかのサンプルは、 のあたりが実装の参考になりやすいです。 [eswai.hatenablog](https://eswai.hatenablog.com/entry/2019/12/09/001009)

- また、MS-IME や Japanist10 など既存環境から移行したユーザの備忘録的記事（）では、QMK と日本語入力環境の組み合わせの実践的な運用も触れられています。 [yshigu](https://yshigu.net/entry/2024/04/16/150133)

***

もしよければ、いまお使いの（あるいは購入予定の）キーボードの機種名を教えてもらえると、その機種に近い事例や、具体的にどのリポジトリを参考にすると良いかまで絞り込みます。 



「Cornix」という名前での事例は見つからず、おそらく **Corne（crkbd / Corne Cherry / Corne V4）系** のことだと思われますが、この系統での QMK 親指シフト事例はあります。 [note](https://note.com/brave_nerine6819/n/n6c61c633f82b)

## Corne 系での QMK 親指シフト事例

- Corne V4 Cherry で親指シフトキーボードを作る（QMK firmware 編）  
  - note の記事で、Corne V4 Cherry を対象に QMK で親指シフトを実装した手順が詳しく解説されています。  
  - QMK で親指シフトを実現するメリット（OS 非依存・接続するだけで即利用など）や、やまぶきR / 紅皿といった PC 側エミュとの比較にも触れています。 [note](https://note.com/brave_nerine6819/n/n6c61c633f82b)

- QMK で自作キーボードを親指シフト / 薙刀式へ拡張する（crkbd 向け）  
  - crkbd（= Corne 系）を対象に、QMK 上で親指シフトと薙刀式を実装している記事があります。 [eswai.hatenablog](https://eswai.hatenablog.com/entry/2019/12/09/001009)
  - 記事中から、QMK 公式リポジトリ内の `crkbd/keymaps/naginata_v12` などの keymap を参照でき、同時押し処理・レイヤ制御の実装パターンがそのまま参考になります。 [eswai.hatenablog](https://eswai.hatenablog.com/entry/2019/12/09/001009)

### 参考になりそうなポイント

- Corne V4 Cherry 記事は、  
  - 「QMK 環境のセットアップ → 親指シフト用 keymap 実装 → ビルド・フラッシュ」  
  を一通り追えるので、Corne 系で 0→1 する場合のチュートリアルとしてかなり使えます。 [note](https://note.com/brave_nerine6819/n/n6c61c633f82b)

- crkbd 薙刀式/親指シフト記事は、  
  - `process_record_user` での同時押し判定  
  - NICOLA/薙刀式のレイヤ切り替え  
  といったロジックを含んでいるので、「親指シフトロジックの組み方」自体を Corne の配列に流用するのに向いています。 [eswai.hatenablog](https://eswai.hatenablog.com/entry/2019/12/09/001009)

***
リンク先の **Cornix LP**（Jezail Funder の 36 キー・無線分割キーボード）については、現時点で「Cornix LP で QMK 親指シフトを実装した」と明示している記事・コード公開は見つかりませんでした。 [note](https://note.com/photodroid/n/nb7e1589c0174)
## Cornix LP 周りで分かったこと
- Cornix LP は  
  - 36キー＋レイヤー前提の分割無線キーボード。 [note](https://note.com/photodroid/n/nb7e1589c0174)
  - ファームウェアは **Vial 対応**（QMK 派生だが実装が一部異なる）と紹介されており、「vialが使用できますがqmkと実装自体が異なりところどころ多少挙動は違う」と明記されています。 [tsuiha](https://tsuiha.com/jzfcornix/)
  - 公式／レビューブログではレイヤー設定やテンティング機能などが詳しいものの、親指シフト配列の例は出ていません。 [techblog.dt-dynamics](https://techblog.dt-dynamics.com/entry/2026/04/01/140305)

- Cornix LP 使用レビューでも、  
  - 既存の親指シフトキーボード（富士通 FKB8579 など）と合わせて使っているユーザーはいるものの、Cornix LP 自体を親指シフト化した手順や keymap 公開は確認できませんでした。 [electricdoc](https://electricdoc.net/archives/10594)
## 代わりに参考になる「近い」事例
Cornix LP 自体の事例は見つからないものの、**構成・キー数が近い分割キーボードでの QMK 親指シフト例**はあるので、ロジックを移植する形になると思います。

- Corne（crkbd / Corne V4 Cherry）での QMK 親指シフト実装記事。 [argos.hatenablog](https://argos.hatenablog.com/entry/2020/09/08/035936)
- crkbd 向け「QMKで自作キーボードを親指シフト/薙刀式へ拡張」記事と、その `crkbd/keymaps/...` にある keymap 実装。 [eswai.hatenablog](https://eswai.hatenablog.com/entry/2019/12/09/001009)
- 任意の QMK キーボードに移植しやすい NICOLA 実装（「QMKで動くニコラ」）。 [oookaworks.seesaa](https://oookaworks.seesaa.net/article/467889668.html)

Cornix LP が Vial 対応であれば、  
- Vial 用の JSON / keymap.c をベースに、上記の「親指シフトロジックの部分」だけを取り込む  
- あるいは QMK ベースのファームを書き直して焼き直す（ただし無線ファームとの兼ね合い要調査）  
という作業になるはずです。 [tsuiha](https://tsuiha.com/jzfcornix/)

***

現状、「Cornix LP で QMK 親指シフトをやりました」と断言している公開事例は見当たらないので、自作する方向になる前提で話を組み立てた方が良さそうです。  
Cornix LP での実装を検討中であれば、優先したいのは「Vial 上で親指シフトをエミュる（タップダンス＋レイヤー）」か、「完全に QMK 側に振って無線まわりも含めて自前ビルドする」かのどちらかだと思いますが、どちら寄りで考えていますか？  
