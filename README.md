NAME
====

Cooklang - `Raku` `Cooklang` parser

SYNOPSIS
========

```raku
    use Cooklang;

    # Parse a recipe from text, a file, or a list of files (joined before parsing)
    my $recipe = Cooklang.new( recipe => "Mix @flour{200%g} and @water{1/2%l}.\n" );
    my $recipe = Cooklang.new( recipe_file => 'recipe.cook' );
    my $recipe = Cooklang.new( recipe_file => <recipe1.cook recipe2.cook> );

    # Recipe parts
    my %metadata    = $recipe.metadata;      # Front matter (YAML) and '>> key: value' lines
    my @ingredients = $recipe.ingredients;   # Cooklang::Ingredient objects
    my @cookware    = $recipe.cookware;      # Cooklang::Cookware objects
    my @comments    = $recipe.comments;      # Cooklang::Comment objects
    my @steps       = $recipe.steps;         # Steps (paragraphs) as lists of hashes
    my %data        = $recipe.data;          # { metadata => ..., steps => ... } as in the spec tests
    my $ast_tree    = $recipe.match;         # The grammar match

    # Ingredient details
    for $recipe.ingredients {
        say .name, ' ', .quantity, ' ', .units;
        say .human;                          # "200 g flour"
        say 'optional' if .optional;         # @?name
        say 'not scaled' if .fixed;          # @name{=1%tsp}
    }

    # Scale the recipe
    $recipe.factor   = 2;                    # Double all scalable quantities
    $recipe.servings = 4;                    # Scale to 4 servings (relative to the 'servings' metadata)

    # Output
    say $recipe.human;                       # Readable text
    say $recipe.cook;                        # The original Cooklang text

    # A recipe that can not be parsed throws Cooklang::ParseError
    CATCH { when Cooklang::ParseError { note .message } }
```

VERSION
=======

    version 2.1.0

DESCRIPTION
===========

Cooklang is a markup language for recipes, see [Cooklang](https://cooklang.org/) and the [specification](https://github.com/cooklang/spec).

This module parses a Cooklang recipe with a `Raku` grammar and grammar actions, and gives access to its metadata, ingredients, cookware, timers, comments and steps. The specification tests (`t/spec`, a git submodule of the specification) are part of the test suite.

SUPPORTED SYNTAX
================

  * Ingredients `@salt`, `@ground black pepper{}`, `@potato{2}`, `@flour{200%g}`, with an optional note `@salt{1%tsp;fine}`

  * Cookware `#pot`, `#frying pan{}`, `#pan{2}` (cookware has no units)

  * Timers `~{25%minutes}`, `~eggs{3%minutes}`

  * Quantities as numbers `2`, fractions `1/2`, mixed numbers `1 1/2`, ranges `1-2` or text `a pinch`

  * Steps: paragraphs separated by a blank line; a single line break is a space, unless the line ends with `\`

  * Comments `-- to end of line` and `[- block -]`

  * Metadata as YAML front matter between `---` lines, and `>> key: value` lines

  * Optional ingredients and cookware `@?thyme`, `#?splatter guard{}` (spec proposal 0018)

  * Scaling with `factor` or `servings`; fixed quantities `@salt{=1%tsp}`, cookware and timers are not scaled (spec proposal 0010)

Not supported yet: notes (`> text`), sections (`= Dough`), short-hand preparations (`@onion{1}(chopped)`) and references to other recipes (`@./sauces/pesto{}`). They are parsed as plain text or as an ordinary ingredient.

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

## Running the tests

The specification tests are in a git submodule:

        % git submodule update --init
        % prove -e 'raku -Ilib' t

COMMUNITY
=========

  * [Code repository Wiki and Issue Tracker](https://github.com/uniejo/cooklang-raku)

  * [Cooklang on raku.land](https://raku.land/zef:uniejo/Cooklang)

SEE ALSO
========

  * [Cooklang](https://cooklang.org/) and the [Cooklang specification](https://github.com/cooklang/spec)

  * [Cooklang for Perl](https://metacpan.org/dist/Cooklang) on MetaCPAN

AUTHOR
======

Erik Johansen - uniejo@users.noreply.github.com

COPYRIGHT
=========

Erik Johansen 2023-2026

LICENSE
=======

This software is licensed under the same terms as Perl itself.
