unit class Cooklang:ver<1.0.2>:auth<Erik Johansen (uniejo@cpan.org)>;
use AttrX::Mooish;

has $.recipe_file  is rw  is mooish(:trigger);
has $.recipe       is rw  is mooish(:trigger);
has $.match        is rw;

grammar Recipe {
    rule TOP            { <line>+ }
    token line          { [ <comments> | <metadata> | <step> | \v ] \v? }
    token step          { <step_part>+ }
    token step_part     { <ingredient> | <cookware> | <timer> | <comments> | [\@\#\%\-]? <step_text> }
    token metadata      { '>>' <meta_label> \s* ':' <meta_value> }
    token ingredient    { '@'  [ <item_text> <qamount> | <item_word> ]  }
    token cookware      { '#'  [ <item_text> <qamount> | <item_word> ]  }
    token timer         { '~'  <item_text>? <qamount>  }
    token qamount       { '{' ~ '}' [ <amount> | <units> ]? }
    token amount        { <quantity> [ '%' <units> ]? }
    token meta_label    { <- [\:] >+ }    # except for ':'
    token meta_value    { \V+ }           # except for vertical space (new line)
    token quantity      { <- [\%\}] >* }  # except for '%' and '}'
    token units         { <- [\%\}] >+ }  # except for '}'
    token item_text     { <- [\{\@] >+ }  # except for '{' and '@'
    token item_word     { <- [\{\s] >+ }  # except for '{' and whitespace
    token step_text     { <- [\@\#\~\-\v] >+ }
    token text          { \V+ } # except for vertical space (new line)
    token comments      { <comment> | <block_comment> }
    token comment       { '--' \V* }
    token block_comment { '[-' ~ '-]' .*? }
#   token punctuation   { Unicode General Category P* ? ;
#   token whitespace    { Unicode General Category Zs and CHARACTER TABULATION (U+0009) ? ;
# <.ws>  Whitespace
# <.crlf>
#   token newline       { newline characters (U+000A ~ U+000D, U+0085, U+2028, and U+2029) ? ;
#   Note \v includes:  U+000A LINE FEED  U+000B VERTICAL TABULATION  U+000C FORM FEED  U+000D CARRIAGE RETURN  U+0085 NEXT LINE  U+2028 LINE SEPARATOR  U+2029 PARAGRAPH SEPARATOR
}

class RecipeActions {
    method TOP ($/) {
       my @parts = $/<line>>>.made;
       my %metadata    = @parts>>.<metadata>>>.list.flat;
       my @ingredients = @parts>>.<ingredients>>>.list;
       my @steps       = @parts>>.<steps>.grep(*.so)>>.list;
       my @comments    = @parts>>.<comments>.grep(*.so)>>.list;
       my %res = metadata => %metadata, ingredients => @ingredients, steps => @steps, comments => @comments;
       make %res;
    }
    method line ($/) {
       my $step     = $/<step>.made;
       my %metadata = $/<metadata>.made // {};
       my @ingredients = $step && $step.<ingredients>>>.list // Empty;
       my @steps       = $step && $step.<steps>.list // Empty;
       my @comments    = $step && $step.<comments>>>.list // Empty;
       push @comments, $/<comments>.made   if $/<comments> && $/<comments>.made;
       my %res =  metadata => %metadata, ingredients => @ingredients, steps => @steps, comments => @comments;
       make %res;
    }
    method step ($/) {  # Array of matches
       my @parts = $/<step_part>>>.made.grep(*.so);
       my @ingredients = @parts>>.<ingredient>.grep(*.so);
       my @steps       = @parts>>.<step>.grep(*.so);
       my @comments    = @parts>>.<comment>.grep(*.so);
       my %res = ingredients => @ingredients,  steps => @steps, comments => @comments;
       make %res;
    }
    method step_part ($/) {  # Alternative of matches
       my $step =
           ( $/<ingredient> && $/<ingredient>.made  ) //
           ( $/<cookware>   && $/<cookware>.made    ) //
           ( $/<timer>      && $/<timer>.made       ) //
           ( $/<step_text>  && $/<step_text>.made   );
       my $ingredient =
           ( $/<ingredient> && $/<ingredient>.made  );
       my $comment =
           ( $/<comments>   && $/<comments>.made  );
       my %res = ingredient => $ingredient, step => $step, comment => $comment;
       make %res;
    }
    method ingredient ($/) {
       return make Empty   unless $/;
       my %res = units => "";
       %res = $/<qamount>.made if $/<qamount> && $/<qamount>.made;
       %res<type> = 'ingredient';
       %res<name> = $/<item_text> ?? ~$/<item_text> !! $/<item_word> ?? ~$/<item_word> !! "";
       %res<quantity> //= 1;
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
    method qamount ($/) {
       my %res;
       %res = $/<amount>.made if $/<amount>;
       %res<units> = $/<units>.made if $/<units>;
       %res<quantity> //= Nil;
       %res<units>    //= "" if $/<quantity>;
       make %res;
    }
    method amount ($/) {
       my %res;
       %res<quantity> = $/<quantity>.made if $/<quantity>;
       %res<units>    = $/<units>.made    if $/<units>;
       %res<units>    //= "";#    if %res<quantity>;
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
    method quantity ($/) {
       my $q_trim = ~$/.trim;
       # Review: Removing spaces inside "1 / 2". Unwanted side-effect "1 2" becomes "12" and is accepted as number.
       my $q_nosp = ~$/.subst(" ","",:g);
       my $res =
           !$/ ?? Nil !!
           $q_trim eq '' ?? Nil !!            # Nothing if empty after trimming
           $q_nosp ~~ /^0\d/ ?? $q_trim !!    # Do not accept number like 01...
           try { 0+$q_nosp } //               # Make quantity numeric (if possible)
           $q_trim;                           # Otherwise use trimmed text
       make $res;
    }
    method units ($/) {
       my $res = ~$/.trim // "";
       make $res;
    }
    method step_text ($/) {
       return make Empty   unless $/ && ~$/ ~! /^\v$/;
       my %res = type => 'text', value => ~$/;
       make %res;
    }
    method metadata ($/) {
       my %res = ~$/<meta_label>.trim => ~$/<meta_value>.trim;
       make %res;
    }
    method comments ($/) {
       make $/<comment> ?? ~$/<comment>.trim !! $/<block_comment> ?? ~$/<block_comment>.trim !! Empty;
    }
}

# Read recipe from file
method trigger-recipe_file ($recipe_file) {
    $!recipe = $recipe_file.IO.slurp;
    $!match = Recipe.parse($!recipe, actions => RecipeActions);
}

# Recipe text passed directly
method trigger-recipe ($recipe) {
    $!match = Recipe.parse($recipe, actions => RecipeActions);
}

# Return ast
# Note that this removes a bit of info from the raw ast
# The removed fields are available directly from the object (see methods below).
method ast {
    return $!match  unless $!match && $!match.made;
    my %res = $!match.made;
    %res<metadata> = $[]  unless %res<metadata> && %res<metadata>.?keys;
    %res<ingredients>:delete;
    %res<comments>:delete;
    return %res;
}

method ingredients { $!match && $!match.made && $!match.made<ingredients> // [] }
method steps       { $!match && $!match.made && $!match.made<steps> // [] }
method metadata    { $!match && $!match.made && $!match.made<metadata> // {} }
method comments    { $!match && $!match.made && $!match.made<comments> // [] }

