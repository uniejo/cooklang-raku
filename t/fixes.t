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
    is $recipe.ingredients[0].human, '2 tsp salts', 'human: plural';
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

done-testing;
