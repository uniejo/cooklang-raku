#!/usr/bin/env raku
use v6;
use Test;
use lib 'lib';
use Cooklang;

# human() works and does not print debug output
my $out = '';
{
    my $*OUT = class { method print(*@a) { $out ~= @a.join }; method flush {} }.new;
    my $recipe = Cooklang.new( recipe => "Add \@salt\{2%tsp} and \@egg\{1}.\n" );
    is $recipe.ingredients[0].human, '2 tsp salt', 'human: no plural of name when units are given';
    is $recipe.ingredients[1].human, '1 egg',       'human: singular';
}
is $out, '', 'No debug output on STDOUT';

# Factor is kept when the recipe changes
my $recipe = Cooklang.new( recipe => "Add \@salt\{2%tsp}.\n" );
$recipe.factor = 3;
is $recipe.ingredients[0].measurement.number, 6, 'Factor applied after setting factor';
$recipe.recipe = "Add \@sugar\{2%tsp}.\n";
is $recipe.ingredients[0].measurement.number, 6, 'Factor kept after changing recipe';

$recipe = Cooklang.new( factor => 2, recipe => "Add \@sugar\{5%g}.\n" );
is $recipe.ingredients[0].measurement.number, 10, 'Factor given with recipe in constructor';

# Ingredient note is kept
$recipe = Cooklang.new( recipe => "Add \@salt\{2%tsp;fine}.\n" );
is $recipe.ingredients[0].note, 'fine', 'Ingredient note kept';
is $recipe.ingredients[0].units, 'tsp', 'Units not affected by note';

# Recipe loaded from file in the constructor is kept, so factor can be changed
my $file = $*TMPDIR.add("cooklang-fixes-$*PID.cook");
$file.spurt("Add \@salt\{2%g}.\n");
$recipe = Cooklang.new( recipe_file => $file );
ok $recipe.recipe.defined, 'Recipe text kept after loading from file';
$recipe.factor = 3;
is $recipe.ingredients[0].measurement.number, 6, 'Factor applied to recipe from file';
$file.unlink;

# steps_flat only returns step parts (no metadata or comments)
$recipe = Cooklang.new( recipe => ">> title: X\nAdd \@salt\{1}. -- note\n" );
is-deeply $recipe.steps_flat.map(*.<type>).List, <text ingredient text>, 'steps_flat: only step parts';

# Timer without a name is not pluralised
$recipe = Cooklang.new( recipe => "Wait ~\{5%min}.\n" );
is $recipe.human, "Wait 5 min.\n", 'Unnamed timer: no plural "s"';

# A list of recipe files is joined before parsing
$recipe = Cooklang.new( recipe_file => <t/data/easy_pancakes.cook t/data/aloo_curry.cook> );
is $recipe.metadata<source>, 'https://www.indianhealthyrecipes.com/potato-curry-aloo-sabzi/', 'Files: metadata from second file';
is $recipe.ingredients[0].name, 'eggs',    'Files: first ingredient from first file';
is $recipe.ingredients[*-1].name, 'coriander leaves', 'Files: last ingredient from second file';
is $recipe.cookware.elems, 2, 'Files: cookware';

# cook() returns the original recipe text unchanged
for |dir('t/data', test => /'.cook'$/), |dir('t/spec/examples', test => /'.cook'$/) -> $f {
    my $src = $f.slurp;
    is Cooklang.new( recipe => $src ).cook, $src, "cook: round-trip of {$f.basename}";
}
my $src = "---\ntitle: X\n---\n-- hi\nAdd \@salt\{1%g}. [- block -]\nStir.\n";
$recipe = Cooklang.new( recipe => $src );
is $recipe.cook, $src, 'cook: front matter and comments kept';
is-deeply $recipe.metadata, %( title => 'X' ), 'cook: front matter markers not in metadata';
is $recipe.human, "( title X )\n( hi )Add 1 g salt. ( block )\nStir.\n", 'human: front matter markers hidden';

# Measurement has the CookBase methods
my $m = Cooklang::Measurement.new( quantity => 2, units => 'g', orig => '{2%g}' );
is $m.type, 'measurement', 'Measurement: type';
is-deeply $m.data, %( quantity => 2, units => 'g', orig => '{2%g}', type => 'measurement' ), 'Measurement: data';
is $m.gist, '{2%g}', 'Measurement: gist';

# Methods are inherited by subclasses
class MyCooklang is Cooklang { }
$recipe = MyCooklang.new( recipe => "Add \@salt\{1}.\n" );
is $recipe.ingredients[0].name, 'salt', 'Subclass: parts() is inherited';
class MyIngredient is Cooklang::Ingredient { }
is MyIngredient.new( name => 'salt', orig => '@salt' ).cook, '@salt', 'Subclass: cook() is inherited';

# Empty recipe gives empty data, not an undefined value
is-deeply Cooklang.new( recipe => "" ).data, %( metadata => {}, steps => [] ), 'Empty recipe: empty data';

# Optional ingredients and cookware are marked in human()
$src = "Season with \@salt and \@?chilli powder\{1%pinch}.\nUse a #?splatter guard\{} or #pan.\n";
$recipe = Cooklang.new( recipe => $src );
is $recipe.ingredients[0].human, 'some salt',                     'human: required ingredient';
is $recipe.ingredients[1].human, '1 pinch chilli powder (optional)', 'human: optional ingredient';
is $recipe.cookware[0].human,    '1 splatter guard (optional)',      'human: optional cookware';
is $recipe.cookware[1].human,    '1 pan',                            'human: required cookware';
is $recipe.cook, $src, 'cook: optional marker kept';

# Plural of names
$recipe = Cooklang.new( recipe => "\@egg\{2} \@eggs\{3} \@chilli flakes\{1%pinch} \@asparagus\{1%bunch} \@hummus\{1}.\n" );
is-deeply $recipe.ingredients>>.human.List,
    ('2 eggs', '3 eggs', '1 pinch chilli flakes', '1 bunch asparagus', '1 hummus'),
    'human: plural "s" only added when needed, never removed';

# a/an when no quantity is given (cookware without a quantity)
my $mw = Cooklang::Measurement.new( number => 1 );
is $mw.human('onion'),  'an onion',  'human: "an" before vowel';
is $mw.human('yogurt'), 'a yogurt',  'human: "a" before y';
is $mw.human('pan'),    'a pan',     'human: "a" before consonant';

# A metadata key does not continue on the next line
$recipe = Cooklang.new( recipe => ">> no colon here\nAdd salt: now\n" );
is-deeply $recipe.metadata, %(), 'Metadata: no key across lines';
is $recipe.steps[0][0]<value>, '>> no colon here Add salt: now', 'Metadata: line without colon is text';

# A front matter block that does not match leaves no metadata behind
$src = "---\ntitle: X\nbad line\n---\nStep.\n";
$recipe = Cooklang.new( recipe => $src );
is-deeply $recipe.metadata, %(), 'Front matter: no partial metadata';
is $recipe.cook, $src, 'Front matter: cook round-trip';

# Front matter is YAML
$src = q:to/END/;
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
$recipe = Cooklang.new( recipe => $src );
is-deeply $recipe.metadata,
    %( title => 'Pancakes', servings => 4, tags => ['breakfast', 'sweet'],
       equipment => ['pan', 'whisk'], nutrition => { kcal => 300 } ),
    'YAML front matter: lists, maps and numbers';
is-deeply $recipe.parts.grep(Cooklang::Metadata)».meta_key.List,
    <title servings tags equipment nutrition>, 'YAML front matter: keys in source order';
is $recipe.cook, $src, 'YAML front matter: cook round-trip';
like $recipe.human, /'( tags breakfast, sweet )'/, 'YAML front matter: human() joins lists';

# Front matter that YAML does not accept, but is simple 'key: value' lines
is-deeply Cooklang.new( recipe => "---\nnotes:\ntitle: X\n---\n" ).metadata,
    %( notes => '', title => 'X' ), 'Front matter: key without a value';
is-deeply Cooklang.new( recipe => "---\n---\nStep.\n" ).metadata, %(), 'Front matter: empty block';

# Parse errors are reported
my $e = Cooklang::ParseError.new( line => 3, near => '@x' );
isa-ok $e, Exception, 'ParseError is an Exception';
is $e.message, "Unable to parse recipe at line 3 near '\@x'", 'ParseError: message';

done-testing;
