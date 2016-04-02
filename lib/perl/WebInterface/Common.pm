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

use DefaultConfig qw(
  $CHARSET $ENABLE_THUMBNAIL $ENABLE_THUMBNAIL_PDFPS $INSTALL_BASE $LANG $ORDER
  $PATH_TRANSLATED $POST_MAX_SIZE
  $RELEASE $REMOTE_USER $REQUEST_URI $SHOWDOTFILES $SHOWDOTFOLDERS $VHTDOCS $VIEW
  $VIRTUAL_BASE %ICONS %TRANSLATION @ALLOWED_TABLE_COLUMNS @SUPPORTED_VIEWS
  @UNSELECTABLE_FOLDERS @VISIBLE_TABLE_COLUMNS %SUPPORTED_LANGUAGES %AUTOREFRESH
  @ALLOWED_TABLE_COLUMNS);
use HTTPHelper qw( get_mime_type );
use WebInterface::Translations qw( read_all_tl  );

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
    my ( $this, $config ) = @_;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    $self->{config}  = $config;
    $self->{db}      = $config->{db};
    $self->{cgi}     = $config->{cgi};
    $self->{backend} = $config->{backend};
    $self->initialize();
    return $self;
}

sub initialize {
    my $self = shift;

    $self->{BYTEUNITS}     = \%BYTEUNITS;
    $self->{BYTEUNITORDER} = \@BYTEUNITORDER;
    $self->{STATIDX}       = \%STATIDX;
    $self->{WEB_ID}        = 0;

    $LANG =
         $self->{cgi}->param('lang')
      || $self->{cgi}->cookie('lang')
      || $LANG
      || 'default';
    $ORDER =
         $self->{cgi}->param('order')
      || $self->{cgi}->cookie('order')
      || $ORDER
      || 'name';

    my $view =
         $self->{cgi}->param('view')
      || $self->{cgi}->cookie('view')
      || $VIEW
      || $SUPPORTED_VIEWS[0];
    my $svregex = '^(' . join( q{|}, @SUPPORTED_VIEWS ) . ')$';
    if ( $view ne $VIEW && $view =~ /$svregex/xms ) {
        $VIEW = $view;
    }
    return $view;
}


sub tl {
    my ( $self, $key, $default, @args ) = @_;
    if ( !defined $key ) { return $default; }
    if ( defined $default && exists $CACHE{tl}{$key}{$default} ) {
        return $CACHE{tl}{$key}{$default};
    }
    read_all_tl($self->{config}{extensions}, $LANG);
    my $val =
         $TRANSLATION{$LANG}{$key}
      // $TRANSLATION{default}{$key}
      // $default
      // $key;
    return $CACHE{tl}{$key}{ $default // $key } =
      scalar( @args > 0 ) ? sprintf( $val, @args ) : $val;
}

sub set_locale {
    my $locale;
    if ( $LANG eq 'default' ) {
        $locale = "en_US.\U$CHARSET\E";
    }
    else {
        if ( $LANG =~ /^(\w{2})(_(\w{2})([.](\S+))?)?$/xms ) {
            my ( $c1, $c, $c3, $c4, $c5 ) = ( $1, $2, $3, $4, $5 );
            $c3 //= uc $c1;
            $c5 //= uc $CHARSET;
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
        $self->{cgi}->cookie(
            -name    => 'lang',
            -value   => $LANG,
            -expires => '+10y'
        ),
        $self->{cgi}->cookie(
            -name    => 'order',
            -value   => $ORDER,
            -expires => '+10y'
        ),
        $self->{cgi}->cookie(
            -name    => 'view',
            -value   => $VIEW,
            -expires => '+10y'
        ),
    );

    if ( !$SHOWDOTFILES ) {
        push @cookies,
          $self->{cgi}->cookie(
            -name  => 'settings.show.dotfiles',
            -value => $self->{cgi}->cookie('settings.show.dotfiles') || 'no'
          );
        push @cookies, $self->{cgi}
          ->cookie( -name => 'settings.show.dotfiles.keep', -value => 1 );
    }
    if ( !$SHOWDOTFOLDERS ) {
        push @cookies,
          $self->{cgi}->cookie(
            -name  => 'settings.show.dotfolders',
            -value => $self->{cgi}->cookie('settings.show.dotfolders') || 'no'
          );
        push @cookies, $self->{cgi}
          ->cookie( -name => 'settings.show.dotfolders.keep', -value => 1 );
    }

    return \@cookies;
}

sub replace_vars {
    my ( $self, $t, $v ) = @_;
    my $lt = localtime;
    $t =~ s/\${?NOW}?/strftime $self->tl('varnowformat'),$lt/exmsg;
    $t =~ s/\${?TIME}?/strftime $self->tl('vartimeformat'), $lt/exmsg;
    $t =~ s/\${?USER}?/$REMOTE_USER/xmsg;
    $t =~ s/\${?REQUEST_URI}?/$REQUEST_URI/xmsg;
    $t =~ s/\${?PATH_TRANSLATED}?/$PATH_TRANSLATED/xmsg;
    $t =~ s/\${?ENV{([^}]+?)}}?/$ENV{$1}/exmsg;
    my $clockfmt = $self->tl('vartimeformat');
    $t =~
s{\${?CLOCK}?}{<span id="clock"></span><script>startClock('clock','$clockfmt');</script>}xmsg;
    $t =~ s/\${?LANG}?/$LANG/xmsg;
    $t =~ s/\${?TL{([^}]+)}}?/$self->tl($1)/exmsg;
    my $vbase = $self->get_vbase();
    $t =~ s/\${?VBASE}?/$vbase/xmsg;
    $t =~ s/\${?VHTDOCS}?/$vbase$VHTDOCS/xmsg;

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
    my $fp_a   = $PATH_TRANSLATED . $a;
    my $fp_b   = $PATH_TRANSLATED . $b;
    my $factor = $CACHE{$self}{cmp_files}{$ORDER} //=
      ( $ORDER =~ /_desc$/xms ) ? -1 : 1;
    $CACHE{$self}{cmp_files}{$fp_a} //= $self->{backend}->isDir($fp_a);
    $CACHE{$self}{cmp_files}{$fp_b} //= $self->{backend}->isDir($fp_b);

    return -1
      if $CACHE{$self}{cmp_files}{$fp_a}
      && !$CACHE{$self}{cmp_files}{$fp_b};
    return 1
      if !$CACHE{$self}{cmp_files}{$fp_a}
      && $CACHE{$self}{cmp_files}{$fp_b};

    if ( $ORDER =~ /^(lastmodified|created|size|mode)/xms ) {
        my $idx = $STATIDX{$1};
        return $factor * (
            ( $self->{backend}->stat($fp_a) )[$idx]
              <=> ( $self->{backend}->stat($fp_b) )[$idx]
              || $self->cmp_strings(
                $self->{backend}->getDisplayName($fp_a),
                $self->{backend}->getDisplayName($fp_b)
              )
        );
    }
    elsif ( $ORDER =~ /mime/xms ) {
        return $factor * (
            $self->cmp_strings( get_mime_type($a), get_mime_type($b) )
              || $self->cmp_strings(
                $self->{backend}->getDisplayName($fp_a),
                $self->{backend}->getDisplayName($fp_b)
              )
        );
    }
    return $factor * $self->cmp_strings(
        $self->{backend}->getDisplayName($fp_a),
        $self->{backend}->getDisplayName($fp_b)
    );
}

sub render_byte_val {
    my ( $self, $v, $f, $ft ) = @_;    # v-value, f-accuracy, ft-title accuracy
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
        (
              $showunit eq 'B'
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
    my $backend = $self->{config}->{backend};
    my $ret     = 0;
    my $filter  = $self->{cgi}->param('search.types')
      // $self->{cgi}->cookie('filter.types');
    if ( defined $filter ) {
        $ret |= $filter !~ /d/xms && $backend->isDir("$path$file");
        $ret |= $filter !~ /f/xms && $backend->isFile("$path$file");
        $ret |= $filter !~ /l/xms && $backend->isLink("$path$file");
        if ($ret) {
            return 1;
        }
    }

    $filter = $self->{cgi}->param('search.size')
      // $self->{cgi}->cookie('filter.size');
    if (   defined $filter
        && $backend->isFile("$path$file")
        && $filter =~ /^([\<\>\=]{1,2})(\d+)(\w*)$/xms )
    {
        my ( $op, $val, $unit ) = ( $1, $2, $3 );
        if ( exists $BYTEUNITS{$unit} ) { $val = $val * $BYTEUNITS{$unit}; }
        my $size = ( $backend->stat("$path$file") )[ $STATIDX{size} ];
        $ret = $self->_handle_filter_operator( $size, $op, $val );
        if ($ret) { return 1; }
    }
    $filter = $self->{cgi}->param('search.name')
      || $self->{cgi}->cookie('filter.name');
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

    if ( $self->{backend}->isLink($fn) ) {
        $m = ( $self->{backend}->lstat($fn) )[ $STATIDX{mode} ];
    }
    my @ret = qw( - - - - - - - - - - );

    $ret[0] = $self->{backend}->isDir($fn)         ? 'd' : $ret[0];
    $ret[0] = $self->{backend}->isBlockDevice($fn) ? 'b' : $ret[0];
    $ret[0] = $self->{backend}->isCharDevice($fn)  ? 'c' : $ret[0];
    $ret[0] = $self->{backend}->isLink($fn)        ? 'l' : $ret[0];

    $ret[1] = ( $m & oct 400 ) == oct(400)        ? 'r' : q{-};
    $ret[2] = ( $m & oct 200 ) == oct(200)        ? 'w' : q{-};
    $ret[3] = ( $m & oct 100 ) == oct(100)        ? 'x' : q{-};
    $ret[3] = $self->{backend}->hasSetUidBit($fn) ? 's' : $ret[3];

    $ret[4] = ( $m & oct 40 ) == oct(40)          ? 'r' : q{-};
    $ret[5] = ( $m & oct 20 ) == oct(20)          ? 'w' : q{-};
    $ret[6] = ( $m & oct 10 ) == oct(10)          ? 'x' : q{-};
    $ret[6] = $self->{backend}->hasSetGidBit($fn) ? 's' : $ret[6];

    $ret[7] = ( $m & 4 ) == 4                     ? 'r' : q{-};
    $ret[8] = ( $m & 2 ) == 2                     ? 'w' : q{-};
    $ret[9] = ( $m & 1 ) == 1                     ? 'x' : q{-};
    $ret[9] = $self->{backend}->hasStickyBit($fn) ? 't' : $ret[9];

    return join q{}, @ret;
}

sub get_icon {
    my ( $self, $type ) = @_;
    return $CACHE{$self}{get_icon}{$type} //= $self->replace_vars(
        exists $ICONS{$type}
        ? $ICONS{$type}
        : $ICONS{default}
    );
}

sub has_thumb_support {
    my ( $self, $mime ) = @_;
    return
         $mime =~ /^image\//xms
      || $mime =~ /^text\/plain/xms
      || ( $ENABLE_THUMBNAIL_PDFPS
        && $mime =~ m{^application/(pdf|ps)$}xmsi );
}

sub can_create_thumb {
    my ( $self, $fn ) = @_;
    return
         $ENABLE_THUMBNAIL
      && $self->has_thumb_support( get_mime_type($fn) )
      && $self->{backend}->isFile($fn)
      && $self->{backend}->isReadable($fn)
      && !$self->{backend}->isEmpty($fn);
}

sub get_visible_table_cols {
    my ($self) = @_;
    my @vc;
    my $avtcregex = '^(' . join( q{|}, @ALLOWED_TABLE_COLUMNS ) . ')$';
    if ( my $vcs = $self->{cgi}->cookie('visibletablecolumns') ) {
        my @cvc = split /,/xms, $vcs;
        my ($allowed) = 1;
        foreach my $c (@cvc) {
            if ( $c =~ /$avtcregex/xmsi ) {
                push @vc, $c;
            }
        }
    }
    else {
        @vc = @VISIBLE_TABLE_COLUMNS;
    }
    return @vc;
}

sub read_template {
    my ( $self, $filename, $tmplpath ) = @_;
    return $CACHE{template}{$tmplpath}{$filename} //=
      $self->_read_template( $filename, $tmplpath );
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

sub _get_varref {
    my ( $self, $str ) = @_;
    $str =~ s/^[@%\$](?:main::)?//xms;
    my $ref = $DefaultConfig::{$str} // $__PACKAGE__::{$str};
    if ( !defined $ref ) {
        if ( defined $self->{$str} ) {
            return $self->{$str};
        }
        return;
    }
    if ( defined ${$ref} ) {
        return \${$ref};
    }
    if ( @{$ref} ) {
        return \@{$ref};
    }
    if ( %{$ref} ) {
        return \%{$ref};
    }
    return;
}

sub render_each {
    my ( $self, %param ) = @_;
    my ( $fn, $ru, $variable, $tmplfile, $filter ) = (
        $param{fn},       $param{ru}, $param{variable},
        $param{tmplfile}, $param{filter},
    );
    my $tmpl =
      $tmplfile =~ /^'(.*)'$/xms ? $1 : $self->read_template($tmplfile);
    if ( defined $filter ) {
        $filter = $self->render_template( $fn, $ru, $filter );
    }
    my $content = q{};
    if ( $variable =~ s/^\%(?:)?//xms ) {
        my $hashref = $self->_get_varref($variable) // {};
        foreach my $key ( sort _flex_sorter keys %{$hashref} ) {
            next if defined $filter && $hashref->{$key} =~ $filter;
            my $t = $tmpl;
            $t =~ s/\$k/$key/xmsg;
            $t =~ s/\${k}/$key/xmsg;
            $t =~ s/\$v/$hashref->{$key}/xmsg;
            $t =~ s/\${v}/$hashref->{$key}/xmsg;
            $content .= $t;
        }
    }
    elsif ($variable =~ /\@/xms
        || $variable =~ /^[(](.*?)[)]$/xms
        || $variable =~ /^\$/xms )
    {
        my @arr;
        if ( $variable =~ /^[(](.*?)[)]$/xms ) {
            @arr = split /,/xms, $1;
        }
        else {
            @arr = @{ $self->_get_varref($variable) // [] };
        }
        foreach my $val (@arr) {
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
        return $param ? ${ $self->_get_varref($param) // \q{} } : q{};
    }
    if ( $func eq 'env' ) {
        return $ENV{$param} // q{};
    }
    if ( $func eq 'tl' ) {
        return $self->tl($param);
    }
    if ( $func eq 'cgiparam' ) {
        return $self->{cgi}->param($param) // q{};
    }
    return q{};
}

sub render_template {
    my ( $self, $fn, $ru, $content, $vars ) = @_;

    $vars //= {};

    my $cgi      = $self->{cgi};    ## allowes easer access from templates
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
        baseuri       => $self->{cgi}->escapeHTML($vbase),
        maxuploadsize => $POST_MAX_SIZE,
        maxuploadsizehr =>
          ( $self->render_byte_val( $POST_MAX_SIZE, 2, 2 ) )[0],
        view            => $VIEW,
        viewname        => $self->tl("${VIEW}view"),
        USER            => $REMOTE_USER,
        REQUEST_URI     => $REQUEST_URI,
        PATH_TRANSLATED => $PATH_TRANSLATED,
        LANG            => $LANG,
        VBASE           => $self->{cgi}->escapeHTML($vbase),
        VHTDOCS         => $vbase . $VHTDOCS,
        RELEASE         => $RELEASE,
        q{.}            => scalar time(),
        %{$vars},
    };

    $content =~ s{\$\[([\w.]+)\]}{$vars->{$1} // "\$$1"}exmsg;
    $content =~ s{\${?([\w.]+)}?}{$vars->{$1} // "\$$1"}exmsg;
    $content =~
s{<!--IF${cond_rx}-->${anyng_rx}((<!--ELSE-->)${anyng_rx})?<!--ENDIF-->}{eval($1)? ( $2 // q{} ): ($5 // q{})}exmsg;
    $content =~
s{<!--IF(\#\d+)${cond_rx}-->${anyng_rx}((<!--ELSE\1-->)${anyng_rx})?<!--ENDIF\1-->}{eval($2)? ($3 // q{}) : ($6 // q{})}exmsg;
    return $content;
}

sub get_vbase {
    return $REQUEST_URI =~ /^($VIRTUAL_BASE)/xms
      ? $1
      : $REQUEST_URI;
}

sub is_unselectable {
    my ( $self, $fn ) = @_;
    my $unselregex =
      @UNSELECTABLE_FOLDERS
      ? '(' . join( q{|}, @UNSELECTABLE_FOLDERS ) . ')'
      : '___cannot match___';
    return $self->{backend}->basename($fn) eq q{..}
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
      if $self->{cgi}->param('search.name')
      || $self->{cgi}->param('search.types')
      || $self->{cgi}->param('search.size');
    return
         $self->{cgi}->cookie('filter.name')
      || $self->{cgi}->cookie('filter.types')
      || $self->{cgi}->cookie('filter.size') ? 1 : 0;
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
