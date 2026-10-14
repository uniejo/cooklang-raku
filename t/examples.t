#!/usr/bin/env raku
use v6;
use Test;
use lib 'lib';
use Cooklang;

# The example recipes from the Cooklang specification (t/spec/examples)

sub recipe ( Str $name, *%args ) {
    return Cooklang.new( recipe_file => "t/spec/examples/$name.cook", |%args );
}
sub items ( @items ) {
    return @items.map({ ( .name, .quantity, .units // '' ) }).List;
}
sub timers ( $recipe ) {
    return items $recipe.parts.grep(Cooklang::Timer);
}

subtest 'Easy Pancakes' => {
    my $recipe = recipe('Easy Pancakes');
    is-deeply items($recipe.ingredients), (
        ('eggs', 3, ''), ('flour', 125, 'g'), ('milk', 250, 'ml'), ('sea salt', 1, 'pinch'), ('oil', 'some', ''),
    ), 'ingredients';
    is-deeply $recipe.cookware».name.List, ('bowl', 'large non-stick frying pan'), 'cookware';
    is-deeply timers($recipe), (('', 15, 'minutes'),), 'timers';
    is $recipe.steps.elems, 6, 'steps';
    is $recipe.comments[0].value, 'TODO add source', 'comment';
    is-deeply $recipe.metadata, %(), 'no metadata';
    # 'a' is from the recipe text, '1 bowl' is the cookware with its default quantity
    is $recipe.steps(data-type => 'human')[1].join, 'Pour into a 1 bowl and leave to stand for 15 minutes.', 'human step';

    $recipe.factor = 2;
    is-deeply items($recipe.ingredients[^2]), (('eggs', 6, ''), ('flour', 250, 'g')), 'scaled ingredients';
    is-deeply timers($recipe), (('', 15, 'minutes'),), 'timers not scaled';
}

subtest 'Coffee Souffle' => {
    my $recipe = recipe('Coffee Souffle');
    # Amounts without '%' are kept as text, without units
    is-deeply items($recipe.ingredients), (
        ('egg yoke', 1, ''), ('condenced milk', 125, 'g'), ('instant coffee', '3tsp', ''),
        ('water', '1,1/2cups', ''), ('gelatine', '3tsp', ''), ('eggwhite', 1, ''), ('cashew', 60, 'g'),
    ), 'ingredients';
    is-deeply $recipe.cookware».name.List, ('bowl', 'puddingbowl'), 'cookware';
    is-deeply timers($recipe), (('', 15, 'minutes'),), 'timers';
    is $recipe.steps.elems, 5, 'steps (two blank lines are one step break)';
    is $recipe.comments[0].value, 'make caramel', 'comment';

    $recipe.factor = 2;
    is $recipe.ingredients[2].quantity, '3tsp', 'text amount is not changed when scaled';
    is $recipe.ingredients[2].number, '3tsp * 2', 'text amount shows the factor in number';
}

subtest 'Fried Rice' => {
    my $recipe = recipe('Fried Rice');
    is-deeply items($recipe.ingredients), (
        ('oyster sauce', 1, 'tbsp'), ('soy sauce', 5, 'tbsp'), ('sesame oil', 5, 'tsp'), ('peanut oil', 1, 'tbsp'),
        ('eggs', 2, 'items'), ('bacon', 75, 'cup'), ('peanut oil', 2, 'tbsp'), ('garlic', 2, 'gloves'),
        ('ginger', 3, 'tsp'), ('onion', 2, 'medium'), ('Chinese cooking wine', 1, 'tbsp'), ('sugar', 2, 'tsp'),
        ('prawns', 150, 'g'), ('cooked rice', 3, 'cups'), ('scallions', 5, 'items'), ('scallions', 2, 'items'),
    ), 'ingredients (repeated ingredients are listed each time)';
    is $recipe.cookware.elems, 0, 'no cookware';
    is timers($recipe).elems, 0, 'no timers';
    is $recipe.steps.elems, 9, 'steps';
}

subtest 'Olivier Salad' => {
    my $recipe = recipe('Olivier Salad');
    is-deeply items($recipe.ingredients), (
        ('corn beef', 1, 'kg'), ('potatoes', 3, 'medium'), ('carrots', 3, 'medium'), ('frozen peas', 1, 'cup'),
        ('eggs', 4, ''), ('pickles', 6, ''), ('mayonnaise', 1, 'cup'), ('dill', 1, 'tbsp'),
    ), 'ingredients';
    is-deeply timers($recipe), (('', 2, 'hours'), ('', 30, 'minutes')), 'timers';
    is $recipe.steps.elems, 13, 'steps';
    is $recipe.ingredients[0].human, '1 kg corn beef', 'human ingredient';
}

subtest 'All examples' => {
    for dir('t/spec/examples', test => / '.cook' $ /).sort -> $file {
        my $src = $file.slurp;
        my $recipe = Cooklang.new( recipe => $src );
        is $recipe.cook, $src, "{$file.basename}: cook round-trip";
        my @at = $src.match(/ '@' /, :g)».from;
        is $recipe.ingredients.elems, @at.elems, "{$file.basename}: one ingredient per '\@'";
        ok $recipe.ingredients.map({ $src.contains(.orig) }).all, "{$file.basename}: ingredients are found in the source";
    }
}

done-testing;
