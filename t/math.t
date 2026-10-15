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
is $recipe.ingredients[0]<measurement><quantity>, 3,     'quantity through hash access';
is $recipe.ingredients[0].quantity,               3,     'quantity: number';
is $recipe.ingredients[1].quantity,               150,   'quantity: number with units';
is $recipe.ingredients[2].quantity,               '2-3', 'quantity: range';
is $recipe.ingredients[4].quantity,               1.5,   'quantity: mixed number';
is $recipe.ingredients[5].quantity,               'few', 'quantity: text';

$recipe = Cooklang.new( recipe => $source, factor => 5 );
is $recipe.ingredients[0].measurement.number, 15,  'factor 5: number scaled';
is $recipe.ingredients[1].measurement.number, 750, 'factor 5: number with units scaled';
is $recipe.ingredients[2].measurement.number, '10-15',    'factor 5: both ends of a range scaled';
is $recipe.ingredients[4].measurement.number, 7.5,        'factor 5: mixed number scaled';
is $recipe.ingredients[5].measurement.number, 'few * 5',  'factor 5: text shows the factor';

done-testing;
