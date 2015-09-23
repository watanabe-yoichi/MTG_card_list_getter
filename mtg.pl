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
use Text::CSV;
use Cwd;
use Path::Class::Dir;

use constant {
    # ユーザ入力項目
    # Wisdom Guild掲載のエキスパンション毎のカードリスト
    TARGET_URL =>
        'http://whisper.wisdom-guild.net/cardlist/BornoftheGods/',

    # IE8のフリをする
    USER_AGENT =>
        "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0)",

    # カードの項目
    COLUMNS => [qw/ name cost type text oracle pt flavor illust info/],
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

        # カード情報を取得
        my @rows = $tree->look_down(
            'class', 'wg-whisper-card-detail'
        )->look_down(_tag => 'table')->look_down(_tag => 'td');

        my $card_info;
        my $number = -1;
        PARAM: for my $key (@{ &COLUMNS }) {
            $number++;

            unless ($rows[$number]) {
                $card_info->{$key} = '';
                next PARAM;
            }

            $card_info->{$key} = encode($encoder->name, $rows[$number]->as_text);
        }
        push @all_card_info, $card_info;

        use DDP; p $card_info;
        $tree = $tree->delete;
    }

    return \@all_card_info;
}

# -------------------------------------
# ここからメインの関数
# -------------------------------------
my $self = shift;

# カードリストがあるページの全内容を取得
my $tree_info = parse_content(TARGET_URL);
my $tree      = $tree_info->{tree};

# URLから全てのリンクを抽出
my @links = $tree->extract_links();

# 個別のカード情報へのリンクのみ抽出
my @target_links;
for my $link (@{ $links[0] }) {
    my $url = $link->[0];
    if ($url =~ /http:\/\/whisper\.wisdom-guild\.net\/card\/*/) {
        push @target_links, $url;
    }
}

# 各カードの情報を取得
my $all_card_info = extract_card_info(@target_links);

# CSVに書き出す
my $csv = Text::CSV_XS->new({
    sep_char => ',',
    binary   => 1,
    eol      => "\n"
});
my $dir  = Path::Class::Dir->new(cwd());
my $file = $dir->file("test.csv");

for my $card_info (@{ $all_card_info }) {
    my @sorted_keys = sort (keys %{ $card_info });
    my @row;
    for my $key (@sorted_keys) {
        push @row, $card_info->{$key};
    }

    my $fh = $file->open('a') or die $!;
    $csv->print($fh, \@row) if @row;
    $fh->close;
}


$tree = $tree->delete;

1;
