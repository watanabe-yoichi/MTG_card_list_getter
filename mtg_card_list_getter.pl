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
use Encode;

=head1 SYNOPSIS

excute : perl mtg_card_list_getter.pl [cardlist name]

ex) perl mtg_card_list_getter.pl Kaladesh

=cut

use constant {
    # IE8のフリをする
    USER_AGENT => "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0)",

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

my $list_name  = shift @ARGV;
my $TARGET_URL = sprintf(
    "http://whisper.wisdom-guild.net/cardlist/%s", $list_name
);

my $csv_info = setup_csv($');
my $csv  = $csv_info->{csv};
my $file = $csv_info->{file};

# カードリストがあるページの全内容を取得
my $tree_info = parse_content($TARGET_URL);
my $tree      = $tree_info->{tree};

print "start extract $list_name cards.\n" ;

# 一覧ページからカード毎のURLを抽出
my @card_urls = extract_card_urls($tree);

# 各URLからカードの情報を抽出
my $all_card_info = extract_card_info(@card_urls);

# カード情報の出力
my $content_fh = $file->open('a') or die $!;
my $card_num;
my @rows;
for my $card_info (@{ $all_card_info }) {
    my @row;
    for my $key (@{ &CONTENT_TYPES }) {
        if (exists $card_info->{$key}) {
            push @row, $card_info->{$key};
        }
        else {
            push @row, '-';
        }
    }
    push @rows, \@row;
    $card_num++;
}
$csv->print($content_fh, $_) for @rows;
$content_fh->close;

$tree = $tree->delete;
print "finished! extract $card_num cards.\n" ;

# --------------------------------------------------------

sub setup_csv {
    # CSV準備
    my $csv = Text::CSV_XS->new({
        sep_char => ',',
        binary   => 1,
        eol      => "\n"
    });

    # ファイル準備
    my $dir  = Path::Class::Dir->new(cwd());
    my $file = $dir->file("$list_name.csv");

    # 見出しを出力
    my $type_fh = $file->open('w') or die $!;
    my @encoded_content = map { encode('utf-8', $_) } @{ &CONTENT_TYPES };
    $csv->print($type_fh, \@encoded_content);
    $type_fh->close;

    return +{
        csv  => $csv,
        file => $file,
    };
}

sub parse_content {
    my $url  = shift;

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

sub extract_card_urls {
    my $tree = shift;

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

    return @target_urls;
}

sub extract_card_info {
    my @urls  = @_;

    my $count = 0;
    my @all_card_info;
    for my $url (@urls) {
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
        print sprintf("extract: %s\n", $card_info->{カード名});

        push @all_card_info, $card_info;
        $tree = $tree->delete;
    }

    return \@all_card_info;
}

1;
