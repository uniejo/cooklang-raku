unit class Cooklang:ver<2.0.1>:auth<zef:uniejo>;
use AttrX::Mooish;

class ParseError is Exception {
    has $.line;
    has $.near;
    method message { "Unable to parse recipe at line $!line near '$!near'" }
}

has $.recipe_file  is rw  is mooish(:trigger);
has $.recipe       is rw  is mooish(:trigger);
has $.factor       is rw  is mooish(:trigger) = 1;
has $.match        is rw;

grammar Recipe {
    rule  TOP             { <line>* }
    token ws              { <!ww> \h* }  # A rule only skips horizontal space (not line breaks)
    token line            { [ <metadata> | <line_comment> | <step>+ | <vertical> ] <vertical>? }
    token step            { <step_item> | <step_text> }
    token step_item       { <ingredient> | <cookware> | <timer> | <step_comment> }
    token step_text       { [ <!before <step_item>> \V ]+ }  # Text up to the next item or line break
    token vertical        { \v [ \h+ <?before \v> ]? }      # A whitespace-only line counts as blank

    # Metadata: '>> key: value' lines, or a front matter block at the very start (^) of the recipe
    token metadata        { <metadata_line> | <metadata_group> }
    rule  metadata_line   { '>>' <meta_key> ':' <meta_value> \v }
    rule  metadata_group  { ^ <metadata_open> <metadata_group_line>* <metadata_close> }
    rule  metadata_group_line { <meta_key> ':' <meta_value> \v }
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

    # {quantity%units//modifier;note}: every part is optional and ends where a later part starts
    token qamount         { '{' ~ '}' [ <quantity> [ '%' <units> ]? [ '//' <modifier> ]? [ ';' <qanote> ]? ] }
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
	for <<quantity units modifier>> {
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
    has $.meta_value;
    method human (--> Str:D) {
        return "( {self.meta_key} {self.meta_value} )";
    }
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
	    $_ = $/<qamount> && $/<qamount>.made // Measurement.new( units => "" );
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
	    # Cookware has no units (see spec tests/README.md)
	    $_ = $/<qamount> && $/<qamount>.made.clone( units => Nil ) // Measurement.new( units => Nil );
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
	    $_ = $/<qamount> && $/<qamount>.made // Measurement.new( units => "" );
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
        %res<orig> = ~$/;
        self.num_parts( %res<quantity>, %res<number>, $!factor );
	make Measurement.new( |%res );
    }
    # Turn the quantity text into a number, scaled by $factor, when possible:
    #   "2" -> 2,  "1/2" or "1 / 2" -> 0.5,  "1 1/2" -> 1.5,  "1-2" -> "1 - 2" (range)
    # Anything else is kept as text, e.g. "a pinch" (with " * factor" when scaled).
    # A number with a leading zero, like "02", is text (spec).
    method num_parts ( $num_str is rw, $num is rw, $factor ) {
        return unless $num_str.defined;
        $num_str ~~ s:g/ \s* '/' \s* /\//;
        if $num_str ~~ / ^ \s* $ / {
            $num = 1;
        }
        elsif is-number($num_str) {
            $num = val($num_str) * $factor;
        }
        elsif $num_str ~~ / ^ (<[0..9.]>+) \s* '-' \s* (<[0..9.]>+) $ / && is-number(~$0) && is-number(~$1) {
            $num = ( $0, $1 ).map({ val(~$_) * $factor }).join(' - ');
        }
        elsif $num_str.words > 1 && all($num_str.words) ~~ / ^ \d+ [ <[./]> \d+ ]? $ / {
            $num = ( [+] $num_str.words».Numeric ) * $factor;  # Mixed number
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
    method metadata_group_line ($/) {
        self.metadata_line($/);
    }
    method metadata_group ($/) {
        make [
            MetadataMarker.new( orig => ~$/<metadata_open> ),
            |$/<metadata_group_line>».made,
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
}

# Recipe text passed directly
method trigger-recipe ($recipe) {
    self!parse;
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
                @list-out[*-1][*-1] = $last.clone( value => $last.value.subst(/ '\\' \h* $ /, ''), orig => $last.orig );
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
    my $source_text = $recipe.cook;     # Same as the original recipe text
    ...
    # A recipe that can not be parsed throws Cooklang::ParseError
    CATCH { when Cooklang::ParseError { note .message } }
=end code

=end SYNOPSIS

=begin VERSION

    version 2.0.1

=end VERSION

=begin AVAILABILITY

Cooklang is implemented in C<Raku> using grammar and grammar action to parse and build AST tree.

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
