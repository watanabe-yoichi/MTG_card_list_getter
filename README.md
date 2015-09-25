# MTG_card_list_getter

### 概要  
本スクリプトはマジック・ザ・ギャザリングのカードデータ取得ツールです。

新しいエキスパンションが出た時には、次のリミテッドが一体どのような環境になるのか分析したくなるものです。  
いくつかの要望については [Wisdom Guild](http://www.wisdom-guild.net/) の便利なサーチエンジンが満たしてくれますが、  
「パワーとタフネスの分布やその平均はいくつか？」「マナコストの分布は？」といった問い対しては地道な努力によって解決するか、誰かがやってくれるのを待つ（もしくは諦める！）しかありませんでした。

本スクリプトを使えば、Wisdom Guild のデータベースをお手軽にCSVデータとして取得することができます。  
一度CSVにしてしまえば、、、後は思う存分やりたいことをやるだけです。

### 使い方  
* `mtg_card_list_getter.pl` の固定値に特定のエキスパンションのURLを入力する
```perl
use constant {
  TARGET_URL => 'http://whisper.wisdom-guild.net/cardlist/BornoftheGods/',
}
```
* コマンドラインで `perl mtg_card_list_getter.pl` を実行する
* 1分ほど待つ ([出力結果サンプル](https://github.com/watanabe-yoichi/MTG_card_list_getter/blob/master/BornoftheGods.csv))

### その他、注意事項など  
* Wisdom Guild 様の仕様に依存しているため、「当該サイトにカードデータが入力されていない」、「サイトのURLやレイアウトが変更になった」、などの際には望んだ結果が得られなくなる場合があります。
* ソースコードは汚いです。
