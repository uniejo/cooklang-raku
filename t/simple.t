#!/usr/bin/env raku
use v6;
use lib 'lib';
use Test;
use Cooklang;

my $source = '
Banana cake
Whip @eggs{3} together with @sugar{150%g} in a #bowl{}, until it is light and porous.
Peal @bananas{2-3} and mash them well.
Mix bananas into sugar and eggs.
Melt @butter{100%g} without getting brown. Mix into the other ingredients.
>> test_file: t/simple.t
';

my $recipe = Cooklang.new( recipe => $source, factor => 1 );

is $recipe.match.made[1].WHAT, Cooklang::Step, 'Match made Part 1 type is: Cooklang::Step';
is $recipe.match.made[1].orig, 'Banana cake',  'Match made Part 1 has text: Banana cake';

is $recipe.parts[0].WHAT, Cooklang::Vertical, 'Part 1 type is: Cooklang::Vertical';
is $recipe.parts[0].orig, "\n",  'Part 1 has text: vertical line';
is $recipe.parts[0].gist, "\n",  'Part 1 has gist: vertical line';
is $recipe.parts[1].WHAT, Cooklang::Step, 'Part 2 type is: Cooklang::Step';
is $recipe.parts[1].orig, 'Banana cake',  'Part 2 has text: Banana cake';
is $recipe.parts[1].gist, 'Banana cake',  'Part 2 has gist: Banana cake';
is $recipe.parts[2].WHAT, Cooklang::Vertical, 'Part 3 type is: Cooklang::Vertical';
is $recipe.parts[2].orig, "\n",  'Part 3 has text: Banana cake';
is $recipe.parts[2].gist, "\n",  'Part 3 has gist: Banana cake';
is $recipe.parts[3].WHAT, Cooklang::Step, 'Part 3 type is: Cooklang::Step';
is $recipe.parts[3].orig, 'Whip ',        'Part 3 has text: Whip ';
is $recipe.parts[3].gist, 'Whip ',        'Part 3 has gist: Whip ';
is $recipe.parts[4].WHAT, Cooklang::Ingredient, 'Part 3 type is: Cooklang::Ingredient';
is $recipe.parts[4].orig, '@eggs{3}',     'Part 3 is item: @eggs{3}';
is $recipe.parts[4].gist, '@eggs{3}',     'Part 3 has gist: @eggs{3}';
is $recipe.parts[4].quantity, 3,          'Part 3 is item quantity: 3';
is $recipe.parts[8].WHAT, Cooklang::Cookware, 'Part 7 type is: Cooklang::Cookware';
is $recipe.parts[8].orig, '#bowl{}',          'Part 7 has orig: bowl{}';
is $recipe.parts[8].gist, '#bowl{}',          'Part 7 has gist: bowl{}';

is $recipe.ingredients[0].orig, '@eggs{3}',        'Ingredient 1 is item: @eggs{3}';
is $recipe.ingredients[1].gist, '@sugar{150%g}',        'Ingredient 2 is item: @sugar{150%g}';
# No empty lines, so it is all one step (a paragraph), with line breaks as spaces
is $recipe.steps.elems,        1,                    'Steps: one paragraph';
is $recipe.steps[0][0]<value>, 'Banana cake Whip ',  'Step 1 part 1 is: Banana cake Whip ';
is $recipe.steps[0][1]<name>,  'eggs',               'Step 1 part 2 name is: eggs';
is $recipe.steps[0][2]<value>, ' together with ',    'Step 1 part 3 is:  together with ';




done-testing;
