#!/usr/bin/env raku
use v6;
use Test;
use lib 'lib';
use Cooklang;

subtest 'human() works and does not print debug output' => {
    my $out = '';
    {
        my $*OUT = class { method print(*@a) { $out ~= @a.join }; method flush {} }.new;
        my $recipe = Cooklang.new( recipe => "Add \@salt\{2%tsp} and \@egg\{1}.\n" );
        is $recipe.ingredients[0].human, '2 tsp salt', 'human: no plural of name when units are given';
        is $recipe.ingredients[1].human, '1 egg',       'human: singular';
    }
    is $out, '', 'No debug output on STDOUT';
}

subtest 'Factor is kept when the recipe changes' => {
    my $recipe = Cooklang.new( recipe => "Add \@salt\{2%tsp}.\n" );
    $recipe.factor = 3;
    is $recipe.ingredients[0].measurement.number, 6, 'Factor applied after setting factor';
    $recipe.recipe = "Add \@sugar\{2%tsp}.\n";
    is $recipe.ingredients[0].measurement.number, 6, 'Factor kept after changing recipe';

    $recipe = Cooklang.new( factor => 2, recipe => "Add \@sugar\{5%g}.\n" );
    is $recipe.ingredients[0].measurement.number, 10, 'Factor given with recipe in constructor';
}

subtest 'Ingredient note is kept' => {
    my $recipe = Cooklang.new( recipe => "Add \@salt\{2%tsp;fine}.\n" );
    is $recipe.ingredients[0].note, 'fine', 'Ingredient note kept';
    is $recipe.ingredients[0].units, 'tsp', 'Units not affected by note';
}

subtest 'Recipe loaded from file in the constructor is kept, so factor can be changed' => {
    my $file = $*TMPDIR.add("cooklang-fixes-$*PID.cook");
    $file.spurt("Add \@salt\{2%g}.\n");
    my $recipe = Cooklang.new( recipe_file => $file );
    ok $recipe.recipe.defined, 'Recipe text kept after loading from file';
    $recipe.factor = 3;
    is $recipe.ingredients[0].measurement.number, 6, 'Factor applied to recipe from file';
    $file.unlink;
}

subtest 'steps_flat only returns step parts (no metadata or comments)' => {
    my $recipe = Cooklang.new( recipe => ">> title: X\nAdd \@salt\{1}. -- note\n" );
    is-deeply $recipe.steps_flat.map(*.<type>).List, <text ingredient text>, 'steps_flat: only step parts';
    is-deeply $recipe.steps_flat.map({ .<value> // .<name> }).List, ('Add ', 'salt', '. '), 'steps_flat: content';

    $recipe = Cooklang.new( recipe => "Add \@salt.\nStir.\n" );
    is $recipe.steps_flat[*-1]<value>, '. Stir.', 'steps_flat: a line break is a space';
    $recipe = Cooklang.new( recipe => "Add \@salt.\n\n\nStir. \\\nBake.\n" );
    is $recipe.steps_flat[*-1]<value>, ". Stir.\nBake.", 'steps_flat: steps joined by a space, backslash keeps the line break';
    is-deeply Cooklang.new( recipe => "" ).steps_flat, [], 'steps_flat: empty recipe';
}

subtest 'Timer without a name is not pluralised' => {
    my $recipe = Cooklang.new( recipe => "Wait ~\{5%min}.\n" );
    is $recipe.human, "Wait 5 min.\n", 'Unnamed timer: no plural "s"';
}

subtest 'A list of recipe files is joined before parsing' => {
    my $recipe = Cooklang.new( recipe_file => <t/data/easy_pancakes.cook t/data/aloo_curry.cook> );
    is $recipe.metadata<source>, 'https://www.indianhealthyrecipes.com/potato-curry-aloo-sabzi/', 'Files: metadata from second file';
    is $recipe.ingredients[0].name, 'eggs',    'Files: first ingredient from first file';
    is $recipe.ingredients[*-1].name, 'coriander leaves', 'Files: last ingredient from second file';
    is $recipe.cookware.elems, 2, 'Files: cookware';
}

subtest 'cook() returns the original recipe text unchanged' => {
    for |dir('t/data', test => /'.cook'$/), |dir('t/spec/examples', test => /'.cook'$/) -> $f {
        my $src = $f.slurp;
        is Cooklang.new( recipe => $src ).cook, $src, "cook: round-trip of {$f.basename}";
    }
    my $src = "---\ntitle: X\n---\n-- hi\nAdd \@salt\{1%g}. [- block -]\nStir.\n";
    my $recipe = Cooklang.new( recipe => $src );
    is $recipe.cook, $src, 'cook: front matter and comments kept';
    is-deeply $recipe.metadata, %( title => 'X' ), 'cook: front matter markers not in metadata';
    is $recipe.human, "( title X )\n\n( hi )\nAdd 1 g salt. ( block )\nStir.\n", 'human: front matter markers hidden, one line per metadata and comment line';
}

subtest 'Measurement has the CookBase methods' => {
    my $m = Cooklang::Measurement.new( quantity => 2, units => 'g', orig => '{2%g}' );
    is $m.type, 'measurement', 'Measurement: type';
    is-deeply $m.data, %( quantity => 2, units => 'g', orig => '{2%g}', type => 'measurement' ), 'Measurement: data';
    is $m.gist, '{2%g}', 'Measurement: gist';
}

subtest 'Parts can be read as hashes' => {
    my $ingredient = Cooklang.new( recipe => "Add \@salt\{1%tsp}.\n" ).ingredients[0];
    is $ingredient<name>, 'salt', 'Hash access: attribute';
    is $ingredient<measurement><units>, 'tsp', 'Hash access: nested';
    is $ingredient<quantity>, Nil, 'Hash access: method, not attribute, is Nil';
    is $ingredient<nope>, Nil, 'Hash access: missing key is Nil';
}

subtest 'Methods are inherited by subclasses' => {
    my class MyCooklang is Cooklang { }
    my $recipe = MyCooklang.new( recipe => "Add \@salt\{1}.\n" );
    is $recipe.ingredients[0].name, 'salt', 'Subclass: parts() is inherited';
    my class MyIngredient is Cooklang::Ingredient { }
    is MyIngredient.new( name => 'salt', orig => '@salt' ).cook, '@salt', 'Subclass: cook() is inherited';
}

subtest 'Empty recipe gives empty data, not an undefined value' => {
    is-deeply Cooklang.new( recipe => "" ).data, %( metadata => {}, steps => [] ), 'Empty recipe: empty data';
}

subtest 'Optional ingredients and cookware are marked in human()' => {
    my $src = "Season with \@salt and \@?chilli powder\{1%pinch}.\nUse a #?splatter guard\{} or #pan.\n";
    my $recipe = Cooklang.new( recipe => $src );
    is $recipe.ingredients[0].human, 'some salt',                     'human: required ingredient';
    is $recipe.ingredients[1].human, '1 pinch chilli powder (optional)', 'human: optional ingredient';
    is $recipe.cookware[0].human,    'splatter guard (optional)',        'human: optional cookware';
    is $recipe.cookware[1].human,    'pan',                              'human: required cookware, no quantity given';
    is Cooklang.new( recipe => "Use #pan\{2}.\n" ).cookware[0].human, '2 pans', 'human: cookware with a quantity';
    is $recipe.cook, $src, 'cook: optional marker kept';
}

subtest 'Plural of names' => {
    my $recipe = Cooklang.new( recipe => "\@egg\{2} \@eggs\{3} \@chilli flakes\{1%pinch} \@asparagus\{1%bunch} \@hummus\{1}.\n" );
    is-deeply $recipe.ingredients>>.human.List,
        ('2 eggs', '3 eggs', '1 pinch chilli flakes', '1 bunch asparagus', '1 hummus'),
        'human: plural "s" only added when needed, never removed';
}

subtest 'a/an when no quantity is given (cookware without a quantity)' => {
    my $mw = Cooklang::Measurement.new( number => 1 );
    is $mw.human('onion'),  'an onion',  'human: "an" before vowel';
    is $mw.human('yogurt'), 'a yogurt',  'human: "a" before y';
    is $mw.human('pan'),    'a pan',     'human: "a" before consonant';
}

subtest 'A metadata key does not continue on the next line' => {
    my $recipe = Cooklang.new( recipe => ">> no colon here\nAdd salt: now\n" );
    is-deeply $recipe.metadata, %(), 'Metadata: no key across lines';
    is $recipe.steps[0][0]<value>, '>> no colon here Add salt: now', 'Metadata: line without colon is text';
}

subtest 'A front matter block that does not match leaves no metadata behind' => {
    my $src = "---\ntitle: X\nbad line\n---\nStep.\n";
    my $recipe = Cooklang.new( recipe => $src );
    is-deeply $recipe.metadata, %(), 'Front matter: no partial metadata';
    is $recipe.cook, $src, 'Front matter: cook round-trip';
}

subtest 'Front matter is YAML' => {
    my $src = q:to/END/;
    ---
    title: Pancakes
    servings: 4
    # a comment
    tags: [breakfast, sweet]
    equipment:
      - pan
      - whisk
    nutrition:
      kcal: 300
    ---
    Mix.
    END
    my $recipe = Cooklang.new( recipe => $src );
    is-deeply $recipe.metadata,
        %( title => 'Pancakes', servings => 4, tags => ['breakfast', 'sweet'],
           equipment => ['pan', 'whisk'], nutrition => { kcal => 300 } ),
        'YAML front matter: lists, maps and numbers';
    is-deeply $recipe.parts.grep(Cooklang::Metadata)».meta_key.List,
        <title servings tags equipment nutrition>, 'YAML front matter: keys in source order';
    is $recipe.cook, $src, 'YAML front matter: cook round-trip';
    like $recipe.human, /'( tags breakfast, sweet )'/, 'YAML front matter: human() joins lists';
}

subtest "Front matter that YAML does not accept, but is simple 'key: value' lines" => {
    is-deeply Cooklang.new( recipe => "---\nnotes:\ntitle: X\n---\n" ).metadata,
        %( notes => '', title => 'X' ), 'Front matter: key without a value';
    is-deeply Cooklang.new( recipe => "---\n---\nStep.\n" ).metadata, %(), 'Front matter: empty block';
}

subtest 'Scaling (spec proposal 0010): fixed quantities, cookware and timers are not scaled' => {
    my $src = "Add \@milk\{1/2%cup} and \@salt\{=1%tsp} to #pan\{2}, wait ~\{10%min}.\n";
    my $recipe = Cooklang.new( recipe => $src, factor => 2 );
    is $recipe.ingredients[0].quantity, 1, 'Scaling: ingredient scaled';
    is $recipe.ingredients[1].quantity, 1, 'Scaling: fixed quantity not scaled';
    ok $recipe.ingredients[1].fixed, 'Scaling: fixed quantity is marked';
    nok $recipe.ingredients[0].fixed, 'Scaling: scaled quantity is not marked';
    is $recipe.cookware[0].quantity, 2, 'Scaling: cookware not scaled';
    is $recipe.parts.first(Cooklang::Timer).quantity, 10, 'Scaling: timer not scaled';
    is $recipe.cook, $src, 'Scaling: cook keeps the original';
}

subtest "Scale to servings, relative to the 'servings' metadata (default 1)" => {
    my $src = "---\nservings: 2\n---\nAdd \@milk\{1/2%cup}.\n";
    my $recipe = Cooklang.new( recipe => $src, servings => 4 );
    is $recipe.factor, 2, 'Servings: factor from constructor';
    is $recipe.ingredients[0].quantity, 1, 'Servings: quantity scaled';
    $recipe.servings = 1;
    is $recipe.ingredients[0].quantity, 0.25, 'Servings: changed later';
    is Cooklang.new( recipe => "Add \@egg\{1}.\n", servings => 3 ).ingredients[0].quantity, 3, 'Servings: no metadata means 1 serving';
    is Cooklang.new( recipe => "---\nservings: 2|4|6\n---\nAdd \@egg\{1}.\n", servings => 4 ).factor, 2, 'Servings: old style 2|4|6 uses the first';
}

subtest "Metadata keys are case-insensitive, and 'serves' is 'servings' (spec proposal 0007)" => {
    is-deeply Cooklang.new( recipe => ">> servings: 2\n>> Servings: 4\nAdd salt.\n" ).metadata,
        %( Servings => '4' ), 'Metadata: the latest key wins, whatever its case';
    is Cooklang.new( recipe => "---\nServings: 2\n---\nAdd \@egg\{1}.\n", servings => 4 ).factor, 2, "Servings: 'Servings'";
    is Cooklang.new( recipe => "---\nserves: 2\n---\nAdd \@egg\{1}.\n", servings => 4 ).factor, 2, "Servings: 'serves'";
}

subtest "Only the first '?' is the optional marker (spec proposal 0018)" => {
    my $recipe = Cooklang.new( recipe => "Add \@??thyme, \@?sage and \@? basil. Use #??lid. Did you add the \@salt\{}?\n" );
    is-deeply $recipe.ingredients.map({ ( .name, so .optional ) }).List,
        (('?thyme', True), ('sage', True), ('salt', False)), "Optional: '\@??thyme' is '?thyme', '\@? basil' is text";
    is-deeply $recipe.cookware.map({ ( .name, so .optional ) }).List, (('?lid', True),), "Optional: '#??lid' is '?lid'";
    is $recipe.cook, "Add \@??thyme, \@?sage and \@? basil. Use #??lid. Did you add the \@salt\{}?\n", 'Optional: cook round-trip';
}

subtest 'Timer names are not shown in human()' => {
    is Cooklang.new( recipe => "Boil \@eggs\{2} for ~eggs\{3%minutes}.\n" ).human, "Boil 2 eggs for 3 minutes.\n", 'Named timer: duration only';
    is Cooklang.new( recipe => "Wait ~?\{5%minutes}.\n" ).human, "Wait 5 minutes.\n", "Timer named '?': duration only";
    is Cooklang.new( recipe => "Wait for the ~bell.\n" ).human, "Wait for the bell.\n", 'Timer without a duration: name';
}

subtest 'An amount does not continue on the next line' => {
    my $src = "Add \@salt\{ and stir\nwell} please.\n";
    my $recipe = Cooklang.new( recipe => $src );
    is-deeply $recipe.ingredients.map({ ( .name, .quantity ) }).List, (('salt', 'some'),), 'Amount: not across lines';
    is $recipe.steps[0][2]<value>, '{ and stir well} please.', 'Amount: unclosed brace is text';
    is $recipe.cook, $src, 'Amount: cook round-trip';
}

subtest "'\@' starts an ingredient anywhere, also in an email address (spec)" => {
    is-deeply Cooklang.new( recipe => "email me\@example.com\n" ).ingredients».name.List, ('example',), 'Email address: "example" is an ingredient';
}

subtest "An unclosed '\{' is kept as text, not a parse error" => {
    my $recipe = Cooklang.new( recipe => "Add \@salt\{1%tsp" );
    is-deeply $recipe.ingredients.map({ ( .name, .quantity ) }).List, (('salt', 'some'),), 'Unclosed brace: item without amount';
    is $recipe.steps[0][2]<value>, '{1%tsp', 'Unclosed brace: rest is text';
}

subtest 'A block comment can span lines (spec EBNF)' => {
    is Cooklang.new( recipe => "A [- one\ntwo -] B\n" ).comments[0].value, "one\ntwo", 'Block comment across lines';
}

subtest 'Parse errors are reported' => {
    my $e = Cooklang::ParseError.new( line => 3, near => '@x' );
    isa-ok $e, Exception, 'ParseError is an Exception';
    is $e.message, "Unable to parse recipe at line 3 near '\@x'", 'ParseError: message';
}

done-testing;
