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
use English qw(-no_match_vars);

use vars qw( %CACHE %BYTEUNITS @BYTEUNITORDER %STATIDX );

BEGIN {
    %BYTEUNITS = (
        B  => 1,
        KB => 1_024,
        MB => 1_048_576,
        GB => 1_073_741_824,
        TB => 1_099_511_627_776,
        PB => 1_125_899_906_842_624,
    );
    @BYTEUNITORDER = qw( B KB MB GB TB PB );

    %STATIDX = (
        dev          => 0,
        ino          => 1,
        mode         => 2,
        nlink        => 3,
        uid          => 4,
        gid          => 5,
        rdev         => 6,
        size         => 7,
        atime        => 8,
        mtime        => 9,
        lastmodified => 9,
        ctime        => 10,
        created      => 10,
        blksize      => 11,
        blocks       => 12,
    );
}

sub new {
    my ($this,$config)  = @_;
    my $class = ref($this) || $this;
    my $self  = {};
    bless $self, $class;
    $self->{config} = $config;
    $self->{db}     = $config->{db};
    $self->{cgi}    = $config->{cgi};
    $self->{backend}= $config->{backend};
    $self->initialize();
    return $self;
}

sub initialize {
    my $self = shift;
    
    ${$self}{BYTEUNITS}     = \%BYTEUNITS;
    ${$self}{BYTEUNITORDER} = \@BYTEUNITORDER;
    ${$self}{STATIDX}       = \%STATIDX;
    ${$self}{WEB_ID}        = 0;

    $main::LANG
        = ${$self}{cgi}->param('lang')
        || ${$self}{cgi}->cookie('lang')
        || $main::LANG
        || 'default';
    $main::ORDER
        = ${$self}{cgi}->param('order')
        || ${$self}{cgi}->cookie('order')
        || $main::ORDER
        || 'name';

    my $view
        = ${$self}{cgi}->param('view')
        || ${$self}{cgi}->cookie('view')
        || $main::VIEW
        || $main::SUPPORTED_VIEWS[0];
    my $svregex = '^(' . join( q{|}, @main::SUPPORTED_VIEWS ) . ')$';
    if ( $view ne $main::VIEW && $view =~ /$svregex/xms ) {
        $main::VIEW = $view;
    }
    return $view;
}

sub _read_tl_file {
    my ( $self, $fn, $dataref ) = @_;
    if ( open my $fh, '<', $fn ) {
        while (<$fh>) {
            chomp;
            if (/^\#/xms) { next; }
            if (/^(\S.*?)\s+"(.*)"\s*$/xms) {
                ${$dataref}{$1} = $2;
            }
        }
        close($fh) || carp("Cannot close $fn.");
    }
    else { carp("Cannot read $fn!"); }
    return;
}

sub _read_tl {
    my ( $self, $l ) = @_;
    my $fn = "${main::INSTALL_BASE}locale/webdav-ui_${l}.msg";
    if ( -e $fn ) {
        $self->_read_tl_file( $fn, $main::TRANSLATION{$l} );
        $main::TRANSLATION{$l}{x__READ__x} = 1;
    }
    return;
}

sub _read_extensions_tl {
    my ( $self, $l ) = @_;
    my $locales = ${$self}{config}{extensions}->handle('locales') || [];
    foreach my $lfn ( @{$locales} ) {
        main::debug("_read_extensions_tl($l): $lfn");
        foreach my $f ( ( 'default', $l ) ) {
            my $fn = $lfn . '_' . $f . '.msg';
            if ( -e $fn ) {
                $self->_read_tl_file( $fn, $main::TRANSLATION{$l} );
            }
        }
    }
    $main::TRANSLATION{$l}{x__EXTENSIONSREAD__x} = 1;
    return;
}

sub tl {
    my ( $self, $key, $default, @args ) = @_;
    if ( !defined $key ) { return $default; }
    if ( defined $default && exists $CACHE{$self}{tl}{$key}{$default} ) {
        return $CACHE{$self}{tl}{$key}{$default};
    }
    if ( !exists $main::TRANSLATION{default}{x__READ__x} ) {
        $self->_read_tl('default');
    }
    if ( !exists $main::TRANSLATION{$main::LANG}{x__READ__x} ) {
        $self->_read_tl($main::LANG);
    }
    if ( !exists $main::TRANSLATION{$main::LANG}{x__EXTENSIONSREAD__x} ) {
        $self->_read_extensions_tl($main::LANG);
    }
    my $val
        = $main::TRANSLATION{$main::LANG}{$key}
        || $main::TRANSLATION{default}{$key}
        || $default
        || $key;
    return $CACHE{$self}{tl}{$key}{ $default // $key }
        = $#args > -1 ? sprintf( $val, @args ) : $val;
}

sub set_locale {
    my $locale;
    if ( $main::LANG eq 'default' ) {
        $locale = "en_US.\U$main::CHARSET\E";
    }
    else {
        if ( $main::LANG =~ /^(\w{2})(_(\w{2})([.](\S+))?)?$/xms ) {
            my ( $c1, $c, $c3, $c4, $c5 ) = ( $1, $2, $3, $4, $5 );
            $c3 //= uc $c1;
            $c5 //= uc $main::CHARSET;
            $locale = "${c1}_${c3}.${c5}";
        }
    }
    setlocale( LC_COLLATE, $locale );
    setlocale( LC_TIME,    $locale );
    setlocale( LC_CTYPE,   $locale );
    setlocale( LC_NUMERIC, $locale );
    return;
}

sub get_cookies {
    my ($self) = @_;
    my @cookies = (
        ${$self}{cgi}->cookie(
            -name    => 'lang',
            -value   => $main::LANG,
            -expires => '+10y'
        ),
        ${$self}{cgi}->cookie(
            -name    => 'order',
            -value   => $main::ORDER,
            -expires => '+10y'
        ),
        ${$self}{cgi}->cookie(
            -name    => 'view',
            -value   => $main::VIEW,
            -expires => '+10y'
        ),
    );

    if ( !$main::SHOWDOTFILES ) {
        push @cookies,
            ${$self}{cgi}->cookie(
            -name  => 'settings.show.dotfiles',
            -value => ${$self}{cgi}->cookie('settings.show.dotfiles') || 'no'
            );
        push @cookies, ${$self}{cgi}
            ->cookie( -name => 'settings.show.dotfiles.keep', -value => 1 );
    }
    if ( !$main::SHOWDOTFOLDERS ) {
        push @cookies,
            ${$self}{cgi}->cookie(
            -name  => 'settings.show.dotfolders',
            -value => ${$self}{cgi}->cookie('settings.show.dotfolders')
                || 'no'
            );
        push @cookies, ${$self}{cgi}
            ->cookie( -name => 'settings.show.dotfolders.keep', -value => 1 );
    }

    return \@cookies;
}

sub replace_vars {
    my ( $self, $t, $v ) = @_;
    my $lt = localtime;
    $t =~ s/\${?NOW}?/strftime $self->tl('varnowformat'),$lt/exmsg;
    $t =~ s/\${?TIME}?/strftime $self->tl('vartimeformat'), $lt/exmsg;
    $t =~ s/\${?USER}?/$main::REMOTE_USER/xmsg;
    $t =~ s/\${?REQUEST_URI}?/$main::REQUEST_URI/xmsg;
    $t =~ s/\${?PATH_TRANSLATED}?/$main::PATH_TRANSLATED/xmsg;
    $t =~ s/\${?ENV{([^}]+?)}}?/$ENV{$1}/exmsg;
    my $clockfmt = $self->tl('vartimeformat');
    $t =~
        s{\${?CLOCK}?}{<span id="clock"></span><script>startClock('clock','$clockfmt');</script>}xmsg;
    $t =~ s/\${?LANG}?/$main::LANG/xmsg;
    $t =~ s/\${?TL{([^}]+)}}?/$self->tl($1)/exmsg;
    my $vbase = $self->get_vbase();
    $t =~ s/\${?VBASE}?/$vbase/xmsg;
    $t =~ s/\${?VHTDOCS}?/$vbase$main::VHTDOCS/xmsg;

    if ($v) {
        $t =~ s{\$\[(\w+)\]}{ $$v{$1} // "\$$1"}exmsg;
        $t =~ s{\${?(\w+)}?}{ $$v{$1} // "\$$1"}exmsg;
    }
    return $t;
}

sub cmp_strings {
    my ( $self, $str1, $str2 ) = @_;
    $CACHE{$self}{cmp_strings}{$str1} //= substr $str1, 0, 1;
    $CACHE{$self}{cmp_strings}{$str2} //= substr $str2, 0, 1;
    return $CACHE{$self}{cmp_strings}{$str1}
        cmp $CACHE{$self}{cmp_strings}{$str2} || $str1 cmp $str2;
}

sub cmp_files {
    my ( $self, $a, $b ) = @_;
    my $fp_a   = $main::PATH_TRANSLATED . $a;
    my $fp_b   = $main::PATH_TRANSLATED . $b;
    my $factor = $CACHE{$self}{cmp_files}{$main::ORDER}
        //= ( $main::ORDER =~ /_desc$/xms ) ? -1 : 1;
    $CACHE{$self}{cmp_files}{$fp_a} //= ${$self}{backend}->isDir($fp_a);
    $CACHE{$self}{cmp_files}{$fp_b} //= ${$self}{backend}->isDir($fp_b);

    return -1
        if $CACHE{$self}{cmp_files}{$fp_a}
        && !$CACHE{$self}{cmp_files}{$fp_b};
    return 1
        if !$CACHE{$self}{cmp_files}{$fp_a}
        && $CACHE{$self}{cmp_files}{$fp_b};

    if ( $main::ORDER =~ /^(lastmodified|created|size|mode)/xms ) {
        my $idx = $STATIDX{$1};
        return $factor * (
            ( ${$self}{backend}->stat($fp_a) )[$idx]
                <=> ( ${$self}{backend}->stat($fp_b) )[$idx]
                || $self->cmp_strings(
                ${$self}{backend}->getDisplayName($fp_a),
                ${$self}{backend}->getDisplayName($fp_b)
                )
        );
    }
    elsif ( $main::ORDER =~ /mime/xms ) {
        return $factor * (
            $self->cmp_strings( main::get_mime_type($a),
                main::get_mime_type($b) )
                || $self->cmp_strings(
                ${$self}{backend}->getDisplayName($fp_a),
                ${$self}{backend}->getDisplayName($fp_b)
                )
        );
    }
    return $factor * $self->cmp_strings(
        ${$self}{backend}->getDisplayName($fp_a),
        ${$self}{backend}->getDisplayName($fp_b)
    );
}

sub render_byte_val {
    my ( $self, $v, $f, $ft ) = @_;   # v-value, f-accuracy, ft-title accuracy
    use locale;
    $v  //= 0;
    $f  //= 2;
    $ft //= $f;
    my $showunit = 'B';
    my %rv;
    my $title        = q{};
    my $lowerlimitf  = 10**( -$f );
    my $lowerlimitft = 10**( -$ft );
    my $upperlimit   = 10_000_000_000;    # 10**10
    foreach my $unit (@BYTEUNITORDER) {
        $rv{$unit} = $v / $BYTEUNITS{$unit};
        last if $rv{$unit} < $lowerlimitf;
        if ( $rv{$unit} >= 1 ) { $showunit = $unit; }
        if ( $rv{$unit} >= $lowerlimitft && $rv{$unit} < $upperlimit ) {
            $title .=
                $unit eq 'B'
                ? sprintf ' = %.0fB ', $rv{$unit}
                : sprintf '= %.' . $ft . 'f%s ', $rv{$unit}, $unit;
        }
    }
    return (
        (     $showunit eq 'B'
            ? $rv{$showunit} . ( $v != 0 ? 'B' : q{} )
            : sprintf q{%.} . $f . q{f%s},
            $rv{$showunit},
            $showunit
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
        if ( exists $BYTEUNITS{$unit} ) { $val = $val * $BYTEUNITS{$unit}; }
        my $size = ( $backend->stat("$path$file") )[$STATIDX{size}];
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

    if ( ${$self}{backend}->isLink($fn) ) {
        $m = ( ${$self}{backend}->lstat($fn) )[$STATIDX{mode}];
    }
    my @ret = qw( - - - - - - - - - - );

    $ret[0] = ${$self}{backend}->isDir($fn)         ? 'd' : $ret[0];
    $ret[0] = ${$self}{backend}->isBlockDevice($fn) ? 'b' : $ret[0];
    $ret[0] = ${$self}{backend}->isCharDevice($fn)  ? 'c' : $ret[0];
    $ret[0] = ${$self}{backend}->isLink($fn)        ? 'l' : $ret[0];

    $ret[1] = ( $m & oct 400 ) == oct(400)         ? 'r' : q{-};
    $ret[2] = ( $m & oct 200 ) == oct(200)         ? 'w' : q{-};
    $ret[3] = ( $m & oct 100 ) == oct(100)         ? 'x' : q{-};
    $ret[3] = ${$self}{backend}->hasSetUidBit($fn) ? 's' : $ret[3];

    $ret[4] = ( $m & oct 40 ) == oct(40)           ? 'r' : q{-};
    $ret[5] = ( $m & oct 20 ) == oct(20)           ? 'w' : q{-};
    $ret[6] = ( $m & oct 10 ) == oct(10)           ? 'x' : q{-};
    $ret[6] = ${$self}{backend}->hasSetGidBit($fn) ? 's' : $ret[6];

    $ret[7] = ( $m & 4 ) == 4                      ? 'r' : q{-};
    $ret[8] = ( $m & 2 ) == 2                      ? 'w' : q{-};
    $ret[9] = ( $m & 1 ) == 1                      ? 'x' : q{-};
    $ret[9] = ${$self}{backend}->hasStickyBit($fn) ? 't' : $ret[9];

    return join q{}, @ret;
}

sub get_icon {
    my ( $self, $type ) = @_;
    return $CACHE{$self}{get_icon}{$type} //= $self->replace_vars(
        exists $main::ICONS{$type}
        ? $main::ICONS{$type}
        : $main::ICONS{default}
    );
}

sub has_thumb_support {
    my ( $self, $mime ) = @_;
    return
           $mime =~ /^image\//xms
        || $mime =~ /^text\/plain/xms
        || ( $main::ENABLE_THUMBNAIL_PDFPS
        && $mime =~ m{^application/(pdf|ps)$}xmsi );
}

sub can_create_thumb {
    my ( $self, $fn ) = @_;
    return
           $main::ENABLE_THUMBNAIL
        && $self->has_thumb_support( main::get_mime_type($fn) )
        && ${$self}{backend}->isFile($fn)
        && ${$self}{backend}->isReadable($fn)
        && !${$self}{backend}->isEmpty($fn);
}

sub get_visible_table_cols {
    my ($self) = @_;
    my @vc;
    my $avtcregex = '^(' . join( q{|}, @main::ALLOWED_TABLE_COLUMNS ) . ')$';
    if ( my $vcs = ${$self}{cgi}->cookie('visibletablecolumns') ) {
        my @cvc = split /,/xms, $vcs;
        my ($allowed) = 1;
        foreach my $c (@cvc) {
            if ( $c =~ /$avtcregex/xmsi ) {
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
        //= $self->_read_template( $filename, $tmplpath );
}

sub _read_template {
    my ( $self, $filename, $tmplpath ) = @_;
    my $text = q{};
    $filename =~ s/\//./xmsg;
    $filename .= -r "${tmplpath}/${filename}.custom.tmpl" ? '.custom' : q{};
    if ( open my $fh, '<', "${tmplpath}/${filename}.tmpl" ) {
        local $RS = undef;
        $text = <$fh>;
        close($fh) || carp("Cannot close ${tmplpath}/${filename}.tmpl");
        $text =~
            s/\$INCLUDE[(](.*?)[)]/$self->read_template($1,$tmplpath)/xmegs;
    }
    return $text;
}

sub _flex_sorter {
    return ( $a =~ /^[\d.]+$/xms && $b =~ /^[\d.]+$/xms )
        ? $a <=> $b
        : $a cmp $b;
}

sub render_each {
    my ( $self, %param ) = @_;
    my ( $fn, $ru, $variable, $tmplfile, $filter ) = (
        $param{fn},       $param{ru}, $param{variable},
        $param{tmplfile}, $param{filter},
    );
    my $tmpl
        = $tmplfile =~ /^'(.*)'$/xms ? $1 : $self->read_template($tmplfile);
    if ( defined $filter ) {
        $filter = $self->render_template( $fn, $ru, $filter );
    }
    my $content = q{};
    if ( $variable =~ s/^\%(?:main::)?//xms ) {
        my %hashvar = $main::{$variable} ? %{ $main::{$variable} } : ${$self}{$variable} ? %{${$self}{$variable}} : ();
        foreach my $key ( sort _flex_sorter keys %hashvar ) {
            next if defined $filter && $hashvar{$key} =~ $filter;
            my $t = $tmpl;
            $t =~ s/\$k/$key/xmsg;
            $t =~ s/\${k}/$key/xmsg;
            $t =~ s/\$v/$hashvar{$key}/xmsg;
            $t =~ s/\${v}/$hashvar{$key}/xmsg;
            $content .= $t;
        }
    }
    elsif ($variable =~ /\@/xms
        || $variable =~ /^[(](.*?)[)]$/xms
        || $variable =~ /^\$/xms )
    {
        my @arrvar;
        if ( $variable =~ /^\$(?:main::)?/xms ) {
            @arrvar = @{ $main::{$variable} };
        }
        elsif ( $variable =~ /^[(](.*?)[)]$/xms ) {
            @arrvar = split /,/xms, $1;
        }
        else {
            $variable =~ s/\@(?:main::)?//xmsg;
            @arrvar
                = $main::{$variable}       ? @{ $main::{$variable} }
                : ${$self}{$variable} ? @{ ${$self}{$variable} }
                :                            ();
        }
        foreach my $val (@arrvar) {
            next if defined $filter && $val =~ $filter;
            my $t = $tmpl;
            $t =~ s/\$[kv]/$val/xmsg;
            $t =~ s/\${[kv]}/$val/xmsg;
            $content .= $t;
        }
    }
    return $content;
}

sub exec_template_function {
    my ( $self, $fn, $ru, $func, $param ) = @_;

    if ( $func eq 'config' ) {
        return $param && $main::{$param} ? ${ $main::{$param} } // q{} : q{};
    }
    if ( $func eq 'env' ) {
        return $ENV{$param} // q{};
    }
    if ( $func eq 'tl' ) {
        return $self->tl($param);
    }
    if ( $func eq 'cgiparam' ) {
        return ${$self}{cgi}->param($param) // q{};
    }
    return q{};
}

sub render_template {
    my ( $self, $fn, $ru, $content, $vars ) = @_;

    $vars //= {};

    my $cgi      = ${$self}{cgi};    ## allowes easer access from templates
    my $anyng_rx = qr{(.*?)}xms;
    my $cond_rx = qr{[(]${anyng_rx}[)]}xms;

    # replace eval:
    $content =~ s/\$eval(.)${anyng_rx}\1/eval($2)/xmegs;

    # replace each:
    $content =~
        s/\$each(.)${anyng_rx}\1${anyng_rx}\1((.)${anyng_rx}\5\1)?/$self->render_each(fn=>$fn,ru=>$ru,variable=>$2,tmplfile=>$3,filter=>$6)/exmsg;

    # replace functions:
    while ( $content =~
        s/\$(\w+)[(]([^)]*)[)]/$self->exec_template_function($fn,$ru,$1,$2)/xmesg
        )
    {
    }

    $content =~ s/\${?ENV{([^}]+?)}}?/$ENV{$1}/exmsg;
    $content =~ s/\${?TL{([^}]+)}}?/$self->tl($1)/exmsg;

    my $vbase = $self->get_vbase();

    # replace standard variables:
    $vars = {
        uri           => $ru,
        baseuri       => ${$self}{cgi}->escapeHTML($vbase),
        maxuploadsize => $main::POST_MAX_SIZE,
        maxuploadsizehr =>
            ( $self->render_byte_val( $main::POST_MAX_SIZE, 2, 2 ) )[0],
        view            => $main::VIEW,
        viewname        => $self->tl("${main::VIEW}view"),
        USER            => $main::REMOTE_USER,
        REQUEST_URI     => $main::REQUEST_URI,
        PATH_TRANSLATED => $main::PATH_TRANSLATED,
        LANG            => $main::LANG,
        VBASE           => ${$self}{cgi}->escapeHTML($vbase),
        VHTDOCS         => $vbase . $main::VHTDOCS,
        RELEASE         => $main::RELEASE,
        q{.}            => scalar time(),
        %{$vars},
    };

    $content =~ s/\$\[([\w.]+)\]/exists $$vars{$1}?$$vars{$1}:"\$$1"/exmsg;
    $content =~ s/\${?([\w.]+)}?/exists $$vars{$1}?$$vars{$1}:"\$$1"/exmsg;
    $content =~
        s/<!--IF${cond_rx}-->${anyng_rx}((<!--ELSE-->)(.*?))?<!--ENDIF-->/eval($1)? $2 : $5 ? $5 : q{}/exmsg;
    $content =~
        s/<!--IF(\#\d+)${cond_rx}-->${anyng_rx}((<!--ELSE\1-->)${anyng_rx})?<!--ENDIF\1-->/eval($2)? $3 : $6 ? $6 : q{}/exmesg;
    return $content;
}

sub get_vbase {
    return $main::REQUEST_URI =~ /^($main::VIRTUAL_BASE)/xms
        ? $1
        : $main::REQUEST_URI;
}

sub is_unselectable {
    my ( $self, $fn ) = @_;
    my $unselregex
        = @main::UNSELECTABLE_FOLDERS
        ? '(' . join( q{|}, @main::UNSELECTABLE_FOLDERS ) . ')'
        : '___cannot match___';
    return ${$self}{backend}->basename($fn) eq q{..}
        || $fn =~ /^$unselregex$/xms;
}

sub quote_ws {
    my ( $self, $filename ) = @_;
    $filename =~ s{([ ]{2,})}{<span class="ws">$1</span>}xmsg;
    return $filename;
}

sub is_filtered_view {
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
    $precision //= 1;
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
