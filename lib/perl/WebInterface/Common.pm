#!/usr/bin/perl
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2011 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
#########################################################################
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#########################################################################

package WebInterface::Common;

use strict;
use warnings;

our $VERSION = '2.0';

use CGI::Carp;
use POSIX qw( strftime ceil locale_h );
use List::MoreUtils qw( any );
use FileUtils;

use vars qw( %CACHE %BYTEUNITS @BYTEUNITORDER );

%BYTEUNITS = (
    B  => 1,
    KB => 1_024,
    MB => 1_048_576,
    GB => 1_073_741_824,
    TB => 1_099_511_627_776,
    PB => 1_125_899_906_842_624,
);
@BYTEUNITORDER = ( 'B', 'KB', 'MB', 'GB', 'TB', 'PB', );

sub new {
    my $this  = shift;
    my $class = ref($this) || $this;
    my $self  = {};
    bless $self, $class;
    $$self{config} = shift;
    $$self{db}     = shift;
    $self->initialize();
    return $self;
}

sub initialize {
    my $self = shift;
    $$self{cgi}     = $$self{config}->getProperty('cgi');
    $$self{backend} = $$self{config}->getProperty('backend');

    $$self{BYTEUNITS}     = \%BYTEUNITS;
    $$self{BYTEUNITORDER} = \@BYTEUNITORDER;
    $$self{WEB_ID}        = 0;

    $main::LANG
        = $$self{cgi}->param('lang')
        || $$self{cgi}->cookie('lang')
        || $main::LANG
        || 'default';
    $main::ORDER
        = $$self{cgi}->param('order')
        || $$self{cgi}->cookie('order')
        || $main::ORDER
        || 'name';

    my $view
        = $$self{cgi}->param('view')
        || $$self{cgi}->cookie('view')
        || $main::VIEW
        || $main::SUPPORTED_VIEWS[0];
    my $svregex = '^(' . join( '|', @main::SUPPORTED_VIEWS ) . ')$';
    $main::VIEW = $view if $view ne $main::VIEW && $view =~ /$svregex/;
    return $view;
}

sub readTLFile {
    my ( $self, $fn, $dataRef ) = @_;
    if ( open( my $i, '<', $fn ) ) {
        while ( my $line = <$i> ) {
            chomp($line);
            next if $line =~ /^#/;
            if ( $line =~ /^(\S.*?)\s+"(.*)"\s*$/ ) {
                $$dataRef{$1} = $2;
            }
        }
        close($i);
    }
    else { carp("Cannot read $fn!"); }
}

sub readTL {
    my ( $self, $l ) = @_;
    my $fn
        = -e "${main::INSTALL_BASE}locale/webdav-ui_${l}.msg"
        ? "${main::INSTALL_BASE}locale/webdav-ui_${l}.msg"
        : undef;
    return unless defined $fn;
    $self->readTLFile( $fn, $main::TRANSLATION{$l} );
    $main::TRANSLATION{$l}{x__READ__x} = 1;
}

sub readViewTL {
    my ( $self, $l ) = @_;
    my $fn
        = -e "${main::INSTALL_BASE}lib/perl/WebInterface/View/$main::VIEW/locale/locale_${l}.msg"
        ? "${main::INSTALL_BASE}lib/perl/WebInterface/View/$main::VIEW/locale/locale_${l}.msg"
        : undef;
    return unless defined $fn;
    $self->readTLFile( $fn, $main::TRANSLATION{$l} );
    $main::TRANSLATION{$l}{x__VIEWREAD__x} = 1;
}

sub readExtensionsTL {
    my ( $self, $l ) = @_;
    my $locales = $$self{config}{extensions}->handle('locales') || [];
    foreach my $lfn ( @{$locales} ) {
        main::debug("readExtensionsTL($l): $lfn");
        foreach my $f ( ( 'default', $l ) ) {
            my $fn = $lfn . '_' . $f . '.msg';
            $self->readTLFile( $fn, $main::TRANSLATION{$l} ) if -e $fn;
        }
    }
    $main::TRANSLATION{$l}{x__EXTENSIONSREAD__x} = 1;
}

sub tl {
    my ( $self, $key, $default, @args ) = @_;
    if ( !defined $key ) { return $default; }
    return $CACHE{$self}{tl}{$key}{$default}
        if defined $default && exists $CACHE{$self}{tl}{$key}{$default};
    $self->readTL('default')
        if !exists $main::TRANSLATION{default}{x__READ__x};
    $self->readViewTL('default')
        if !exists $main::TRANSLATION{default}{x__VIEWREAD__x};
    $self->readTL($main::LANG)
        if !exists $main::TRANSLATION{$main::LANG}{x__READ__x};
    $self->readViewTL($main::LANG)
        if !exists $main::TRANSLATION{$main::LANG}{x__VIEWREAD__x};
    $self->readExtensionsTL($main::LANG)
        if !exists $main::TRANSLATION{$main::LANG}{x__EXTENSIONSREAD__x};

    my $val
        = $main::TRANSLATION{$main::LANG}{$key}
        || $main::TRANSLATION{default}{$key}
        || $default
        || $key;
    return $CACHE{$self}{tl}{$key}{ $default // $key }
        = $#args > -1 ? sprintf( $val, @args ) : $val;
}

sub setLocale {
    my $locale;
    if ( $main::LANG eq 'default' ) {
        $locale = "en_US.\U$main::CHARSET\E";
    }
    else {
        if ( $main::LANG =~ /^(\w{2})(_(\w{2})([.](\S+))?)?$/ ) {
            my ( $c1, $c, $c3, $c4, $c5 ) = ( $1, $2, $3, $4, $5 );
            $c3 = uc($c1) unless $c3;
            $c5 = uc($main::CHARSET)
                unless $c5 && uc($c5) eq uc($main::CHARSET);
            $locale = "${c1}_${c3}.${c5}";
        }
    }
    setlocale( LC_COLLATE, $locale );
    setlocale( LC_TIME,    $locale );
    setlocale( LC_CTYPE,   $locale );
    setlocale( LC_NUMERIC, $locale );
    return;
}

sub getCookies {
    my ($self) = @_;
    my @cookies = (
        $$self{cgi}->cookie(
            -name    => 'lang',
            -value   => $main::LANG,
            -expires => '+10y'
        ),
        $$self{cgi}->cookie(
            -name    => 'order',
            -value   => $main::ORDER,
            -expires => '+10y'
        ),
        $$self{cgi}->cookie(
            -name    => 'view',
            -value   => $main::VIEW,
            -expires => '+10y'
        ),
    );

    if ( !$main::SHOWDOTFILES ) {
        push @cookies,
            $$self{cgi}->cookie(
            -name  => 'settings.show.dotfiles',
            -value => $$self{cgi}->cookie('settings.show.dotfiles') || 'no'
            );
        push @cookies, $$self{cgi}
            ->cookie( -name => 'settings.show.dotfiles.keep', -value => 1 );
    }
    if ( !$main::SHOWDOTFOLDERS ) {
        push @cookies,
            $$self{cgi}->cookie(
            -name  => 'settings.show.dotfolders',
            -value => $$self{cgi}->cookie('settings.show.dotfolders') || 'no'
            );
        push @cookies, $$self{cgi}
            ->cookie( -name => 'settings.show.dotfolders.keep', -value => 1 );
    }

    return \@cookies;
}

sub replaceVars {
    my ( $self, $t, $v ) = @_;
    my $lt = localtime();
    $t =~ s/\${?NOW}?/strftime($self->tl('varnowformat'),$lt)/eg;
    $t =~ s/\${?TIME}?/strftime($self->tl('vartimeformat'), $lt)/eg;
    $t =~ s/\${?USER}?/$main::REMOTE_USER/g;
    $t =~ s/\${?REQUEST_URI}?/$main::REQUEST_URI/g;
    $t =~ s/\${?PATH_TRANSLATED}?/$main::PATH_TRANSLATED/g;
    $t =~ s/\${?ENV{([^}]+?)}}?/$ENV{$1}/eg;
    my $clockfmt = $self->tl('vartimeformat');
    $t =~
        s@\${?CLOCK}?@<span id="clock"></span><script>startClock('clock','$clockfmt');</script>@;
    $t =~ s/\${?LANG}?/$main::LANG/g;
    $t =~ s/\${?TL{([^}]+)}}?/$self->tl($1)/eg;
    $main::REQUEST_URI =~ /^($main::VIRTUAL_BASE)/;
    my $vbase = $1;
    $t =~ s/\${?VBASE}?/$vbase/g;
    $t =~ s/\${?VHTDOCS}?/$vbase$main::VHTDOCS/g;

    if ($v) {
        $t =~ s/\$\[(\w+)\]/exists $$v{$1}?$$v{$1}:"\$$1"/egs;
        $t =~ s/\$\{?(\w+)\}?/exists $$v{$1}?$$v{$1}:"\$$1"/egs;
    }
    return $t;
}

sub cmp_strings {
    $CACHE{ $_[0] }{cmp_strings}{ $_[1] } = substr( $_[1], 0, 1 )
        unless exists $CACHE{ $_[0] }{cmp_strings}{ $_[1] };
    $CACHE{ $_[0] }{cmp_strings}{ $_[2] } = substr( $_[2], 0, 1 )
        unless exists $CACHE{ $_[0] }{cmp_strings}{ $_[2] };
    return $CACHE{ $_[0] }{cmp_strings}{ $_[1] }
        cmp $CACHE{ $_[0] }{cmp_strings}{ $_[2] } || $_[1] cmp $_[2];
}

sub cmp_files {
    my ( $self, $a, $b ) = @_;
    my $fp_a = $main::PATH_TRANSLATED . $a;
    my $fp_b = $main::PATH_TRANSLATED . $b;
    my $factor
        = exists $CACHE{$self}{cmp_files}{$main::ORDER}
        ? $CACHE{$self}{cmp_files}{$main::ORDER}
        : ( $CACHE{$self}{cmp_files}{$main::ORDER}
            = ( $main::ORDER =~ /_desc$/ ) ? -1 : 1 );
    $CACHE{$self}{cmp_files}{$fp_a} = $$self{backend}->isDir($fp_a)
        unless exists $CACHE{$self}{cmp_files}{$fp_a};
    $CACHE{$self}{cmp_files}{$fp_b} = $$self{backend}->isDir($fp_b)
        unless exists $CACHE{$self}{cmp_files}{$fp_b};

    return -1
        if $CACHE{$self}{cmp_files}{$fp_a}
        && !$CACHE{$self}{cmp_files}{$fp_b};
    return 1
        if !$CACHE{$self}{cmp_files}{$fp_a}
        && $CACHE{$self}{cmp_files}{$fp_b};

    if ( $main::ORDER =~ /^(lastmodified|created|size|mode)/ ) {
        my $idx
            = $main::ORDER =~ /^lastmodified/ ? 9
            : $main::ORDER =~ /^created/      ? 10
            : $main::ORDER =~ /^mode/         ? 2
            :                                   7;
        return $factor * (
            ( $$self{backend}->stat($fp_a) )[$idx]
                <=> ( $$self{backend}->stat($fp_b) )[$idx]
                || $self->cmp_strings(
                $$self{backend}->getDisplayName($fp_a),
                $$self{backend}->getDisplayName($fp_b)
                )
        );
    }
    elsif ( $main::ORDER =~ /mime/ ) {
        return $factor * (
            $self->cmp_strings( main::get_mime_type($a),
                main::get_mime_type($b) )
                || $self->cmp_strings(
                $$self{backend}->getDisplayName($fp_a),
                $$self{backend}->getDisplayName($fp_b)
                )
        );
    }
    return $factor * $self->cmp_strings(
        $$self{backend}->getDisplayName($fp_a),
        $$self{backend}->getDisplayName($fp_b)
    );
}

sub escapeQuotes {
    my ( $self, $q ) = @_;
    $q =~ s/(["'])/\\$1/xmsg;
    return $q;
}

sub renderByteValue {
    my ( $self, $v, $f, $ft ) = @_;   # v-value, f-accuracy, ft-title accuracy
    $f  //= 2;
    $ft //= $f;
    my $showunit = 'B';
    my %rv;
    my $title        = '';
    my $lowerlimitf  = 10**( -$f );
    my $lowerlimitft = 10**( -$ft );
    my $upperlimit   = 10**10;
    foreach my $unit (@BYTEUNITORDER) {
        $rv{$unit} = $v / $BYTEUNITS{$unit};
        last if $rv{$unit} < $lowerlimitf;
        $showunit = $unit if $rv{$unit} >= 1;
        $title .= (
            $unit eq 'B'
            ? sprintf( ' = %.0fB ', $rv{$unit} )
            : sprintf( '= %.' . $ft . 'f%s ', $rv{$unit}, $unit )
        ) if $rv{$unit} >= $lowerlimitft && $rv{$unit} < $upperlimit;
    }
    return (
        (     $showunit eq 'B'
            ? $rv{$showunit} . ( $v != 0 ? 'B' : '' )
            : sprintf( '%.' . $f . 'f%s', $rv{$showunit}, $showunit )
        ),
        $title
    );

}

sub filter {
    my ( $self, $path, $file ) = @_;
    return 1 if FileUtils::filter( $path, $file );
    my $backend = main::getBackend();
    my $ret     = 0;
    my $filter  = ${$self}{cgi}->param('search.types')
        // ${$self}{cgi}->cookie('filter.types');
    if ( defined $filter ) {
        $ret |= $filter !~ /d/xms && $backend->isDir("$path$file");
        $ret |= $filter !~ /f/xms && $backend->isFile("$path$file");
        $ret |= $filter !~ /l/xms && $backend->isLink("$path$file");
        if ($ret) {
            return 1;
        }
    }

    $filter = ${$self}{cgi}->param('search.size')
        // ${$self}{cgi}->cookie('filter.size');
    if (   defined $filter
        && $backend->isFile("$path$file")
        && $filter =~ /^([\<\>\=]{1,2})(\d+)(\w*)$/xms )
    {
        my ( $op, $val, $unit ) = ( $1, $2, $3 );
        $val = $val * $BYTEUNITS{$unit} if exists $BYTEUNITS{$unit};
        my $size = ( $backend->stat("$path$file") )[7];
        $ret = $self->_handle_filter_operator( $size, $op, $val );
        if ($ret) { return 1; }
    }
    $filter = ${$self}{cgi}->param('search.name')
        || ${$self}{cgi}->cookie('filter.name');
    if (   defined $filter
        && defined $file
        && $filter =~ /^(=~|[\^\$]|eq|ne|lt|gt|le|ge)\s(.*)$/xms )
    {
        my ( $nameop, $nameval ) = ( $1, $2 );
        $nameval =~ s/\//\/\//xmsg;
        return $self->_handle_filter_operator( $file, $nameop, $nameval );
    }
    return 0;
}

sub _handle_filter_operator {
    my ( $self, $operand, $operator, $value ) = @_;
    if ( $operator eq q{=} ) {
        return $operand != $value;
    }
    if ( $operator eq q{<} ) {
        return $operand >= $value;
    }
    if ( $operator eq q{>} ) {
        return $operand <= $value;
    }
    if ( $operator eq q{^} ) {
        return $operand !~ /^\Q$value\E/xmsi;
    }
    if ( $operator eq q{$} ) {
        return $operand !~ /\Q$value\E$/xmsi;
    }
    if ( $operator eq q{=~} ) {
        return $operand !~ /\Q$value\E/xmsi;
    }
    if ( $operator eq 'eq' ) {
        return $operand ne $value;
    }
    if ( $operator eq 'ne' ) {
        return $operand eq $value;
    }
    if ( $operator eq 'lt' ) {
        return $operand ge $value;
    }
    if ( $operator eq 'gt' ) {
        return $operand le $value;
    }
    if ( $operator eq 'le' ) {
        return $operand gt $value;
    }
    if ( $operator eq 'ge' ) {
        return $operand lt $value;
    }
    return 0;
}

sub mode2str {
    my ( $self, $fn, $m ) = @_;

    $m = ( $$self{backend}->lstat($fn) )[2] if $$self{backend}->isLink($fn);
    my @ret = split( //, '-' x 10 );

    $ret[0] = 'd' if $$self{backend}->isDir($fn);
    $ret[0] = 'b' if $$self{backend}->isBlockDevice($fn);
    $ret[0] = 'c' if $$self{backend}->isCharDevice($fn);
    $ret[0] = 'l' if $$self{backend}->isLink($fn);

    $ret[1] = 'r' if ( $m & oct(400) ) == oct(400);
    $ret[2] = 'w' if ( $m & oct(200) ) == oct(200);
    $ret[3] = 'x' if ( $m & oct(100) ) == oct(100);
    $ret[3] = 's' if $$self{backend}->hasSetUidBit($fn);

    $ret[4] = 'r' if ( $m & oct(40) ) == oct(40);
    $ret[5] = 'w' if ( $m & oct(20) ) == oct(20);
    $ret[6] = 'x' if ( $m & oct(10) ) == oct(10);
    $ret[6] = 's' if $$self{backend}->hasSetGidBit($fn);

    $ret[7] = 'r' if ( $m & 4 ) == 4;
    $ret[8] = 'w' if ( $m & 2 ) == 2;
    $ret[9] = 'x' if ( $m & 1 ) == 1;
    $ret[9] = 't' if $$self{backend}->hasStickyBit($fn);

    return join( '', @ret );
}

sub getIcon {
    my ( $self, $type ) = @_;
    return $CACHE{$self}{getIcon}{$type} //= $self->replaceVars(
        exists $main::ICONS{$type}
        ? $main::ICONS{$type}
        : $main::ICONS{default}
    );    ## //
}

sub hasThumbSupport {
    my ( $self, $mime ) = @_;
    return
           $mime =~ /^image\//xms
        || $mime =~ /^text\/plain/xms
        || ( $main::ENABLE_THUMBNAIL_PDFPS
        && $mime =~ m{^application/(pdf|ps)$}xmsi );
}

sub getVisibleTableColumns {
    my ($self) = @_;
    my @vc;
    my $avtcregex = '^(' . join( '|', @main::ALLOWED_TABLE_COLUMNS ) . ')$';
    if ( my $vcs = $$self{cgi}->cookie('visibletablecolumns') ) {
        my @cvc = split( ',', $vcs );
        my ($allowed) = 1;
        foreach my $c (@cvc) {
            if ($c =~ /$avtcregex/xmsi) {
                push @vc, $c;
            } 
        }
    }
    else {
        @vc = @main::VISIBLE_TABLE_COLUMNS;
    }
    return @vc;
}

sub read_template {
    my ( $self, $filename, $tmplpath ) = @_;
    return $CACHE{template}{$tmplpath}{$filename}
        ||= $self->_read_template( $filename, $tmplpath );
}

sub _read_template {
    my ( $self, $filename, $tmplpath ) = @_;
    my $text = "";
    $filename =~ s/\//\./g;
    $filename .= '.custom' if -r "${tmplpath}/${filename}.custom.tmpl";
    if ( open( IN, "${tmplpath}/${filename}.tmpl" ) ) {
        my @tmpl = <IN>;
        close(IN);
        $text = join( "", @tmpl );
        $text =~ s/\$INCLUDE\((.*?)\)/$self->read_template($1,$tmplpath)/egs;
    }
    return $text;
}

sub createMsgQuery {
    my ( $self, $msg, $msgparam, $errmsg, $errmsgparam, $prefix ) = @_;
    $prefix = '' unless defined $prefix;
    my $query = "";
    $query .= ";${prefix}msg=$msg"       if defined $msg;
    $query .= ";$msgparam"               if $msgparam;
    $query .= ";${prefix}errmsg=$errmsg" if defined $errmsg;
    $query .= ";$errmsgparam"            if defined $errmsg && $errmsgparam;
    return "?t=" . time() . $query;
}

sub flexSorter {
    return $a <=> $b if ( $a =~ /^[\d\.]+$/ && $b =~ /^[\d\.]+$/ );
    return $a cmp $b;
}

sub renderEach {
    my ( $self, $fn, $ru, $variable, $tmplfile, $filter ) = @_;
    no strict 'refs';
    my $tmpl = $tmplfile =~ /^'(.*)'$/ ? $1 : $self->read_template($tmplfile);
    $filter = $self->render_template( $fn, $ru, $filter ) if defined $filter;
    my $content = "";
    if ( $variable =~ /^\%/ ) {
        $variable =~ s/^\%//;
        my %hashvar = %{"$variable"};
        foreach my $key ( sort flexSorter keys %hashvar ) {
            next if defined $filter && $hashvar{$key} =~ $filter;
            my $t = $tmpl;
            $t =~ s/\$k/$key/g;
            $t =~ s/\$\{k\}/$key/g;
            $t =~ s/\$v/$hashvar{$key}/g;
            $t =~ s/\$\{v\}/$hashvar{$key}/g;
            $content .= $t;
        }
    }
    elsif ($variable =~ /\@/
        || $variable =~ /^\((.*?)\)$/s
        || $variable =~ /^\$/ )
    {
        my @arrvar;
        if ( $variable =~ /^\$/ ) {
            @arrvar = @{ eval($variable) };
        }
        elsif ( $variable =~ /^\((.*?)\)$/s ) {
            @arrvar = split( /,/, $1 );
        }
        else {
            $variable =~ s/\@//g;
            @arrvar = @{"$variable"};
        }
        foreach my $val (@arrvar) {
            next if defined $filter && $val =~ $filter;
            my $t = $tmpl;
            $t =~ s/\$[kv]/$val/g;
            $t =~ s/\$\{[kv]\}/$val/g;
            $content .= $t;
        }
    }
    return $content;
}

sub exec_template_function {
    my ( $self, $fn, $ru, $func, $param ) = @_;
    no strict 'refs';
    my $content;

    $content = ${"main::${param}"} || '' if $func eq 'config';
    $content = $ENV{$param}        || '' if $func eq 'env';
    $content = $self->tl($param) if $func eq 'tl';
    $content = $$self{cgi}->param($param) ? $$self{cgi}->param($param) : ""
        if $func eq 'cgiparam';
    return $content;
}

sub render_template {
    my ( $self, $fn, $ru, $content, $vars ) = @_;

    $vars //= {};

    my $cgi = $$self{cgi};    ## allowes easer access from templates

    # replace eval:
    $content =~ s/\$eval(.)(.*?)\1/eval($2)/egs;

    # replace each:
    $content =~
        s/\$each(.)(.*?)\1(.*?)\1((.)(.*?)\5\1)?/$self->renderEach($fn,$ru,$2,$3,$6)/xmegs;

    # replace functions:
    while ( $content =~
        s/\$(\w+)\(([^\)]*)\)/$self->exec_template_function($fn,$ru,$1,$2)/xmesg
        )
    {
    }

    $content =~ s/\${?ENV{([^}]+?)}}?/$ENV{$1}/xmegs;
    $content =~ s/\${?TL{([^}]+)}}?/$self->tl($1)/xmegs;

    my $vbase = $ru =~ /^($main::VIRTUAL_BASE)/ ? $1 : $ru;

    # replace standard variables:
    $vars = {
        uri           => $ru,
        baseuri       => $$self{cgi}->escapeHTML($vbase),
        maxuploadsize => $main::POST_MAX_SIZE,
        maxuploadsizehr =>
            ( $self->renderByteValue( $main::POST_MAX_SIZE, 2, 2 ) )[0],
        view            => $main::VIEW,
        viewname        => $self->tl("${main::VIEW}view"),
        USER            => $main::REMOTE_USER,
        REQUEST_URI     => $main::REQUEST_URI,
        PATH_TRANSLATED => $main::PATH_TRANSLATED,
        LANG            => $main::LANG,
        VBASE           => $$self{cgi}->escapeHTML($vbase),
        VHTDOCS         => $vbase . $main::VHTDOCS,
        RELEASE         => $main::RELEASE,
        '.'             => scalar time(),
        %{$vars},
    };

    $content =~ s/\$\[([\w\.]+)\]/exists $$vars{$1}?$$vars{$1}:"\$$1"/xmegs;
    $content =~ s/\$\{?([\w\.]+)\}?/exists $$vars{$1}?$$vars{$1}:"\$$1"/xmegs;
    $content =~
        s/<!--IF\((.*?)\)-->(.*?)((<!--ELSE-->)(.*?))?<!--ENDIF-->/eval($1)? $2 : $5 ? $5 : ''/xmegs;
    $content =~
        s/<!--IF(\#\d+)\((.*?)\)-->(.*?)((<!--ELSE\1-->)(.*?))?<!--ENDIF\1-->/eval($2)? $3 : $6 ? $6 : ''/xmegs;
    return $content;
}

sub canCreateThumbnail {
    my ( $self, $fn ) = @_;
    return
           $main::ENABLE_THUMBNAIL
        && $self->hasThumbSupport( main::get_mime_type($fn) )
        && $$self{backend}->isFile($fn)
        && $$self{backend}->isReadable($fn)
        && !$$self{backend}->isEmpty($fn);
}

sub getVBase() {
    return $main::REQUEST_URI =~ /^($main::VIRTUAL_BASE)/xms
        ? $1
        : $main::REQUEST_URI;
}

sub isUnselectable {
    my ( $self, $fn ) = @_;
    my $unselregex
        = @main::UNSELECTABLE_FOLDERS
        ? '(' . join( '|', @main::UNSELECTABLE_FOLDERS ) . ')'
        : '___cannot match___';
    return $$self{backend}->basename($fn) eq '..'
        || $fn =~ /^$unselregex$/xms;
}

sub quoteWhiteSpaces {
    my ( $self, $filename ) = @_;
    $filename =~ s{([ ]{2,})}{<span class="ws">$1</span>}xmsg;
    return $filename;
}

sub isViewFiltered {
    my ($self) = @_;
    return 1
        if ${$self}{cgi}->param('search.name')
        || ${$self}{cgi}->param('search.types')
        || ${$self}{cgi}->param('search.size');
    return
           ${$self}{cgi}->cookie('filter.name')
        || ${$self}{cgi}->cookie('filter.types')
        || ${$self}{cgi}->cookie('filter.size') ? 1 : 0;
}

sub minify_html {
    my ( $self, $content ) = @_;
    $content =~ s/<!--.*?-->//xmsg;
    $content =~ s/[\r\n]/ /xmsg;

#$content=~s/\s{2,}/ /sg; ## bug: filenames with multiple spaces are not managable
#$content=~s/>\s{2,}</> </sg; ## bug: same problem
    return $content;
}

sub round {
    my ( $self, $float, $precision ) = @_;
    $precision = 1 unless defined $precision;
    my $ret = sprintf "%.${precision}f", $float;
    $ret =~ s/,(\d{0,$precision})$/.$1/xms;    # fix locale specific notation
    return $ret;
}

sub stat_matchcount {
    my ( $self, $string, $search ) = @_;
    if ( my @m = $string =~ /$search/xmsg ) {
        return $#m + 1;
    }
    return 0;
}

sub is_in {
    my ( $self, $string, $value ) = @_;
    return $string =~ m/\Q$value\E/xms;
}
1;
