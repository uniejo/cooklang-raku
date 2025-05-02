#!/usr/bin/env raku
use v6;
use Test;
use lib 'lib';
use Cooklang;

my $recipe = Cooklang.new( recipe => 'ingredients like @onion{0.5%cup//dicedred}' );
#my $recipe = Cooklang.new( recipe => 'ingredients like @onion{0.5%cup//diced red onion;Yellow OK}' );

# note $recipe.match;

my %expected =
    data => {
        metadata => [
        ],
        steps    => [
            [
                {:type("text"), :value("ingredients like ")},
                {:name("onion"), :quantity(0.5), :type("ingredient"), :units("cup")},
            ],
        ],
    },
    ingredients => [
        {:name("onion"), :quantity(0.5), :type("ingredient"), :units("cup")},
    ],
    cookwares => [
    ],
    comments => [
    ],
;
subtest 'is-deeply' => { is-deeply( $recipe.data, %expected<data>, 'Test .data output') };
subtest 'is-deeply' => { is-deeply( $recipe.metadata, {}, 'Test .metadata output') };
subtest 'is-deeply' => { is-deeply( $recipe.ingredients, %expected<ingredients>, 'Test .ingredients output') };
subtest 'is-deeply' => { is-deeply( $recipe.comments, %expected<comments>, 'Test .comments output') };


done-testing;
