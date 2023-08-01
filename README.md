NAME
====

Cooklang - `Raku` `Cooklang` parser

SYNOPSIS
========

```raku
    use Cooklang;
    ...
    my $source = "some Cooklang text";
    my $recipe = Cooklang.new( recipe => $source );
    ...
    my $file = 'recipe.cook';
    my $recipe = Cooklang.new( recipe_file => $file );
    ...
    my $files = [ 'recipe1.cook', 'recipe2.cook' ];
    my $recipe = Cooklang.new( recipe_file => $files );
    # Currently does a simple join of all files, before parsing.
    ...
    my $metadata = $recipe.metadata;
    my $ingredients = $recipe.ingredients;
    my $steps = $recipe.steps;
    my $ast = $recipe.ast;
    my $ast_tree = $recipe.match;
```

VERSION
=======

    version 1.0.4

AVAILABILITY
============

Cooklang is implemented in `Raku` using grammer and grammar action to parse and build AST tree.

DESCRIPTION
===========

For the `Cooklang` syntax, see [Cooklang](https://cooklang.org/).

DOCUMENTATION
=============

Cooklang documentation is available as `POD6`. You can run `raku --doc` from a shell to read the documentation:

        % raku --doc lib/Cooklang.rakumod
        % raku --doc=Markdown lib/Cooklang.rakumod     # zef install Pod::To::Markdown
        % raku --doc=HTML lib/Cooklang.rakumod         # zef install Pod::To::HTML

INSTALLATION
============

Installing Cooklang is straightforward.

## Installation with zef from CPAN6

If you have zef, you only need one line:

        % zef install Cooklang

## Installation with zef from git repository

        % zef install https://github.com/uniejo/cooklang-raku.git

COMMUNITY
=========

- [Code repository Wiki and Issue Tracker](https://github.com/uniejo/cooklang-raku)

AUTHOR
======

Erik Johansen - uniejo@users.noreply.github.com

COPYRIGHT
=========

Erik Johansen 2023

LICENSE
=======

This software is licensed under the same terms as Perl itself.

