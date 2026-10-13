unit class Cooklang:ver<2.0.1>:auth<zef:uniejo>;
use AttrX::Mooish;

has $.recipe_file  is rw  is mooish(:trigger);
has $.recipe       is rw  is mooish(:trigger);
has $.factor       is rw  is mooish(:trigger) = 1;
has $.match        is rw;

grammar Recipe {
    rule TOP            { <line>+ }
    token ws            { <!ww> \h* }  # rule can have ws between all parts
    token line          { [ <metadata> | <line_comment> | <step>+ | <vertical> ] <vertical>? }
    token step          { <step_item> | <step_text> }
    token step_item     { <ingredient> | <cookware> | <timer> | <step_comment> }
    token metadata      { <metadata_line> | <metadata_group> }
    rule  metadata_group { :m ^ '---' \h* \v  ~  '---'   <metadata_group_line>* }
    rule  metadata_line  {      '>>'  <meta_key> ':' <meta_value> \v }
    rule  metadata_group_line { <meta_key> ':' <meta_value> \v }
    rule  non_metadata_group { '---' \h* \v  ~  '---'  .*? }
    token ingredient    { '@' <!before \h>  [ <item_text> <qamount> | <item_word> ]  }
    token cookware      { '#' <!before \h>  [ <item_text> <qamount> | <item_word> ]  }
    token timer         { '~' <!before \h>  [ <item_text>? <qamount> | <item_word> ] }
    token qamount       { '{'  ~  '}'   [ [ <quantity> [ '%' <units> ]? ]? [ '//' <modifier> ]? [ ';' <qanote> ]? | <qamount_HUH> ] }
    token line_comment  { <comment> \v | <block_comment> }
    token step_comment  { <comment> | <block_comment> }
    token comment       { <!after '-'> '--' <!before '-' > <( \V* )> }
    token block_comment { '[-'  ~  '-]'   .*? }
    token meta_key      { <- [\:] >+ }    # except for ':'
    token meta_value    { \V+ }           # except for vertical space (new line)
    token item_text     { [ <!before <step_item> | '{' > \V ]+ }  # except for '{' and <step_item>
 #  token item_word     { [ ^ { \s \p{P} }]+ }  # except for '{', whitespace, punctuation
    token item_word     { <-[{\s] - :P>+ }  # except for '{', whitespace, punctuation (Unicode P*)
    token step_text     { [ <!before <step_item>> [ <non_metadata_group> | \V ] ]+ }  # Non-vertial as long as it does not match <step_item> (full match)
    token number        { <number_part> [\s+ <reci> ] ? | <reci>  }
    rule  reci          { <intval> '/' <intval> }
    token intval        { <[1..9.]><[0..9]>* }
    token number_part   { <[1..9.]><[0..9.]>* }
    token quantity      { <quant_text>  }
    token quantityY     { <number> | <quant_text>  }
    token quant_text    { [ <!before ['%'|'//'|';'|'}'] > . ]* }
    token units         { [ <!before [    '//'|';'|'}'] > . ]+ }
    token modifier      { [ <!before [         ';'|'}'] > . ]+ }
    token qanote        { [ <!before [             '}'] > . ]+ }
    token qamount_HUH   { [ <!before [             '}'] > . ]* }
    token hspace        { \h }
    token vertical      { \v [ \h+ <?before \v> ]? }  # a whitespace-only line counts as blank
#   Note \h is horisontal white space. ie. \s - \v
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
        my $n = self.number;
        return $n ~~ Real && $n != 1;
    }
    submethod human ( $item? is copy ) {
        return Empty  unless self.quantity || self.units || self.modifier || $item;
	my $quantity = self.quantity;
	# Singular/pluralis of $item
	if ( self.pluralis ) {
            # Pluralis
            $item.=subst(/$/, "s") if $item;
        }
	else {
            # Signular (or default a/an)
            $item.=subst(/s$/, "") if $item;
	    $quantity ||= $item ~~ /^[aeiouy]/ ?? 'an' !! 'a'  if $item;
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
    # Do not use submethod BUILD { } as that may prevent value input
    submethod TWEAK() {
        self.measurement.quantity //= 1;
    }
    submethod human (--> Str:D) {
        return self.measurement.human(self.name);
    }
}
class Ingredient does CookBase does CookMeasurement {
    has $.note;
    submethod TWEAK() {
        self.measurement.quantity //= "some";
    }
    submethod gist (--> Str:D) {
        return self.orig;
    }
    submethod human (--> Str:D) {
        return self.measurement.human(self.name);
    }
}
class Timer does CookBase does CookMeasurement {
    submethod TWEAK() {
     #   self.measurement.units    //= Nil;
        self.measurement.quantity //= "";
    }
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
        my @res = $/<ingredient cookware timer step_comment>.grep(*.so)>>.made.list;
        make @res;
    }
    method step_text ($/) {
        my $txt = ~$/.subst(/\n/, ' ', :g);
        make Step.new( type => 'text', value => $txt, orig => $txt );
    }
    method vertical ($/) {
        @.parts.push: Vertical.new( type => 'text', value => ~$/, orig => ~$/ )  if $/;
    }
    method ingredient ($/) {
        return   unless $/;
        my %res;
	for %res<measurement> {
	    $_ = $/<qamount> && $/<qamount>.made // Measurement.new( units => "" );
	#   say "Ingredient { $/ } : quantity from qamount.made measurement: { .quantity.raku }";
        # qamount and quantity at the same time - One has to go
            #.quantity //= 1*$!factor;
            .quantity //= "some";
	    # say "Ingredient { $/ } : quantity now: { .quantity.raku }";
            .number   //= 1*$!factor;
        }
        %res<name> = $/<item_text> ?? ~$/<item_text> !! $/<item_word> ?? ~$/<item_word> !! "";
        %res<note> = ~$/<qamount><qanote>.trim  if $/<qamount> && $/<qamount><qanote>;
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
               # val() returns a plain Str (no Failure) for non-numbers like "7 k"
               my $n = val($num_str);
               die unless $n ~~ Numeric;
               $n.Numeric * $factor
           } //
        # $q_nosp ~~ /^([1-9]\d*)-(([1-9]\d*)$/ ?? try { [$1,$2].map{* * $.factor}.join("-") } //
           $num_str ~~  /^(<[0..9.]>+)\s*"-"\s*(<[0..9.]>+)$/ && try { # Make quantity range numeric (if possible), and back to range string TODO? no zero prefix
	       join ' - ', map { die if /^0\d/; 0+$_*$factor }, $/[0], $/[1];

           } //
           $num_str ~ ($factor != 1 ?? " * {$factor}" !! "");  # Otherwise use trimmed text (but add factor if present)

      # say "Measurement {$/} * { $.factor } = {$res.raku}";
        # Mixed number like "1 1/2" becomes 1.5
        if $num ~~ Str && $num_str.words > 1 && $num_str.words.all ~~ /^ <[0..9]>+ [ <[./]> <[0..9]>+ ]? $/ {
            $num = ([+] $num_str.words.map(*.Numeric)) * $factor;
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
    }
#    method metadata_group ($/) {
#        my %res;
#say "Processing metadata_group " ~ ~$/;
#        # TODO
##for %res<metadata_group_line> {
##           #  %res<meta_key>   = ~$/<meta_key>.trim;
##           #  %res<meta_value> = ~$/<meta_value>.trim;
##    $_ = $/<qamount> && $/<qamount>.made // Measurement.new( units => "" );
##    say "Ingredient { $/ } : quantity from qamount.made measurement: { .quantity.raku }";
##       # qamount and quantity at the same time - One has to go
##           #.quantity //= 1*$!factor;
##           .quantity //= "some";
##    say "Ingredient { $/ } : quantity now: { .quantity.raku }";
#      #     .number   //= 1*$!factor;
#      #     .modifier = ~$/<modifier>  if $/<modifier>;
#      # }
#      # %res<orig> = ~$/;
#      # push @.parts, Metadata.new( |%res );
#    }
    method metadata_line ($/) {
#say "Processing metadata_line " ~ ~$/;
        my %res;
        %res<meta_key>   = ~$/<meta_key>.trim;
        %res<meta_value> = ~$/<meta_value>.trim;
        %res<orig> = ~$/;
        push @.parts, Metadata.new( |%res );
    }
    method metadata_group_line ($/) {
#say "Processing metadata_group_line { (~$/).raku }";
        my %res;
        %res<meta_key>   = ~$/<meta_key>.trim;
        %res<meta_value> = ~$/<meta_value>.trim;
        %res<orig> = ~$/;
        push @.parts, Metadata.new( |%res );
    }
    method line_comment ($/) {
        push @.parts, Comment.new( value => ~( $/<comment> // $/<block_comment> ).trim );
    }
    method step_comment ($/) {
        make          Comment.new( value => ~( $/<comment> // $/<block_comment> ).trim );
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
method !parse {
    return  unless $!recipe.defined;
    $!match = Recipe.parse($!recipe, actions => RecipeActions.new( factor => $!factor // 1 ) );
}

# Return data
# Note that this removes a bit of info from the raw ast
# The removed fields are available directly from the object (see methods below).
method data {
    return $!match  unless $!match && $!match.made;
    my %res;
    %res<metadata> = self.metadata;
 #  %res<metadata> = $[]  unless %res<metadata> && %res<metadata>.?keys;
    %res<steps> = self.steps;
 #  %res<steps> = $[]  unless %res<steps>;
    return %res;
}

submethod parts( :$match?, CookBase :$split-by?, :$join-by?, :$data-type? ) {
    return Empty  unless $!match && $!match.made;
    my @list = $!match.made;
    @list .= grep( $match );# if $match;#   if $type.^name ne 'Any';
    @list = split-by(@list, $split-by)   if $split-by.^name ne 'Cooklang::CookBase';
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
#say "Processing join-by";
    for @list-in -> $p {
        if $p ~~ List|Array {
#say "Processing join-by list >  " ~ $p;
            @list-out.push: join-by($p, $join-by);
            next;
        }
#say "Processing join-by item     " ~ $p.orig;
        if $p ~~ $join-by {
            if $item {
                $item = $item.clone( value => $item.value ~ $p.value, orig => $item.orig ~ $p.orig );
#say "Processing join-by item 1 +   = " ~ $p.value;
            }
            else {
#say "Processing join-by item 1 . ";
                $item = $p;
            }
        }
        else {
            if $item {
#say "Processing join-by item 0 >    = " ~ $item.value;
                @list-out.push: $item;
                $item = Nil;
            }
#say "Processing join-by item 0 > " ~ $p;
            @list-out.push: $p;
        }
    }
    if ( $item ) {
#say "Processing join-by item L > " ~ $item.value;
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
