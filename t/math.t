#!/usr/bin/env raku
use v6;
use Test;
use lib 'lib';
use Cooklang;

my $source = '
Banana cake
Whip @eggs{3} together with @sugar{150%g}, until it is light and porous.
Peal @bananas{2-3} and mash them well.
Mix bananas into sugar and eggs.
Melt @butter{100%g} without getting brown. Mix into the other ingredients.
';

my $recipe = Cooklang.new( recipe => $source, factor => 1 );
is $recipe.ingredients[0]<quantity>,   3;
is $recipe.ingredients[1]<quantity>, 150;
is $recipe.ingredients[2]<quantity>, "2-3";
note("");
note("Ingredient (#1): {.<quantity>} {.<units>} {.<name>}") for $recipe.ingredients.list;

$recipe = Cooklang.new( recipe => $source, factor => 5 );
is $recipe.ingredients[0]<quantity>,  15;
is $recipe.ingredients[1]<quantity>, 750;
is $recipe.ingredients[2]<quantity>, "2-3 * 5";  # "10-15" would be better
note("");
note("Ingredient (#2): {.<quantity>} {.<units>} {.<name>}") for $recipe.ingredients.list;
#note("Ingredient (sorted): {.<quantity>} {.<units>} {.<name>}") for $recipe.ingredients.sort;
#note("Ingredient (sorted by name): {.<quantity>} {.<units>} {.<name>}") for $recipe.ingredients.sort(by => [<name>]);
#note("Ingredient (sorted by units, quantity, name): {.<quantity>} {.<units>} {.<name>}") for $recipe.ingredients.sort(by => [<units quantity name>]);

done-testing;
