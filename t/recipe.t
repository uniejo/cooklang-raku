#!/usr/bin/env raku
use v6;
use Test;
use YAMLish;
use lib 'lib';
use Cooklang;

my $text = 't/canonical.yaml'.IO.slurp;
my $canonical = load-yaml($text);
my %count = failed => 0, matched => 0, total => 0;

for $canonical<tests>.sort(*.key).map(*.kv).flat -> $name, $test {
#   note "Testing: $name : ", $test<source>.subst(/\v/, '\v', :g);
    my $recipe = Cooklang.new( recipe => $test<source> );
#   note "Object data:\t", $recipe.data.raku;
#   note "Object match:\t", $recipe.match.raku;

    my $status = $recipe.match ~~ Match ?? 'matched' !! 'failed';
    %count{ $status }++;
    %count<total>++;

    my $test_title =  sprintf("Test: %s", $name);
    my $test_message =  sprintf("  Input text:   %s\n  Expected:    %s\n  Object DATA:  %s",
        $test<source>.subst(/\v/, '\v', :g), $test<result>.raku, $recipe.data.raku);

    subtest $test_title => {
        is-deeply( $recipe.data, $test<result>, $test_message);
    };

#   note $recipe.metadata;
#   note $recipe.ingredients;
#   note $recipe.steps;
#   note "Test finished: $name : $test<source>".subst(/\v/, '\v', :g);
#   note "--------";
}
note(%count);

done-testing;
