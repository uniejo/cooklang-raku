#!/usr/bin/env raku
use v6;
use Test;
use lib 'lib';
use Cooklang;

# Any text is a recipe: random text made from Cooklang fragments always parses,
# and cook() gives back the text unchanged.
# The seed is fixed, so a failure can be repeated.
srand 42;
my @fragments = '@', '#', '~', '{', '}', '%', '//', ';', '=', '?', '[-', '-]', '--', '---',
                '>', '>>', ':', '\\', '1/2', '2-3', 'salt', ' ', "\n", "\n\n";

my @failed;
for ^1000 {
    my $src = @fragments.roll((1..10).pick).join;
    my $cook = try Cooklang.new( recipe => $src ).cook;
    @failed.push: $src  unless $cook.defined && $cook eq $src;
}
is-deeply @failed, [], 'Random text: parses, and cook() round-trips';

done-testing;
