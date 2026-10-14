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
is $recipe.ingredients[0]<measurement><quantity>,   3;
is $recipe.ingredients[0].quantity,    3;
is $recipe.ingredients[1].quantity, 150;
is $recipe.ingredients[2].quantity, '2-3';

$recipe = Cooklang.new( recipe => $source, factor => 5 );
is $recipe.ingredients[0].measurement.number,  15;
is $recipe.ingredients[1].measurement.number, 750;

done-testing;
