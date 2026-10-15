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

is $recipe.match.made[1].WHAT, Cooklang::Step, 'match.made[1]: type Step';
is $recipe.match.made[1].orig, 'Banana cake',  'match.made[1]: orig "Banana cake"';

is $recipe.parts[0].WHAT, Cooklang::Vertical,   'parts[0]: type Vertical';
is $recipe.parts[0].orig, "\n",                 'parts[0]: orig is a line break';
is $recipe.parts[0].gist, "\n",                 'parts[0]: gist is a line break';
is $recipe.parts[1].WHAT, Cooklang::Step,       'parts[1]: type Step';
is $recipe.parts[1].orig, 'Banana cake',        'parts[1]: orig "Banana cake"';
is $recipe.parts[1].gist, 'Banana cake',        'parts[1]: gist "Banana cake"';
is $recipe.parts[2].WHAT, Cooklang::Vertical,   'parts[2]: type Vertical';
is $recipe.parts[2].orig, "\n",                 'parts[2]: orig is a line break';
is $recipe.parts[2].gist, "\n",                 'parts[2]: gist is a line break';
is $recipe.parts[3].WHAT, Cooklang::Step,       'parts[3]: type Step';
is $recipe.parts[3].orig, 'Whip ',              'parts[3]: orig "Whip "';
is $recipe.parts[3].gist, 'Whip ',              'parts[3]: gist "Whip "';
is $recipe.parts[4].WHAT, Cooklang::Ingredient, 'parts[4]: type Ingredient';
is $recipe.parts[4].orig, '@eggs{3}',           'parts[4]: orig "@eggs{3}"';
is $recipe.parts[4].gist, '@eggs{3}',           'parts[4]: gist "@eggs{3}"';
is $recipe.parts[4].quantity, 3,                'parts[4]: quantity 3';
is $recipe.parts[8].WHAT, Cooklang::Cookware,   'parts[8]: type Cookware';
is $recipe.parts[8].orig, '#bowl{}',            'parts[8]: orig "#bowl{}"';
is $recipe.parts[8].gist, '#bowl{}',            'parts[8]: gist "#bowl{}"';

is $recipe.ingredients[0].orig, '@eggs{3}',      'ingredients[0]: orig "@eggs{3}"';
is $recipe.ingredients[1].gist, '@sugar{150%g}', 'ingredients[1]: gist "@sugar{150%g}"';
# No empty lines, so it is all one step (a paragraph), with line breaks as spaces
is $recipe.steps.elems,        1,                   'steps: one paragraph';
is $recipe.steps[0][0]<value>, 'Banana cake Whip ', 'steps[0][0]: text "Banana cake Whip "';
is $recipe.steps[0][1]<name>,  'eggs',              'steps[0][1]: ingredient "eggs"';
is $recipe.steps[0][2]<value>, ' together with ',   'steps[0][2]: text " together with "';

done-testing;
