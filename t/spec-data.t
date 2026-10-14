#!/usr/bin/env raku
use v6;
use Test;
use YAMLish;
use lib 'lib';
use Cooklang;

my $text = 't/spec/tests/canonical.yaml'.IO.slurp;
my $canonical = load-yaml($text);
my %count = failed => 0, matched => 0, total => 0;
my $test_method = %*ENV<TEST_METHOD> // rx/./;
my $filter = rx{$test_method};

for $canonical<tests>.sort(*.key).map(*.kv).flat -> $name, $test {
    next if $name !~~ $filter;
    # Cookware has no units (spec tests/README.md), but a few canonical tests
    # list `units: ""` for cookware anyway. Drop it so all tests agree.
    for $test<result><steps>.map(|*) -> $item {
        $item<units>:delete if $item<type> eq 'cookware' && ($item<units> // '-') eq '';
    }
    my $recipe = Cooklang.new( recipe => $test<source> );

    my $status = $recipe.match ~~ Match ?? 'matched' !! 'failed';
    %count{ $status }++;
    %count<total>++;

    my $test_message =  sprintf("  Input text:   %s\n  Expected:    %s\n  Got (.data):  %s",
        $test<source>.subst(/\v/, '\v', :g), $test<result>.raku, $recipe.data.raku);

    subtest $name => {
        is-deeply( $recipe.data, $test<result>, $test_message);
    };
}
note(%count);

done-testing;
