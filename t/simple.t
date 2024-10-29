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
#note "Input text:\n{$source}\n";

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
#is $recipe.ingredients[0]<quantity>,   3;
is $recipe.parts[8].WHAT, Cooklang::Cookware, 'Part 7 type is: Cooklang::Cookware';
is $recipe.parts[8].orig, '#bowl{}',          'Part 7 has orig: bowl{}';
is $recipe.parts[8].gist, '#bowl{}',          'Part 7 has gist: bowl{}';

is $recipe.ingredients[0].orig, '@eggs{3}',        'Ingredient 1 is item: @eggs{3}';
is $recipe.ingredients[1].gist, '@sugar{150%g}',        'Ingredient 2 is item: @sugar{150%g}';
#$recipe.steps.raku.note;
is $recipe.steps[0][0]<value>, 'Banana cake',        'Step 1 is: Banana cake';
is $recipe.steps[1][0]<value>, 'Whip ',              'Step 2 is: Whip ';
is $recipe.steps[1][1]<name>,  'eggs',               'Step 3 name is:  eggs';
is $recipe.steps[1][2]<value>, ' together with ',    'Step 4 is:  together with ';

#is $recipe.cookware[0].gist, '#bowl{}',          'Cookware 1 has gist: bowl{}';

#$recipe.parts>>.gist.join("").note;
#note $recipe.match.made;
#note $recipe.match;
#is $recipe.ingredients[0],   3;
#is $recipe.ingredients[0],   3;
#is $recipe.ingredients[1]<quantity>, 150;
#is $recipe.ingredients[2]<quantity>, "2-3";
#note("");
#note("Ingredient (#1): {.<quantity>} {.<units>} {.<name>}") for $recipe.ingredients.list;

#$recipe = Cooklang.new( recipe => $source, factor => 5 );
#is $recipe.ingredients[0]<quantity>,  15;
#is $recipe.ingredients[1]<quantity>, 750;
#is $recipe.ingredients[2]<quantity>, "2-3 * 5";  # "10-15" would be better
#note("");
#note("Ingredient (#2): {.<quantity>} {.<units>} {.<name>}") for $recipe.ingredients.list;
#note("Ingredient (sorted): {.<quantity>} {.<units>} {.<name>}") for $recipe.ingredients.sort;
#note("Ingredient (sorted by name): {.<quantity>} {.<units>} {.<name>}") for $recipe.ingredients.sort(by => [<name>]);
#note("Ingredient (sorted by units, quantity, name): {.<quantity>} {.<units>} {.<name>}") for $recipe.ingredients.sort(by => [<units quantity name>]);

done-testing;
