unit class Cooklang:ver<2.1.0>:auth<zef:uniejo>;
use AttrX::Mooish;
use YAMLish;

class ParseError is Exception {
    has $.line;
    has $.near;
    method message { "Unable to parse recipe at line $!line near '$!near'" }
}

has $.recipe_file  is rw  is mooish(:trigger);
has $.recipe       is rw  is mooish(:trigger);
has $.factor       is rw  is mooish(:trigger) = 1;
has $.servings     is rw  is mooish(:trigger);  # Scale to this many servings
has $.match        is rw;

grammar Recipe {
    rule  TOP             { <line>* }
    token ws              { <!ww> \h* }  # A rule only skips horizontal space (not line breaks)
    token line            { [ <metadata> | <line_comment> | <step>+ | <vertical> ] <vertical>? }
    token step            { <step_item> | <step_text> }
    token step_item       { <ingredient> | <cookware> | <timer> | <step_comment> }
    token step_text       { [ <!before <step_item>> \V ]+ }  # Text up to the next item or line break
    token vertical        { \v [ \h+ <?before \v> ]? }      # A whitespace-only line counts as blank

    # Metadata: '>> key: value' lines, or a YAML front matter block at the very start (^) of the recipe
    token metadata        { <metadata_line> | <metadata_group> }
    rule  metadata_line   { '>>' <meta_key> ':' <meta_value> \v }
    token metadata_group  { ^ <metadata_open> <metadata_body> <metadata_close> <?{ front-matter(~$<metadata_body>).defined }> }
    token metadata_body   { [ <!before '---'> \V* \v ]* }
    token metadata_open   { '---' \h* \v }
    token metadata_close  { '---' \h* }
    token meta_key        { <-[:\v]>+ }  # Up to ':' on the same line
    token meta_value      { \V+ }        # Rest of the line

    # @ingredient, #cookware and ~timer: a single word, or several words ended by {amount}
    token ingredient      { '@' <optional>? <!before \h> [ <item_text> <qamount> | <item_word> ] }
    token cookware        { '#' <optional>? <!before \h> [ <item_text> <qamount> | <item_word> ] }
    token timer           { '~'             <!before \h> [ <item_text>? <qamount> | <item_word> ] }
    token optional        { '?' }  # Only the first '?' is the marker, '@??x{}' is ingredient '?x'
    token item_text       { [ <!before '{' | <step_item>> \V ]+ }  # Up to '{' (or the next item)
    token item_word       { <-[\s] - :P>+ }                         # Up to whitespace or punctuation (Unicode P*)

    # {quantity%units//modifier;note}: every part is optional and ends where a later part starts.
    # A quantity starting with '=' is fixed: it is not scaled, e.g. {=1%tsp}
    token qamount         { '{' ~ '}' [ <fixed>? <quantity> [ '%' <units> ]? [ '//' <modifier> ]? [ ';' <qanote> ]? ] }
    token fixed           { \h* '=' }
    token quantity        { [ <!before '%' | '//' | ';' | '}'> . ]* }
    token units           { [ <!before       '//' | ';' | '}'> . ]+ }
    token modifier        { [ <!before              ';' | '}'> . ]+ }
    token qanote          { [ <!before                    '}'> . ]+ }

    # Comments: '-- to end of line' or '[- block -]'
    token line_comment    { <comment> \v | <block_comment> }
    token step_comment    { <comment> | <block_comment> }
    token comment         { <!after '-'> '--' <!before '-'> <( \V* )> }  # Not part of '---'
    token block_comment   { '[-' ~ '-]' [ <!before '-]'> . ]* }

#   Note \h is horizontal white space. ie. \s - \v
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
    # Do not use submethod BUILD { } as that may prevent value input
    method gist (--> Str:D) {
       return self.orig;
    }
    method cook (--> Str:D) {
       return self.orig;
    }
    method human (--> Str:D) {
       return self.orig; # By default
    }
    method data {
        my %data;
        for self.^attributes(:local) {
            next unless .has_accessor;
            my $v = .get_value(self);
            next unless defined $v;
            %data{.name.subst(<$!>,"")}=$v;
        }
	for <<quantity units modifier fixed>> {
            next unless self.^can($_);
	    my $v = self."$_"();
            next unless defined $v;
	    %data{$_} = $v;
        }
        return %data;
    }
    method spec-data {
        my %data = self.data;
        %data<orig>:delete;
        %data<qamount>:delete;
        %data<measurement>:delete;
        return %data;
    }
    method AT-KEY (\key) {
        my $k = '$!' ~ key;
        return .get_value(self) for grep { .name eq $k && .has_accessor }, self.^attributes(:local);
        return Nil;
    }
}
class Measurement does CookBase {
    has $.quantity is rw; # This may have to go again
    has $.number is rw;
    has $.units is rw;
    has $.modifier is rw;
    has $.fixed is rw;  # True, or undefined when the quantity is scaled
    method pluralis {
        my $n = self.number;
        return $n ~~ Real && $n != 1;
    }
    method human ( $item? is copy ) {
        return Empty  unless self.quantity || self.units || self.modifier || $item;
	my $quantity = self.quantity;
	# Plural of $item, but only when there are no units ("2 eggs", "2 tsp salt").
	# The name is never made singular, as the author chose it ("chilli flakes")
	if self.pluralis {
            $item ~= "s"  if $item && !self.units && $item !~~ / s $ /;
        }
	elsif $item {
	    $quantity ||= $item ~~ /^ :i <[aeiou]> / ?? 'an' !! 'a';
        }
        my @qparts =
	    $quantity // Empty,
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
    method fixed    { self.measurement.?fixed }
}
class Comment does CookBase {
    has $.value;
    method gist (--> Str:D) {
        return self.orig // self.value;
    }
    method cook (--> Str:D) {
       return self.orig // "[- { self.value } -]";
    }
    method human (--> Str:D) {
       return "( { self.value } )";
    }
}
class Cookware does CookBase does CookMeasurement {
    has $.optional;  # True, or undefined (left out of data) when required
    # NO units
    # Do not use submethod BUILD { } as that may prevent value input
    submethod TWEAK() {
        self.measurement.quantity //= 1;
    }
    method human (--> Str:D) {
        return self.measurement.human(self.name) ~ (self.optional ?? " (optional)" !! "");
    }
}
class Ingredient does CookBase does CookMeasurement {
    has $.note;
    has $.optional;  # True, or undefined (left out of data) when required
    submethod TWEAK() {
        self.measurement.quantity //= "some";
    }
    method human (--> Str:D) {
        return self.measurement.human(self.name) ~ (self.optional ?? " (optional)" !! "");
    }
}
class Timer does CookBase does CookMeasurement {
    submethod TWEAK() {
        self.measurement.quantity //= "";
    }
    method human (--> Str:D) {
        return self.measurement.human(self.name);
    }
}
class Step does CookBase {
    has $.value;
    method gist (--> Str:D) {
        return self.orig // self.value;
    }
    method human (--> Str:D) {
        # Without the '\' that marks a line break at the end of a line
        return ( self.value // self.orig ).subst(/ \h* '\\' \h* $ /, '');
    }
}
class Vertical does CookBase {
    has $.value;
    method gist (--> Str:D) {
        return self.orig // self.value;
    }
}
# The '---' lines around a YAML front matter block (kept for cook())
class MetadataMarker does CookBase {
    method human (--> Str:D) {
        return "";
    }
}
class Metadata does CookBase {
    has $.meta_key;
    has $.meta_value;  # Str, or any YAML value (number, Bool, list, map) from front matter
    method human (--> Str:D) {
        my $value = do given self.meta_value {
            when Associative { .sort(*.key).map({ "{.key}: {.value}" }).join(', ') }
            when Positional  { .join(', ') }
            default          { ~$_ }
        };
        return "( {self.meta_key} $value )";
    }
}

# Parse the body of a front matter block into a list of key => value pairs
# (in the order they appear), or Nil if it is not metadata.
# The body is YAML, but plain 'key: value' lines that YAML does not accept,
# like 'cooking time    :30 mins' (spec) or 'notes:', are also allowed.
sub front-matter ( Str $body ) {
    return ()  if $body !~~ / \S /;
    with load-yaml($body) -> $yaml {
        # YAMLish nests the next key under a key without a value ('notes:'),
        # so only trust the result if every key at the start of a line is a top-level key
        my @keys = $body.lines.map({ ~$0 if / ^ (<-[\s#'"-]> <-[:]>*?) \h* ':' [ \s | $ ] / });
        return $yaml.pairs.sort({ $body.index(~.key) // Inf }).List
            if $yaml ~~ Associative && !@keys.first({ $yaml{$_}:!exists });
    }
    my @pairs;
    for $body.lines.grep(/ \S /) {
        next  if / ^ \h* '#' /;  # YAML comment
        return Nil  unless / ^ \h* (<-[:]>+?) \h* ':' \h* (\V*) $ /;
        @pairs.push: ~$0 => (~$1).trim;
    }
    return @pairs.List;
}

# Comment text without the '--' or '[- -]' delimiters
sub comment-text ($/) {
    return ~$/<comment>.trim  if $/<comment>;
    return ~$/<block_comment>.substr(2, *-2).trim;
}

# A plain number like "2", "1.5", ".5" or "1/2" (not "02", "1-2" or "7 k")
sub is-number ( Str $s --> Bool ) {
    return so $s ~~ / ^ <[0..9.]> / && $s !~~ / ^ 0 \d / && !$s.contains('-') && val($s) ~~ Numeric;
}

class RecipeActions {
    has $.factor       is readonly = 1;
    has @.parts        is rw;
    method TOP ($/) {
        make @.parts;
    }
    method step ($/) {
        my @step_item = $/<step_item>.made.list if $/<step_item> && $/<step_item>.made;
        @.parts.push: |@step_item;
        @.parts.push: $/<step_text>.made if $/<step_text> && $/<step_text>.made;
    }
    method step_item ($/) {  # Alternative of matches
        my @res = $/<ingredient cookware timer step_comment>.grep(*.so)>>.made.list;
        make @res;
    }
    method step_text ($/) {
        my $txt = ~$/.subst(/\n/, ' ', :g);
        make Step.new( type => 'text', value => $txt, orig => ~$/ );
    }
    method vertical ($/) {
        @.parts.push: Vertical.new( type => 'text', value => ~$/, orig => ~$/ )  if $/;
    }
    method ingredient ($/) {
        return   unless $/;
        my %res;
	for %res<measurement> {
	    $_ = self!measurement( $/, $!factor, units => "" );
            .quantity //= "some";
            .number   //= 1*$!factor;
        }
        %res<name> = $/<item_text> ?? ~$/<item_text> !! $/<item_word> ?? ~$/<item_word> !! "";
        %res<note> = ~$/<qamount><qanote>.trim  if $/<qamount> && $/<qamount><qanote>;
        %res<optional> = True  if $/<optional>;
        %res<orig> = ~$/;
        make Ingredient.new( |%res );
    }
    method cookware ($/) {
        return   unless $/;
        my %res;
	for %res<measurement> {
	    # Cookware has no units (see spec tests/README.md), and is not scaled (spec proposal 0010)
	    $_ = self!measurement( $/, 1 );
	    .units = Nil;
	}
        %res<name> = $/<item_text> ?? ~$/<item_text> !! ~$/<item_word>;
        %res<optional> = True  if $/<optional>;
        %res<orig> = ~$/;
        make Cookware.new( |%res );
    }
    method timer ($/) {
        return    unless $/;
        my %res;
	for %res<measurement> {
	    # Timers are not scaled (spec proposal 0010)
	    $_ = self!measurement( $/, 1, units => "" );
	}
        %res<name> = $/<item_text> ?? ~$/<item_text> !! $/<item_word> ?? ~$/<item_word> !! "";
        %res<orig> = ~$/;
        make Timer.new( |%res );
    }
    method qamount ($/) {
        my %res;
        %res<quantity> = $/<quantity>.made  if $/<quantity>;
        %res<units>    = $/<units> && $/<units>.made // "";
        %res<modifier> = $/<modifier>.made if $/<modifier>;
        %res<fixed>    = True  if $/<fixed>;
        %res<orig> = ~$/;
	make Measurement.new( |%res );
    }
    # The measurement of an item, scaled by $factor unless it is fixed
    method !measurement ( $/, $factor, *%default --> Measurement ) {
        my $m = $/<qamount> ?? $/<qamount>.made !! Measurement.new( |%default );
        self.num_parts( $m.quantity, $m.number, $m.fixed ?? 1 !! $factor );
        return $m;
    }
    # Turn the quantity text into a number, scaled by $factor, when possible:
    #   "2" -> 2,  "1/2" or "1 / 2" -> 0.5,  "1 1/2" -> 1.5,  "1-2" -> "1-2" (range, both ends scaled)
    # Anything else is kept as text, e.g. "a pinch" (with " * factor" when scaled).
    # A number with a leading zero, like "02", is text (spec).
    method num_parts ( $num_str is rw, $num is rw, $factor ) {
        return unless $num_str.defined;
        $num_str ~~ s:g/ \s* '/' \s* /\//;
        if $num_str ~~ / ^ \s* $ / {
            $num = 1;
        }
        elsif is-number($num_str) {
            $num = ( val($num_str) * $factor ).narrow;
        }
        elsif $num_str ~~ / ^ (<[0..9.]>+) (\s* '-' \s*) (<[0..9.]>+) $ / && is-number(~$0) && is-number(~$2) {
            # Range: scale both ends, and keep the author's spacing around '-'
            $num = ( val(~$0) * $factor ).narrow ~ $1 ~ ( val(~$2) * $factor ).narrow;
            $num_str = $num;
        }
        elsif $num_str.words > 1 && all($num_str.words) ~~ / ^ \d+ [ <[./]> \d+ ]? $ / {
            $num = ( ( [+] $num_str.words».Numeric ) * $factor ).narrow;  # Mixed number
        }
        else {
            $num = $num_str ~ ( $factor != 1 ?? " * $factor" !! "" );
        }
        $num_str = $num  if $num ~~ Real;
    }
    method units ($/) {
        make ~$/.trim;
    }
    method modifier ($/) {
        make ~$/.trim;
    }
    method quantity ($/) {
	make ~$/.trim  if $/ && ~$/ !~~ /^\s*$/;
    }
    # Metadata is only added when the whole line or front matter block has matched
    method metadata ($/) {
        @.parts.push: |( $/<metadata_line> // $/<metadata_group> ).made;
    }
    method metadata_line ($/) {
        make Metadata.new(
            meta_key   => ~$/<meta_key>.trim,
            meta_value => ~$/<meta_value>.trim,
            orig       => ~$/,
        );
    }
    method metadata_group ($/) {
        my $body = ~$/<metadata_body>;
        make [
            MetadataMarker.new( orig => ~$/<metadata_open> ~ $body ),
            |front-matter($body).map({ Metadata.new( meta_key => .key, meta_value => .value, orig => "" ) }),
            MetadataMarker.new( orig => ~$/<metadata_close> ),
        ];
    }
    method line_comment ($/) {
        push @.parts, Comment.new( value => comment-text($/), orig => ~$/ );
    }
    method step_comment ($/) {
        make          Comment.new( value => comment-text($/), orig => ~$/ );
    }
}

# The constructor resets $!recipe after trigger-recipe_file has run, so load it again here
submethod TWEAK {
    self!load-recipe_file  if $!recipe_file.defined && !$!recipe.defined;
}

# Read recipe from file (or list of files)
method trigger-recipe_file ($recipe_file) {
    self!load-recipe_file;
}

method !load-recipe_file {
    $!recipe = $!recipe_file.map(*.IO.slurp).join("\n\n");
    self!parse;
    self!scale-to-servings;
}

# Recipe text passed directly
method trigger-recipe ($recipe) {
    self!parse;
    self!scale-to-servings;
}

method trigger-servings ($servings) {
    self!scale-to-servings;
}

# Set the factor from the wanted servings and the recipe's 'servings' metadata.
# A recipe without 'servings' is for 1 serving (spec proposal 0010).
method !scale-to-servings {
    return  unless $!servings.defined && $!match;
    my $base = ( self.metadata<servings> // 1 ).Str.match(/ <[0..9.]>+ /);  # '2', or old style '2|4|6'
    self.factor = $!servings / ( $base && +$base ?? +$base !! 1 );
}

method trigger-factor ($factor) {
    self!parse;
}

# (Re)parse the recipe, scaled by the current factor
# Throws ParseError if the recipe can not be parsed
method !parse {
    return  unless $!recipe.defined;
    my $match = Recipe.subparse($!recipe, actions => RecipeActions.new( factor => $!factor // 1 ) );
    my $pos = $match ?? $match.to !! 0;
    if $pos < $!recipe.chars {
        $!match = Nil;
        ParseError.new(
            line => $!recipe.substr(0, $pos).lines.elems max 1,
            near => $!recipe.substr($pos, 20),
        ).throw;
    }
    $!match = $match;
}

# Return data
# Note that this removes a bit of info from the raw ast
# The removed fields are available directly from the object (see methods below).
method data {
    return $!match  unless $!match;
    my %res;
    %res<metadata> = self.metadata;
    %res<steps> = self.steps;
    return %res;
}

method parts( :$match?, CookBase :$split-by?, :$join-by?, :$data-type? ) {
    return Empty  unless $!match;
    my @list = $!match.made;
    @list .= grep( $match );
    @list = split-by(@list, $split-by)   if $split-by !=:= CookBase;
    @list = join-by(@list, $join-by)   if $join-by;
    @list = apply-data-type( @list, $data-type )   if $data-type;
    return @list;
}

# Split into paragraphs (steps) separated by an empty line.
# A single line break within a paragraph becomes a space,
# unless the line ends with a backslash, which forces a line break.
sub split-by( @list-in, CookBase $split-by ) {
    my @list-out;
    my $breaks = 0;
    for @list-in -> $p {
        if $p ~~ $split-by { $breaks++; next; }
        if !@list-out || $breaks >= 2 {
            @list-out.push: [];
        }
        elsif $breaks == 1 {
            my $last = @list-out[*-1][*-1];
            my $sep = ' ';
            if $last ~~ Step && $last.value ~~ / '\\' \h* $ / {
                @list-out[*-1][*-1] = $last.clone( value => $last.value.subst(/ \h* '\\' \h* $ /, ''), orig => $last.orig );
                $sep = "\n";
            }
            @list-out[*-1].push: Step.new( type => 'text', value => $sep, orig => $sep );
        }
        $breaks = 0;
        @list-out[*-1].push: $p;
    }
    return @list-out;
}

sub join-by( @list-in, $join-by ) {
    my @list-out;
    my $item;
    for @list-in -> $p {
        if $p ~~ List|Array {
            @list-out.push: join-by($p, $join-by);
            next;
        }
        if $p ~~ $join-by {
            if $item {
                $item = $item.clone( value => $item.value ~ $p.value, orig => $item.orig ~ $p.orig );
            }
            else {
                $item = $p;
            }
        }
        else {
            if $item {
                @list-out.push: $item;
                $item = Nil;
            }
            @list-out.push: $p;
        }
    }
    if ( $item ) {
        @list-out.push: $item;
        $item = Nil;
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
method steps ( :$data-type = 'spec-data' )  {
    return self.parts(
        match => * ~~ Step|Ingredient|Cookware|Timer|Vertical,
        join-by => * ~~ Step, # type 'text'
        split-by => Vertical,
        data-type => $data-type );
}
method steps_flat ( :$data-type = 'spec-data' )  {
    return self.parts(
        match => * ~~ Step|Ingredient|Cookware|Timer,
        join-by => * ~~ Step, # type 'text'
        data-type => $data-type );
}
method metadata {
    my %m;
    %m{.meta_key} = .meta_value for self.parts.grep( * ~~ Cooklang::Metadata );
    return %m;
}
method cook  { return self.parts>>.cook.join("") }
method human { return self.parts>>.human.join("") }

=begin pod

=begin NAME

Cooklang - C<Raku> C<Cooklang> parser

=end NAME

=begin SYNOPSIS

=begin code :lang<raku>
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
=end code

=end SYNOPSIS

=begin VERSION

    version 2.1.0

=end VERSION

=begin DESCRIPTION

Cooklang is a markup language for recipes, see L<Cooklang|https://cooklang.org/>
and the L<specification|https://github.com/cooklang/spec>.

This module parses a Cooklang recipe with a C<Raku> grammar and grammar actions,
and gives access to its metadata, ingredients, cookware, timers, comments and steps.
The specification tests (C<t/spec>, a git submodule of the specification) are part of the test suite.

=end DESCRIPTION

=begin SUPPORTED-SYNTAX

=item1 Ingredients C<@salt>, C<@ground black pepper{}>, C<@potato{2}>, C<@flour{200%g}>, with an optional note C<@salt{1%tsp;fine}>
=item1 Cookware C<#pot>, C<#frying pan{}>, C<#pan{2}> (cookware has no units)
=item1 Timers C<~{25%minutes}>, C<~eggs{3%minutes}>
=item1 Quantities as numbers C<2>, fractions C<1/2>, mixed numbers C<1 1/2>, ranges C<1-2> or text C<a pinch>
=item1 Steps: paragraphs separated by a blank line; a single line break is a space, unless the line ends with C<\>
=item1 Comments C<-- to end of line> and C<[- block -]>
=item1 Metadata as YAML front matter between C<---> lines, and C<<< >> key: value >>> lines
=item1 Optional ingredients and cookware C<@?thyme>, C<#?splatter guard{}> (spec proposal 0018)
=item1 Scaling with C<factor> or C<servings>; fixed quantities C<@salt{=1%tsp}>, cookware and timers are not scaled (spec proposal 0010)

Not supported yet: notes (C<< > text >>), sections (C<= Dough>), short-hand preparations
(C<@onion{1}(chopped)>) and references to other recipes (C<@./sauces/pesto{}>).
They are parsed as plain text or as an ordinary ingredient.

=end SUPPORTED-SYNTAX

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

## Running the tests

The specification tests are in a git submodule:

=begin code
    % git submodule update --init
    % prove -e 'raku -Ilib' t
=end code

=end INSTALLATION

=begin COMMUNITY
=item1 [Code repository Wiki and Issue Tracker](https://github.com/uniejo/cooklang-raku)
=item1 [Cooklang on raku.land](https://raku.land/zef:uniejo/Cooklang)
=end COMMUNITY

=begin SEE-ALSO
=item1 [Cooklang](https://cooklang.org/) and the [Cooklang specification](https://github.com/cooklang/spec)
=item1 [Cooklang for Perl](https://metacpan.org/dist/Cooklang) on MetaCPAN
=end SEE-ALSO

=begin AUTHOR
Erik Johansen - uniejo@users.noreply.github.com
=end AUTHOR

=begin COPYRIGHT
Erik Johansen 2023-2026
=end COPYRIGHT

=begin LICENSE
This software is licensed under the same terms as Perl itself.
=end LICENSE

=end pod
