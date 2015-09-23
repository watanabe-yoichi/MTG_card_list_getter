#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use lib '/Users/watanabe-yoichi/perl5/lib/perl5/';

use LWP::UserAgent;
use HTML::TreeBuilder;
use Encode;
use Encode 'decode';
use Encode::Guess;
use Cwd;
use Text::CSV;
use Path::Class::Dir;

use constant {
    # ユーザ入力項目
    # Wisdom Guild掲載のエキスパンション毎のカードリスト
    TARGET_URL =>
        'http://whisper.wisdom-guild.net/cardlist/BornoftheGods/',
    BASE_URL =>
        'http://whisper.wisdom-guild.net/cardlist/',

    # IE8のフリをする
    USER_AGENT =>
        "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0)",

    # カード項目
    CONTENT_TYPES => [qw/
        カード名
        マナコスト
        タイプ
        テキスト
        オラクル
        Ｐ／Ｔ
        忠誠度
        フレーバ
        イラスト
        セット等
        再録
    /],
};

sub parse_content {
    (my $url)  = @_;

    # LWPを使ってサイトにアクセスし、HTMLの内容を取得する
    my $ua = LWP::UserAgent->new('agent' => USER_AGENT);
    my $res = $ua->get($url);
    my $content = $res->content;

    # TreeBuilderはUTF8で文字化けするので、一度デコードする
    my $encoder = guess_encoding($content, qw/ euc-jp shiftjis 7bit-jis /);
    $content = decode($encoder->name, $content) unless (utf8::is_utf8($content));

    # HTML::TreeBuilderで解析する
    my $tree = HTML::TreeBuilder->new;
    $tree->parse($content);

    return +{
        tree    => $tree,
        encoder => $encoder,
    };
}

sub extract_card_info {
    (my @urls)  = @_;

    my $count = 0;
    my @all_card_info;
    CARD: for my $url (@urls) {
        my $tree_info = parse_content($url);
        my $tree      = $tree_info->{tree};
        my $encoder   = $tree_info->{encoder};

        # カード情報テーブルを取得
        my @rows = $tree->look_down(
            'class', 'wg-whisper-card-detail'
        )->look_down(_tag => 'tr');

        # 各パラメータを取得
        my $card_info;
        for my $row (@rows) {
            my $type    = $row->look_down(_tag => 'th')->as_text;
            my $content = $row->look_down(_tag => 'td')->as_text;

            $card_info->{$type} = encode('utf-8', $content);
        }
        warn "extract: ".$card_info->{カード名};

        push @all_card_info, $card_info;
        $tree = $tree->delete;
    }

    return \@all_card_info;
}

# -------------------------------------
# ここからメインの関数
# -------------------------------------
my $self = shift;

# 想定と違うURLが指定されたらreturn
return unless (TARGET_URL =~ BASE_URL);

my $filename = $';
chop $filename;

# カードリストがあるページの全内容を取得
my $tree_info = parse_content(TARGET_URL);
my $tree      = $tree_info->{tree};

# URLから全てのリンクを抽出
my @links = $tree->extract_links();

# 個別のカード情報へのリンクのみ抽出
my @target_urls;
for my $link (@{ $links[0] }) {
    my $url = $link->[0];
    if ($url =~ /http:\/\/whisper\.wisdom-guild\.net\/card\/*/) {
        push @target_urls, $url;
    }
}

# 各カードの情報を取得
my $all_card_info = extract_card_info(@target_urls);

# CSVに書き出す

my $csv = Text::CSV_XS->new({
    sep_char => ',',
    binary   => 1,
    eol      => "\n"
});
my $dir  = Path::Class::Dir->new(cwd());
my $file = $dir->file("$filename.csv");

# 見出しを出力
my $fh = $file->open('w') or die $!;
$csv->print($fh, &CONTENT_TYPES);
$fh->close;

# カード情報の出力
my $card_num;
for my $card_info (@{ $all_card_info }) {
    my @row;
    for my $key (@{ &CONTENT_TYPES }) {
        if (exists $card_info->{$key}) {
            # TODO: アーティファクトのマナコストが負の値になっちゃう
            push @row, $card_info->{$key};
        }
        else {
            push @row, '-';
        }
    }

    my $fh = $file->open('a') or die $!;
    $csv->print($fh, \@row) if @row;
    $fh->close;

    $card_num++;
}

$tree = $tree->delete;
warn "done! output $card_num cards" ;

1;
