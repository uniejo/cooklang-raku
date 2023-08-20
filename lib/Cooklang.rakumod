unit class Cooklang:ver<1.1.1>:auth<zef:uniejo>;
use AttrX::Mooish;

has $.recipe_file  is rw  is mooish(:trigger);
has $.recipe       is rw  is mooish(:trigger);
has $.factor       is rw  is mooish(:trigger) = 1;
has $.match        is rw;

grammar Recipe {
    rule TOP            { <line>+ }
    token line          { [ <comments> | <metadata> | <step>+ | \v ] \v? }
    token step          { <step_item> | <step_text> }
    token step_item     { <ingredient> | <cookware> | <timer> | <comments> }
    token metadata      { '>>' <meta_label> \s* ':' <meta_value> }
    token ingredient    { '@'  [ <item_text> <qamount> | <item_word> ]  }
    token cookware      { '#'  [ <item_text> <qamount> | <item_word> ]  }
    token timer         { '~'  <item_text>? <qamount>  }
    token qamount       { '{' ~ '}'  [ <quantity>? [ '%' <units> ]? ]? [ '//' <modifier> ]? [ ';' <note> ]? }
    token comment       { '--' <( \V* )> }
    token block_comment { '[-' ~ '-]' .*? }
    token comments      { <comment> | <block_comment> }
    token meta_label    { <- [\:] >+ }    # except for ':'
    token meta_value    { \V+ }           # except for vertical space (new line)
    token item_text     { [ <!before <step_item>> <- [\{] > ]+ }  # except for '{' and <step_item>
    token item_word     { [ <!before <step_item>> \S ]+ }  # except for whitespace and <step_item>
    token step_text     { [ <!before <step_item>> \V ]+ }  # Non-vertial as long as it does not match <step_item> (full match)
    token quantity      { [ <!before ['%'|'//'|';'|'}'] > . ]+ }
    token units         { [ <!before [    '//'|';'|'}'] > . ]+ }
    token modifier      { [ <!before [         ';'|'}'] > . ]+ }
    token note          { [ <!before [         '}'] > . ]+ }
#   Note \v includes:  U+000A LINE FEED  U+000B VERTICAL TABULATION  U+000C FORM FEED  U+000D CARRIAGE RETURN  U+0085 NEXT LINE  U+2028 LINE SEPARATOR  U+2029 PARAGRAPH SEPARATOR
}

class RecipeActions {
    has $.factor       is readonly = 1;
    method TOP ($/) {
       my @parts = $/<line>>>.made.grep(*.so);
       my %metadata    = @parts>>.<metadata>.grep(*.so)>>.list.flat;
       my @ingredients = @parts>>.<ingredients>.grep(*.so)>>.list.flat;
       my @steps       = @parts>>.<steps>.grep(*.so)>>.list;
       my @comments    = @parts>>.<comments>.grep(*.so)>>.list.flat;
       my %res = metadata => %metadata, ingredients => @ingredients, steps => @steps, comments => @comments;
       make %res;
    }
    method line ($/) {
       my @step     = $/<step>>>.made.grep(*.so);
       my %metadata = $/<metadata>.made // {};
       my @ingredients = @step>>.<ingredients>.grep(*.so)>>.list.flat;
       my @steps       = @step>>.<steps>.grep(*.so)>>.list.flat;
       my @comments    = @step>>.<comments>.grep(*.so)>>.list.flat;
       push @comments, $/<comments>.made   if $/<comments>;
       my %res =  metadata => %metadata, ingredients => @ingredients, steps => @steps, comments => @comments;
       make %res;
    }
    method step ($/) {
       my %res = $/<step_item> ?? $/<step_item>.made !! $/<step_text> ?? $/<step_text>.made !! Empty;
       make %res;
    }
    method step_item ($/) {  # Alternative of matches
       my @steps       = $/<ingredient cookware timer>.grep(*.so)>>.made.list;
       my @ingredients;
       push @ingredients, $/<ingredient>.made   if $/<ingredient>;
       my @comments    = $/<comments>.grep(*.so)>>.made;
       my %res = ingredients => @ingredients, steps => @steps, comments => @comments;
       make %res;
    }
    method ingredient ($/) {
       return make Empty   unless $/;
       my %res = units => "";
       %res = $/<qamount>.made if $/<qamount>;
       %res<type> = 'ingredient';
       %res<name> = $/<item_text> ?? ~$/<item_text> !! $/<item_word> ?? ~$/<item_word> !! "";
       %res<quantity> //= 1*$!factor;
       %res<modifier> = ~$/<modifier>  if $/<modifier>;
       %res<note> = ~$/<note>  if $/<note>;
       make %res;
    }
    method cookware ($/) {
       return make Empty   unless $/;
       my %res;
       %res = $/<qamount>.made if $/<qamount>;
       %res<type> = 'cookware';
       %res<name> = $/<item_text> ?? ~$/<item_text> !! ~$/<item_word>;
       %res<quantity> //= '';
       %res<units>:delete;
       make %res;
    }
    method timer ($/) {
       return make Empty   unless $/;
       my %res;
       %res = $/<qamount>.made  if $/<qamount>;
       %res<type> = 'timer';
       %res<name> = $/<item_text> ?? ~$/<item_text> !! "";
       make %res;
    }
    method qamount ($/) {
       my %res;
       %res<quantity> = $/<quantity> && $/<quantity>.made;
       %res<units>    = $/<units> && $/<units>.made // "";
       %res<modifier> = $/<modifier>.made if $/<modifier>;
       make %res;
    }
    method quantity ($/) {
       my $q_trim = ~$/.trim;
       my $q_nosp = ~$/.subst(/\s*\/\s*/,"/",:g);   # "1 / 2" becomes "1/2" eval to 0.5
       my $res =
           !$/ ?? Nil !!
           $q_trim eq '' ?? Nil !!            # Nothing if empty after trimming
           try { # Make quantity numeric (if possible), no zero prefix
	       die if $q_nosp ~~ /^0\d/;
	       (0+$q_nosp)*$.factor
           } //
	 # $q_nosp ~~ /^([1-9]\d*)-(([1-9]\d*)$/ ?? try { [$1,$2].map{* * $.factor}.join("-") } //
           $q_trim ~ ($.factor != 1 ?? " * {$.factor}" !! "");  # Otherwise use trimmed text (but add factor if present)

       say "Quantity {$/} * { $.factor } = {$res.raku}";
 
       make $res;
    }
    method units ($/) {
       make ~$/.trim // "";
    }
    method modifier ($/) {
       make ~$/.trim // "";
    }
    method step_text ($/) {
       return make Empty   unless $/;
       return make Empty   if ~$/ ~~ /^\v*$/;
       my %step = type => 'text', value => ~$/;
       my %res = ingredients => Nil, steps => [ $%(%step) ], comments => Nil;
       make %res;
    }
    method metadata ($/) {
       my %res = ~$/<meta_label>.trim => ~$/<meta_value>.trim;
       make %res;
    }
    method comments ($/) {
       my %res = type=>'comment', value => ~( $/<comment> // $/<block_comment> ).trim;
       make %res;
    }
}

# Read recipe from file (or list of files)
method trigger-recipe_file ($recipe_file) {
    $!recipe = [$recipe_file]>>.map(*.IO.slurp).join("\n\n");
    $!match = Recipe.parse($!recipe, actions => RecipeActions.new);
}

# Recipe text passed directly
method trigger-recipe ($recipe) {
    $!match = Recipe.parse($recipe, actions => RecipeActions.new);
}

method trigger-factor ($factor) {
    $!match = Recipe.parse($!recipe, actions => RecipeActions.new( factor => $factor ) );
}

# Return data
# Note that this removes a bit of info from the raw ast
# The removed fields are available directly from the object (see methods below).
method data {
    return $!match  unless $!match && $!match.made;
    my %res = $!match.made;
    %res<metadata> = $[]  unless %res<metadata> && %res<metadata>.?keys;
    %res<ingredients>:delete;
    %res<comments>:delete;
    return %res;
}

method metadata    { $!match && $!match.made && $!match.made<metadata>  }
method ingredients { $!match && $!match.made && $!match.made<ingredients>  }
method steps       { $!match && $!match.made && $!match.made<steps>     }
method comments    { $!match && $!match.made && $!match.made<comments>  }


=begin pod

=begin NAME

Cooklang - C<Raku> C<Cooklang> parser

=end NAME

=begin SYNOPSIS

=begin code :lang<raku>
    use Cooklang;
    ...
    my $source = "some Cooklang text";
    my $recipe = Cooklang.new( recipe => $source );
    ...
    my $file = 'recipe.cook';
    my $recipe = Cooklang.new( recipe_file => $file );
    ...
    my @files = 'recipe1.cook', 'recipe2.cook';
    my $recipe = Cooklang.new( recipe_file => @files );
    # Currently does a simple join of all files, before parsing.
    ...
    my $metadata    = $recipe.metadata;
    my $ingredients = $recipe.ingredients;
    my $steps       = $recipe.steps;
    my $comments    = $recipe.comments;
    my $data        = $recipe.data;
    my $ast_tree    = $recipe.match;
=end code

=end SYNOPSIS

=begin VERSION

    version 1.1.1

=end VERSION

=begin AVAILABILITY

Cooklang is implemented in C<Raku> using grammer and grammar action to parse and build AST tree.

=end AVAILABILITY

=begin DESCRIPTION
For the C<Cooklang> syntax, see [Cooklang](https://cooklang.org/).
=end DESCRIPTION

=begin DOCUMENTATION
Cooklang documentation is available as C<POD6>.
You can run `raku --doc` from a shell to read the documentation:
=begin code
    % raku --doc lib/Cooklang.rakumod
    % raku --doc=Markdown lib/Cooklang.rakumod     # zef install Pod::To::Markdown
    % raku --doc=HTML lib/Cooklang.rakumod         # zef install Pod::To::HTML
=end code
=end DOCUMENTATION

=begin INSTALLATION
Installing Cooklang is straightforward.

## Installation with zef from CPAN6

If you have zef, you only need one line:

=begin code
    % zef install Cooklang
=end code

## Installation with zef from git repository

=begin code
    % zef install https://github.com/uniejo/cooklang-raku.git
=end code

=end INSTALLATION

=begin COMMUNITY
=item1 [Code repository Wiki and Issue Tracker](https://github.com/uniejo/cooklang-raku)
=item1 [Cooklang on modules.raku.org](https://modules.raku.org/dist/Cooklang:zef:zef:uniejo)
=end COMMUNITY

=begin AUTHOR
Erik Johansen - uniejo@users.noreply.github.com
=end AUTHOR

=begin COPYRIGHT
Erik Johansen 2023
=end COPYRIGHT

=begin LICENSE
This software is licensed under the same terms as Perl itself.
=end LICENSE

=end pod
