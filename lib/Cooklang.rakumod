unit class Cooklang:ver<2.0.1>:auth<zef:uniejo>;
use AttrX::Mooish;

has $.recipe_file  is rw  is mooish(:trigger);
has $.recipe       is rw  is mooish(:trigger);
has $.factor       is rw  is mooish(:trigger) = 1;
has $.match        is rw;

grammar Recipe {
    rule TOP            { <line>+ }
    token line          { [ <line_comments> | <metadata> | <step>+ | <vertical> ] <vertical>? }
    token step          { <step_item> | <step_text> }
    token step_item     { <ingredient> | <cookware> | <timer> | <step_comments> }
    token metadata      { '>>' <meta_key> \s* ':' <meta_value> }
    token ingredient    { '@'  [ <item_text> <qamount> | <item_word> ]  }
    token cookware      { '#'  [ <item_text> <qamount> | <item_word> ]  }
    token timer         { '~'  <item_text>? <qamount>  }
    token qamount       { '{' ~ '}' [ [ <quantity> [ '%' <units> ]? ]? [ '//' <modifier> ]? [ ';' <qanote> ]? | <qamount_HUH> ] }
    token line_comments { <comment> | <block_comment> }
    token step_comments { <comment> | <block_comment> }
    token comment       { '--' <( \V* )> }
    token block_comment { '[-' ~ '-]' .*? }
    token meta_key      { <- [\:] >+ }    # except for ':'
    token meta_value    { \V+ }           # except for vertical space (new line)
    token item_text     { [ <!before <step_item>> <- [\{] > ]+ }  # except for '{' and <step_item>
    token item_word     { [ <!before <step_item>> <- [\s\}]> ]+ }  # except for whitespace and <step_item>
    token step_text     { [ <!before <step_item>> \V ]+ }  # Non-vertial as long as it does not match <step_item> (full match)
    token quantityX     { [ <!before ['%'|'//'|';'|'}'] > . ]+ }
    token quantityY     { <number> | <quant_text>  }
    token quantity      { <quant_text>  }
    token quant_text    { [ <!before ['%'|'//'|';'|'}'] > . ]* }
    token qamount_HUH   { [ <!before ['}'] > . ]* }
    token number        { <number_part> [\s+ <reci> ] ? | <reci>  }
    token reci          { <intval> \s* '/' \s* <intval> }
    token intval        { <[1..9.]><[0..9]>* }
    token number_part   { <[1..9.]><[0..9.]>* }
    token units         { [ <!before [    '//'|';'|'}'] > . ]+ }
    token modifier      { [ <!before [         ';'|'}'] > . ]+ }
    token qanote        { [ <!before [         '}'] > . ]+ }
    token vertical      { \v }
#   Note \v includes:
#     U+000A LINE FEED
#     U+000B VERTICAL TABULATION
#     U+000C FORM FEED
#     U+000D CARRIAGE RETURN
#     U+0085 NEXT LINE
#     U+2028 LINE SEPARATOR
#     U+2029 PARAGRAPH SEPARATOR
}

role CookBase does Associative {
    has $.type = self.^name.subst("Cooklang::","").lc;
    has $.orig ;
    has $.name ;
#   submethod BUILD {  # Notice this may prevent value input
#     # say "Build Cookbase: " ~ self.^name ~~ /::/ ? $/.tail;
#     # say "Build Cookbase: " ~ $!type;
#   }
#   multi submethod gist(CookBase:U) { "<todo>" }
#   multi submethod gist(CookBase:D) { .orig }
#   multi submethod gist(Any:D) { .orig }
#   submethod gist { $!orig }
    submethod gist (--> Str:D) {
       return self.orig;
    }
    submethod cook (--> Str:D) {
       return self.orig;
    }
    submethod human (--> Str:D) {
       return self.orig; # By default
    }
    submethod data {
        my %data;
        for self.^attributes(:local) {
            next unless .has_accessor;
            my $v = .get_value(self);
            next unless defined $v;
            %data{.name.subst(<$!>,"")}=$v;
        }
	for <<quantity units modifier>> {
            next unless self.^can($_);
	    my $v = self."$_"();
            next unless defined $v;
	    %data{$_} = $v;
        }
        return %data;
    }
    submethod spec-data {
        my %data = self.data;
        %data<orig>:delete;
        %data<qamount>:delete;
        %data<measurement>:delete;
        return %data;
    }
    method AT-KEY (\key) {
      # return self.{key};
        my $k = '$!' ~ key;
        return .get_value(self) for grep { .name eq $k && .has_accessor }, self.^attributes(:local);
#return self.^can($_).() for grep { key eq $_ && self.^can($_) }, <<quantity units modifier>>;
        return Nil;
    }
}
class Measurement is CookBase {
    has $.quantity is rw; # This may have to go again
    has $.number is rw;
    has $.units is rw;
    has $.modifier is rw;
    submethod pluralis {
	return self.qamount.defined && self.qamount.Int != 1;
    }
    submethod human ( $item? is copy ) {
        return Empty  unless self.quantity || self.units || self.modifier || $item;
	my $quantity = self.quantity;
	# Singular/pluralis of $item
say "Item is : { $item.raku } ({ $item.^name })";
say "Quantity is : { $quantity.raku } ({ $quantity.^name })";
say "Qamount is : { self.qamount.raku } ({ self.qamount.^name })";
say "Units is : { self.units.raku } ({ self.units.^name })";
	if ( self.pluralis ) {
            # Pluralis
            $item.=subst(/$/, "s") if $item ~~ Str;
        }
	else {
            # Signular (or default a/an)
            $item.=subst(/s$/, "") if $item ~~ Str;
	    $quantity ||= $item ~~ /^[aeiouy]/ ?? 'an' !! 'a'  if $item ~~ Str;
        }
	# Use quantity 'a' or 'an' when no quantity given
        my @qparts =
	    $quantity // Empty,
	    # TODO: Pluralis should be next word after quantity
	    self.units    || Empty,
	    self.modifier || Empty,
	    $item || Empty;
	return @qparts ?? @qparts.join(" ") !! Empty;
    }
}
role CookMeasurement {
    has Measurement $.measurement = Measurement.new;
    method quantity { self.measurement.?quantity }
    method number   { self.measurement.?number }
    method units    { self.measurement.?units }
    method modifier { self.measurement.?modifier }
}
class Comment does CookBase {
    has $.value;
    submethod gist (--> Str:D) {
        return self.orig // self.value;
    }
    submethod cook (--> Str:D) {
       # May need to add atribute to tell what comment type it is
       return "[- { self.value } -]";
    }
    submethod human (--> Str:D) {
       return "( { self.value } )";
    }
}
class Cookware does CookBase does CookMeasurement {
   # NO units
#    submethod BUILD {  # Notice this may prevent value input
#      $!units = Nil;
#    }
    submethod TWEAK() {
        self.measurement.units = Nil;
        self.measurement.quantity = "";
    }
    submethod human (--> Str:D) {
        return self.measurement.human(self.name);
    }
}
class Ingredient does CookBase does CookMeasurement {
    has $.note;
    submethod gist (--> Str:D) {
        return self.orig;
    }
    submethod human (--> Str:D) {
        return self.measurement.human(self.name);
    }
}
class Timer does CookBase does CookMeasurement {
    submethod gist (--> Str:D) {
        return self.orig;
    }
    submethod human (--> Str:D) {
        return self.measurement.human(self.name);
    }
}
class Step does CookBase {
    has $.value;
    submethod gist (--> Str:D) {
        return self.orig // self.value;
    }
}
class Vertical does CookBase {
    has $.value;
    submethod gist (--> Str:D) {
        return self.orig // self.value;
    }
}
class Metadata does CookBase {
    has $.meta_key;
    has $.meta_value;
    submethod gist (--> Str:D) {
        return self.orig;
    }
    submethod human (--> Str:D) {
        return "( {self.meta_key} {self.meta_value} )";
    }
}

class RecipeActions {
    has $.factor       is readonly = 1;
    has @.parts        is rw;
    method TOP ($/) {
        make @.parts;
    }
    method line ($/) {
    }
    method step ($/) {
        my @step_item = $/<step_item>.made.list if $/<step_item> && $/<step_item>.made;
        @.parts.push: |@step_item;
        @.parts.push: $/<step_text>.made if $/<step_text> && $/<step_text>.made;
    }
    method step_item ($/) {  # Alternative of matches
        my @res = $/<ingredient cookware timer step_comments>.grep(*.so)>>.made.list;
        make @res;
    }
    method step_text ($/) {
        make Step.new( type => 'text', value => ~$/, orig => ~$/ );
    }
    method vertical ($/) {
        @.parts.push: Vertical.new( type => 'text', value => ~$/, orig => ~$/ )  if $/;
    }
    method ingredient ($/) {
        return   unless $/;
        my %res;
	for %res<measurement> {
	    $_ = $/<qamount> && $/<qamount>.made // Measurement.new( units => "" );
	    say "Ingredient { $/ } : quantity from qamount.made measurement: { .quantity.raku }";
        # qamount and quantity at the same time - One has to go
            .quantity //= 1*$!factor;
	    say "Ingredient { $/ } : quantity now: { .quantity.raku }";
            .number   //= 1*$!factor;
            .modifier = ~$/<modifier>  if $/<modifier>;
        }
        %res<name> = $/<item_text> ?? ~$/<item_text> !! $/<item_word> ?? ~$/<item_word> !! "";
        %res<qanote> = ~$/<qanote>  if $/<qanote>;
        %res<orig> = ~$/;
        make Ingredient.new( |%res );
    }
    method cookware ($/) {
        return   unless $/;
        my %res;
	for %res<measurement> {
	    $_ = $/<qamount> && $/<qamount>.made // Measurement.new( units => "" );
	}
        %res<name> = $/<item_text> ?? ~$/<item_text> !! ~$/<item_word>;
        %res<orig> = ~$/;
        make Cookware.new( |%res );
    }
    method timer ($/) {
        return    unless $/;
        my %res;
        %res<measurement> = $/<qamount> && $/<qamount>.made // Measurement.new;
        %res<name> = $/<item_text> ?? ~$/<item_text> !! "";
        %res<orig> = ~$/;
        make Timer.new( |%res );
    }
    method qamount ($/) {
        my %res;
        %res<quantity> = $/<quantity>.made  if $/<quantity>;
        %res<units>    = $/<units> && $/<units>.made // "";
        %res<modifier> = $/<modifier>.made if $/<modifier>;
        %res<orig> = ~$/;
        self.num_parts( %res<quantity>, %res<number>, $!factor );
	make Measurement.new( |%res );
    }
    # TODO: num_parts should be able to handle:
    # "num_str "1 1/2" is num 1.5
    # add in factor to num and num_str
    # (update units if it seems appropiate)
    submethod num_parts ( $num_str is rw, $num is rw, $factor ) {
	return unless $num_str.defined;
	# What if number is several alternative values
        $num_str ~~ s:g/\s*\/\s*/\//;   # "1 / 2" becomes "1/2" eval to 0.5
        $num =
           $num_str ~~ /^\s*$/ && 1 //
           $num_str ~~ /^<[0..9.]>/ && try { # Make quantity numeric (if possible), no zero prefix
               die if $num_str ~~ /^0\d/; # spec rule
               die if $num_str ~~ /<[-]>/; # range
               (0+$num_str)*$factor
           } //
        # $q_nosp ~~ /^([1-9]\d*)-(([1-9]\d*)$/ ?? try { [$1,$2].map{* * $.factor}.join("-") } //
           $num_str ~~  /^(<[0..9.]>+)\s*"-"\s*(<[0..9.]>+)$/ && try { # Make quantity range numeric (if possible), and back to range string TODO? no zero prefix
	       join ' - ', map { die if /^0\d/; 0+$_*$factor }, $/[0], $/[1];

           } //
           $num_str ~ ($factor != 1 ?? " * {$factor}" !! "");  # Otherwise use trimmed text (but add factor if present)

      # say "Measurement {$/} * { $.factor } = {$res.raku}";
	if ( $num ~~ Str && $num_str.subst(" "," ") && try { [+] $num_str.split(/\s+/).map(0+*) } ) {
            $num = $_;
        }
      # if ( $num ~~ Real && ~$num eq $num_str ) {
        if ( $num ~~ Real ) {
            $num_str = $num;
        }
    }
    method units ($/) {
        make ~$/.trim // "";
    }
    method modifier ($/) {
        make ~$/.trim // "";
    }
    method quantity ($/) {
	make ~$/.trim  if $/ && ~$/ !~~ /^\s*$/;
    }
    method number ($/) {
	make ~$/.trim  if $/ && ~$/ ne '';
    }
    method metadata ($/) {
        my %res;
        %res<meta_key>   = ~$/<meta_key>.trim;
        %res<meta_value> = ~$/<meta_value>.trim;
        %res<orig> = ~$/;
        push @.parts, Metadata.new( |%res );
    }
    method line_comments ($/) {
        push @.parts, Comment.new( value => ~( $/<comment> // $/<block_comment> ).trim );
    }
    method step_comments ($/) {
        make Comment.new( value => ~( $/<comment> // $/<block_comment> ).trim );
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
    my %res;
    %res<metadata> = self.metadata;
    %res<metadata> = $[]  unless %res<metadata> && %res<metadata>.?keys;
    %res<steps> = self.steps;
 #  %res<steps> = $[]  unless %res<steps>;
    return %res;
}

submethod parts( :$match?, CookBase :$split-by?, :$data-type? ) {
    return Empty  unless $!match && $!match.made;
    my @list = $!match.made;
    @list .= grep( $match );# if $match;#   if $type.^name ne 'Any';
    @list = split-by(@list, $split-by)   if $split-by.^name ne 'Cooklang::CookBase';
    @list = apply-data-type( @list, $data-type )   if $data-type;
    return @list;
}

sub split-by( @list-in, CookBase $split-by ) {
    my @list-out;
    my $add-line = True;
    for @list-in -> $p {
        if $p ~~ $split-by { $add-line = True; next; }
        if $add-line { @list-out.push: []; $add-line = False; }
        @list-out[*-1].push: $p;
    }
    return @list-out;
}

sub apply-data-type ( @list, $data-type ) {
    for @list -> $p is rw {
        if ( $p ~~ List|Array ) {
            for @$p -> $q is rw {
	        $q.="$data-type"();
            }
        }
        else {
            $p.="$data-type"();
        }
    }
    return @list;
}

method ingredients { return self.parts.grep( * ~~ Ingredient ) }
method cookware    { return self.parts.grep( * ~~ Cookware ) }
method comments    { return self.parts.grep( * ~~ Comment ) }
method steps ( :$data-type = 'spec-data' )  { return self.parts( match => * ~~ Step|Ingredient|Cookware|Timer|Vertical, split-by => Vertical, data-type => $data-type ) }
method steps_flat ( :$data-type = 'spec-data' )  { return self.parts( type => * ~~ Step|Ingredient|Cookware|Timer, data-type => $data-type ) }
method metadata    {
    my %m;
    %m{.meta_key} = .meta_value for self.parts.grep( * ~~ Cooklang::Metadata );
    return %m;
}
#
method cook  { return self.parts>>.cook.join("") }
method human { return self.parts>>.human.join("") }


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

    version 2.0.1

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
Erik Johansen 2024
=end COPYRIGHT

=begin LICENSE
This software is licensed under the same terms as Perl itself.
=end LICENSE

=end pod
