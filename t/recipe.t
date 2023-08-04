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
#   note "Object ast:\t", $recipe.data.raku;

    my $status = $recipe.match ~~ Match ?? 'matched' !! 'failed';
    %count{ $status }++;
    %count<total>++;

    my $test_message =  sprintf("Expect result to match for %s\n  Input text: %s\n  Objct AST:  %s\n  Expected:  %s",
        $name, $test<source>.subst(/\v/, '\v', :g), $recipe.data.raku, $test<result>.raku);

    subtest 'is-deeply' => {
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
