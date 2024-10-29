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
Add @cream{1 1/2%dl}, and mix well.
Note @thyme{few%springs}.
';

my $recipe = Cooklang.new( recipe => $source, factor => 1 );
#note $recipe.ingredients[0].raku;
is $recipe.ingredients[0]<measurement><quantity>,   3;
#is $recipe.ingredients[0]<quantity>,   3;
is $recipe.ingredients[0].quantity,    3;
#is $recipe.ingredients[1]<quantity>, 150;
is $recipe.ingredients[1].quantity, 150;
#is $recipe.ingredients[2]<quantity>, "2-3";
is $recipe.ingredients[2].quantity, '2-3';
#note("");
#note("Ingredient (#1): {.quantity//'<undef>'} {.units//'<undef>'} {.name//'<undef>'}") for $recipe.ingredients.list;

$recipe = Cooklang.new( recipe => $source, factor => 5 );
is $recipe.ingredients[0].measurement.number,  15;
is $recipe.ingredients[1].measurement.number, 750;
#like $recipe.ingredients[2].quantity, /^< '10-15' | '2-3 * 5' >$/;
#is $recipe.ingredients[2].quantity, "2-3 * 5";  # "10-15" would be better
#note("");
#note("Ingredient (#2): {.quantity//'<undef>'} {.units//'<undef>'} {.name//'<undef>'}") for $recipe.ingredients.list;
#note("Ingredient (sorted): {.<quantity>} {.<units>} {.<name>}") for $recipe.ingredients.sort;
#note("Ingredient (sorted by name): {.<quantity>} {.<units>} {.<name>}") for $recipe.ingredients.sort(by => [<name>]);
#note("Ingredient (sorted by units, quantity, name): {.<quantity>} {.<units>} {.<name>}") for $recipe.ingredients.sort(by => [<units quantity name>]);
0 and is $recipe.human, '
Banana cake
Whip @eggs{3} together with @sugar{150%g}, until it is light and porous.
Peal @bananas{2-3} and mash them well.
Mix bananas into sugar and eggs.
Melt @butter{100%g} without getting brown. Mix into the other ingredients.
Add @cream{1 1/2%dl}, and mix well.
', "Recipe should look the same with a factor of 1.";


done-testing;
