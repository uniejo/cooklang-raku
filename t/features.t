#!/usr/bin/env raku
use v6;
use Test;
use lib 'lib';
use Cooklang;

# Made-up recipes (t/data) that use many features of the parser

sub recipe ( Str $name, *%args ) {
    return Cooklang.new( recipe_file => "t/data/$name.cook", |%args );
}
sub items ( @items ) {
    return @items.map({ ( .name, .quantity, .units // '' ) }).List;
}
sub timers ( $recipe ) {
    return items $recipe.parts.grep(Cooklang::Timer);
}

subtest 'Weekend brunch: YAML front matter, optional, fixed and servings' => {
    my $recipe = recipe('weekend_brunch');
    is-deeply $recipe.metadata, %( title => 'Weekend Brunch', servings => 2, tags => ['breakfast', 'eggs'] ), 'metadata';
    is-deeply items($recipe.ingredients), (
        ('eggs', 4, ''), ('milk', 100, 'ml'), ('chives', 1, 'tbsp'), ('salt', 1, 'pinch'), ('pepper', 'some', ''),
        ('butter', 1.5, 'tbsp'), ('bread', 4, 'slices'), ('smoked salmon', 100, 'g'),
    ), 'ingredients';
    is-deeply $recipe.ingredients.grep(*.optional)».name.List, ('chives', 'smoked salmon'), 'optional ingredients';
    is-deeply $recipe.ingredients.grep(*.fixed)».name.List, ('salt',), 'fixed ingredients';
    is $recipe.ingredients[2].note, 'finely chopped', 'note';
    is-deeply $recipe.cookware.map({ ( .name, .quantity, so .optional ) }).List,
        (('frying pan', 1, False), ('warm plate', 1, True)), 'cookware';
    is-deeply timers($recipe), (('', '3-4', 'minutes'),), 'timer with a range';
    is-deeply $recipe.comments».value.List, ('Serve warm', 'low heat'), 'line and block comments';
    is $recipe.steps.elems, 3, 'steps';
    is-deeply $recipe.ingredients[2, 3, 5]».human.List,
        ('1 tbsp chives (optional)', '1 pinch salt', '1.5 tbsp butter'), 'human ingredients';
    is $recipe.cook, 't/data/weekend_brunch.cook'.IO.slurp, 'cook round-trip';

    # The recipe is for 2 servings
    $recipe.servings = 4;
    is $recipe.factor, 2, 'servings 4: factor';
    is-deeply items($recipe.ingredients), (
        ('eggs', 8, ''), ('milk', 200, 'ml'), ('chives', 2, 'tbsp'), ('salt', 1, 'pinch'), ('pepper', 'some', ''),
        ('butter', 3, 'tbsp'), ('bread', 8, 'slices'), ('smoked salmon', 200, 'g'),
    ), 'servings 4: ingredients scaled, except the fixed salt';
    is-deeply $recipe.cookware».quantity.List, (1, 1), 'servings 4: cookware not scaled';
    is-deeply timers($recipe), (('', '3-4', 'minutes'),), 'servings 4: timer not scaled';

    $recipe = recipe('weekend_brunch', servings => 1);
    is $recipe.ingredients[0].quantity, 2, 'servings 1 in constructor: eggs halved';
}

subtest 'Pesto: >> metadata, ranges, fractions, comments and line breaks' => {
    my $recipe = recipe('pesto');
    is-deeply $recipe.metadata, %( source => 'made up for the tests', 'time required' => '15 minutes' ), 'metadata';
    is-deeply items($recipe.ingredients), (
        ('pine nuts', '2-3', 'tbsp'), ('basil', 2, 'cups'), ('garlic', '1-2', 'cloves'), ('parmesan', 0.5, 'cup'),
        ('olive oil', 1/3, 'cup'), ('salt', 'some', ''), ('lemon juice', 0.5, 'tsp'),
    ), 'ingredients';
    is-deeply $recipe.comments».value.List, ('or a bit more',), 'comment at the end of a line';
    is $recipe.steps.elems, 3, 'steps';
    is $recipe.steps(data-type => 'human')[0].join,
        "Toast 2-3 tbsp pine nuts in pan for 2 minutes.\nWatch them closely.", 'backslash keeps the line break';
    is $recipe.steps(data-type => 'human')[1].join,
        "Blend 2 cups basil, 1-2 cloves garlic, 0.5 cup parmesan and the pine nuts. Add 0.333333 cup olive oil slowly  while blending.",
        'single line breaks become spaces, the comment is left out';
    like $recipe.human, / 'minutes.' \n 'Watch' /, 'human(): no backslash';
    is $recipe.cook, 't/data/pesto.cook'.IO.slurp, 'cook round-trip';

    $recipe.factor = 2;
    is-deeply items($recipe.ingredients), (
        ('pine nuts', '4-6', 'tbsp'), ('basil', 4, 'cups'), ('garlic', '2-4', 'cloves'), ('parmesan', 1, 'cup'),
        ('olive oil', 2/3, 'cup'), ('salt', 'some', ''), ('lemon juice', 1, 'tsp'),
    ), 'factor 2: ranges and fractions scaled';
}

done-testing;
