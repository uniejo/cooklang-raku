# NAME

Cooklang - Perl Cooklang parser

# SYNOPSIS

    use Cooklang;
    ...
    my $source = "some Cooklang text";
    my $recipe = Cooklang.new( recipe => $source );
    ...
    my $file = 'recipe.cook';
    my $recipe = Cooklang.new( recipe_file => $file );
    ...
    my $metadata = $recipe.metadata;
    my $ingredients = $recipe.ingredients;
    my $steps = $recipe.steps;
    my $ast = $recipe.ast;

# AVAILABILITY

Cooklang is implemented in Raku using grammer and grammar action to parse and build AST tree.

# DESCRIPTION

For the Cooklang syntax, see [Cooklang](https://cooklang.org/).

# COMMUNITY

- [Code repository Wiki and Issue Tracker](https://github.com/uniejo/cooklang-raku)

# AUTHOR

Erik Johansen

# COPYRIGHT

Erik Johansen 2023 -

# LICENSE

This software is licensed under the same terms as Perl itself.

# SEE ALSO

