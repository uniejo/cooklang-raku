#!/usr/bin/env raku
use v6;
use Test;
use lib 'lib';
use Cooklang;

my $source = '
-- Source: https://www.jamieoliver.com/recipes/eggs-recipes/easy-pancakes/
>> First meta: This is first meta
>> Second meta: This is second meta


Crack the @eggs{3} into a blender, then add the @flour{125%g}, @milk{250%ml} and @sea salt{1%pinch}, and blitz until smooth.

Pour into a #bowl and leave to stand for ~{15%minutes}.

Melt the @butter (or a drizzle of @oil if you want to be a bit healthier) in a #large non-stick frying pan{} on a medium heat, then tilt the pan so the butter coats the surface.

Pour in 1 ladle of batter and tilt again, so that the batter spreads all over the base, then cook for 1 to 2 minutes, or until it starts to come away from the sides.

Once golden underneath, flip the pancake over and cook for 1 further minute, or until cooked through.

Serve straightaway with your favourite topping. -- Add your favorite topping here to make sure it\'s included in your meal plan!
';

my $recipe = Cooklang.new( recipe => $source );

# note $recipe.match;

my %expected =
    ast => {
        metadata => {
            'First meta' => 'This is first meta',
            'Second meta' => 'This is second meta',
        },
        steps    => [
            [
                {:type("text"), :value("Crack the ")},
                {:name("eggs"), :quantity(3), :type("ingredient"), :units("")},
                {:type("text"), :value(" into a blender, then add the ")},
                {:name("flour"), :quantity(125), :type("ingredient"), :units("g")},
                {:type("text"), :value(", ")}, {:name("milk"), :quantity(250), :type("ingredient"), :units("ml")},
                {:type("text"), :value(" and ")},
                {:name("sea salt"), :quantity(1), :type("ingredient"), :units("pinch")},
                {:type("text"), :value(", and blitz until smooth.")}
            ],
            [
                {:type("text"), :value("Pour into a ")},
                {:name("bowl"), :quantity(""), :type("cookware")},
                {:type("text"), :value(" and leave to stand for ")},
                {:name(""), :quantity(15), :units('minutes'), :type("timer")},
                {:type("text"), :value(".")},
            ],
            [
                {:type("text"), :value("Melt the ")},
                {:name("butter"), :quantity(1), :type("ingredient"), :units("")},
                {:type("text"), :value(" (or a drizzle of ")},
                {:name("oil"), :quantity(1), :type("ingredient"), :units("")},
                {:type("text"), :value(" if you want to be a bit healthier) in a ")},
                {:name("large non-stick frying pan"), :quantity(""), :type("cookware")},
                {:type("text"), :value(" on a medium heat, then tilt the pan so the butter coats the surface.")}
            ],
            [
                {:type("text"), :value("Pour in 1 ladle of batter and tilt again, so that the batter spreads all over the base, then cook for 1 to 2 minutes, or until it starts to come away from the sides.")},
            ],
            [
                {:type("text"), :value("Once golden underneath, flip the pancake over and cook for 1 further minute, or until cooked through.")},
            ],
            [
                {:type("text"), :value("Serve straightaway with your favourite topping. ")},
            ]
        ],
    },
    ingredients => [
        {:name("eggs"), :quantity(3), :type("ingredient"), :units("")},
        {:name("flour"), :quantity(125), :type("ingredient"), :units("g")},
        {:name("milk"), :quantity(250), :type("ingredient"), :units("ml")},
        {:name("sea salt"), :quantity(1), :type("ingredient"), :units("pinch")},
        {:name("butter"), :quantity(1), :type("ingredient"), :units("")},
        {:name("oil"), :quantity(1), :type("ingredient"), :units("")},
    ],
    cookwares => [
        {:name("bowl and leave to stand for ~"), :quantity(15), :type("cookware")},
        {:name("large non-stick frying pan"), :quantity(1), :type("cookware")},
    ],
    comments => [
        {:type('comment'), value => "Source: https://www.jamieoliver.com/recipes/eggs-recipes/easy-pancakes/" },
    ],
;
subtest 'is-deeply' => { is-deeply( $recipe.ast, %expected<ast>, 'Test .ast output') };
subtest 'is-deeply' => { is-deeply( $recipe.metadata, %expected<ast><metadata>, 'Test .metadata output') };
subtest 'is-deeply' => { is-deeply( $recipe.ingredients, %expected<ingredients>, 'Test .ingredients output') };
subtest 'is-deeply' => { is-deeply( $recipe.comments, %expected<comments>, 'Test .comments output') };


done-testing;
