#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2016 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

use CGI;
use CGI::Carp;
use POSIX qw( strftime ceil locale_h );
use List::MoreUtils qw( any );
use English qw(-no_match_vars);

use DefaultConfig qw(
  $CHARSET $ENABLE_THUMBNAIL $ENABLE_THUMBNAIL_PDFPS $INSTALL_BASE $LANG $ORDER
  $PATH_TRANSLATED $POST_MAX_SIZE $FILETYPES $CGI $BACKEND_INSTANCE
  $RELEASE $REMOTE_USER $REQUEST_URI $SHOWDOTFILES $SHOWDOTFOLDERS $VHTDOCS $VIEW
  $VIRTUAL_BASE %ICONS %TRANSLATION @ALLOWED_TABLE_COLUMNS @SUPPORTED_VIEWS
  @UNSELECTABLE_FOLDERS @VISIBLE_TABLE_COLUMNS %SUPPORTED_LANGUAGES %AUTOREFRESH
  @ALLOWED_TABLE_COLUMNS $DB $CM $CGI $BACKEND_INSTANCE $CONFIG %SESSION 
  @ALL_EXTENSIONS $DOCUMENT_ROOT);
use HTTPHelper qw( get_mime_type print_compressed_header_and_content );
use WebInterface::Translations qw( read_all_tl  );
use FileUtils;

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
    my ($this) = @_;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    $self->{config} = $CONFIG;
    return $self->init();
}
sub free {
    my ($self) = @_;
    foreach my $k (qw(config db cgi backend cache BYTEUNITS BYTEUNITORDER STATIDX WEB_ID)) {
        delete $self->{$k};
    }
    return $self;
}
sub init {
    my ($self) = @_;
    $self->{config}  = $CONFIG;
    $self->{db}      = $DB;
    $self->{cgi}     = $CGI;
    $self->{backend} = $BACKEND_INSTANCE;
    $self->{cache}   = $CM;
    return $self->initialize();
}

sub initialize {
    my ($self) = @_;

    $self->{BYTEUNITS}     = \%BYTEUNITS;
    $self->{BYTEUNITORDER} = \@BYTEUNITORDER;
    $self->{STATIDX}       = \%STATIDX;
    $self->{WEB_ID}        = 0;

    $LANG =
         $self->{cgi}->param('lang')
      || $self->{cgi}->cookie('lang')
      || $LANG
      || 'en';
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
    return $self;
}

sub tl {
    my ( $self, $key, $default, @args ) = @_;
    if ( !defined $key ) { return $default; }
    if ( defined $default && exists $CACHE{tl}{$key}{$default} ) {
        return $CACHE{tl}{$key}{$default};
    }
    read_all_tl( $self->{config}{extensions}, $LANG );
    my $val =
      $TRANSLATION{$LANG}{$key} // $TRANSLATION{default}{$key} // $default
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
    my $path = $self->get_vbase();
    my @cookies = (
        $self->{cgi}->cookie(
            -name    => 'lang',
            -value   => $LANG,
            -expires => '+10y',
            -path    => $path
        ),
        $self->{cgi}->cookie(
            -name    => 'order',
            -value   => $ORDER,
            -expires => '+10y',
            -path    => $path
        ),
        $self->{cgi}->cookie(
            -name    => 'view',
            -value   => $VIEW,
            -expires => '+10y',
            -path    => $path
        ),
    );

    if ( !$SHOWDOTFILES ) {
        push @cookies,
          $self->{cgi}->cookie(
            -name  => 'settings.show.dotfiles',
            -value => $self->{cgi}->cookie('settings.show.dotfiles') || 'no',
            -path  => $path
          );
        push @cookies, $self->{cgi}
          ->cookie( -name => 'settings.show.dotfiles.keep', -value => 1, -path => $path );
    }
    if ( !$SHOWDOTFOLDERS ) {
        push @cookies,
          $self->{cgi}->cookie(
            -name  => 'settings.show.dotfolders',
            -value => $self->{cgi}->cookie('settings.show.dotfolders') || 'no',
            -path  => $path
          );
        push @cookies, $self->{cgi}
          ->cookie( -name => 'settings.show.dotfolders.keep', -value => 1, -path => $path );
    }

    return \@cookies;
}
sub _get_std_template_vars {
    my ($self, $ru, $vars) = @_;
    my $vbase = $self->get_vbase();
    my @lt = localtime;
    $vars //= {};
    return {
        uri             => $ru // $REQUEST_URI,
        baseuri         => $self->{cgi}->escapeHTML($vbase),
        basedn          => $self->{backend} ? $self->{backend}->getDisplayName($DOCUMENT_ROOT) : $DOCUMENT_ROOT,
        maxuploadsize   => $POST_MAX_SIZE,
        maxuploadsizehr => ( $self->render_byte_val( $POST_MAX_SIZE, 2, 2 ) )[0],
        view            => $VIEW,
        viewname        => $self->tl("${VIEW}view"),
        USER            => $REMOTE_USER,
        REQUEST_URI     => $REQUEST_URI,
        PATH_TRANSLATED => $PATH_TRANSLATED,
        LANG            => $LANG,
        TRANS_LANG      => $SUPPORTED_LANGUAGES{$LANG} // $SUPPORTED_LANGUAGES{en},
        VBASE           => $self->{cgi}->escapeHTML($vbase),
        VHTDOCS         => $vbase . $VHTDOCS,
        RELEASE         => $RELEASE,
        TOKENNAME       => $ENV{SESSION_TOKENNAME} // 't',
        TOKEN           => $ENV{SESSION_TOKEN} // time,
        q{.}            => scalar time,
        TIME            => strftime($self->tl('vartimeformat'), @lt),
        NOW             => strftime($self->tl('varnowformat'), @lt),
        %{$vars},
    };
}
sub _replace_std_template_vars {
    my ($self, $tref, $ru, $v) = @_;
    my $vars = $self->_get_std_template_vars($ru, $v);

    ${$tref} =~ s{\$\[([\w.]+)\]}{ $vars->{$1} // "\$$1"}exmsg;
    ${$tref} =~ s{\$\{?([\w.]+)\}?}{ $vars->{$1} // "\$$1"}exmsg;

    ${$tref} =~ s/\$\{?ENV\{([^}]+?)}}?/$ENV{$1}/exmsg;
    my $clockfmt = $self->tl('vartimeformat');
    ${$tref} =~ s{\$\{?CLOCK\}?}{<span id="clock"></span><script>startClock('clock','$clockfmt');</script>}xmsg;
    ${$tref} =~ s/\$\{?TL\{([^}]+)}}?/$self->tl($1)/exmsg;

    return $tref;
}
sub replace_vars {
    my ( $self, $t, $v ) = @_;
    return ${ $self->_replace_std_template_vars(\$t, $REQUEST_URI, $v) };
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
            ( ($self->{backend}->stat($fp_a) )[$idx] // 0 )
              <=> (( $self->{backend}->stat($fp_b) )[$idx] // 0 )
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
    } elsif (!defined $m) {
        $m = ( $self->{backend}->stat($fn))[ $STATIDX{mode} ];
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
    my ( $h ) = @_; 
    my $aa = $a;
    my $bb = $b;
    if ( ref $h->{$a} eq 'HASH') {
        $aa = $h->{$a}->{_order} // $a;
        $bb = $h->{$b}->{_order} // $b;
    }
    return ( $aa =~ /^[\d.]+$/xms && $bb =~ /^[\d.]+$/xms )
      ? $aa <=> $bb
      : $aa cmp $bb;
}

sub _get_varref {
    my ( $self, $str ) = @_;
    $str =~ s/^[@%\$](?:main::)?//xms;
    my $ref = $DefaultConfig::{$str} // $__PACKAGE__::{$str};

    if ( !defined $ref ) {
        if ( defined $self->{$str} ) {
            return $self->{$str};
        }
        if ($str=~/^(.*){(.*?)}/xms) {
            $ref = $DefaultConfig::{$1}{$2};
            return $ref;
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
        foreach my $key ( sort { _flex_sorter($hashref) } keys %{$hashref} ) {
            next if defined $filter && $hashref->{$key} =~ /$filter/xmsg;
            my $t = $tmpl;
            $t =~ s/\$k/$key/xmsg;
            $t =~ s/\$\{k\}/$key/xmsg;
            $t =~ s/\$v/$hashref->{$key}/xmsg;
            $t =~ s/\$\{v\}/$hashref->{$key}/xmsg;
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
            $t =~ s/\$\{[kv]\}/$val/xmsg;
            $content .= $t;
        }
    }
    return $content;
}

sub exec_template_function {
    my ( $self, $fn, $ru, $func, $param ) = @_;
    if ( $func eq 'tl' ) {
        return $self->tl($param);
    }
    if ( $func eq 'config' ) {
        return $param ? ${ $self->_get_varref($param) // \q{} } : q{};
    }
    if ( $func eq 'inchelp' ) {
        return $self->handle_inc_help($param);
    }
    if ( $func eq 'env' ) {
        return $ENV{$param} // q{};
    }
    if ( $func eq 'cgiparam' ) {
        return $self->{cgi}->escapeHTML($self->{cgi}->param($param) // q{});
    }
    if ( $func eq 'help' ) {
        return $self->handle_help($param);
    }
    return q{};
}

sub render_template {
    my ( $self, $fn, $ru, $content, $vars ) = @_;
    $vars //= {};

    my $cgi      = $self->{cgi};    ## allowes easier access from templates
    my $anyng_rx = qr{(.*?)}xms;
    my $cond_rx = qr{[(]${anyng_rx}[)]}xms;

    # replace eval:
    $content =~ s/\$eval(.)${anyng_rx}\1/eval($2)/xmegs;

    # replace each:
    $content =~ s/\$each(.)${anyng_rx}\1${anyng_rx}\1((.)${anyng_rx}\5\1)?/$self->render_each(fn=>$fn,ru=>$ru,variable=>$2,tmplfile=>$3,filter=>$6)/exmsg;

    # replace functions:
    while ( $content =~ s/\$(\w+)[(]([^)]*)[)]/$self->exec_template_function($fn,$ru,$1,$2)/xmesg) { }

    # replace standard variables:
    $self->_replace_std_template_vars(\$content, $ru, $vars);

    $content =~ s{<!--IF${cond_rx}-->${anyng_rx}((<!--ELSE-->)${anyng_rx})?<!--ENDIF-->}{eval($1)? ( $2 // q{} ): ($5 // q{})}exmsg;
    $content =~ s{<!--IF(\#\d+)${cond_rx}-->${anyng_rx}((<!--ELSE\1-->)${anyng_rx})?<!--ENDIF\1-->}{eval($2)? ($3 // q{}) : ($6 // q{})}exmsg;

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

# f...... workaround for older CGI versions:
sub get_cgi_multi_param {
    my ( $self, $param ) = @_;
    if ( !wantarray ) { return scalar $self->{cgi}->param($param); }
    my @vals;
    if ( defined $CGI::{multi_param} ) {
        @vals = $self->{cgi}->multi_param($param);
    }
    else {
        @vals = $self->{cgi}->param($param);
    }
    return @vals;
}

sub get_category_class {
    my ( $self, $suffix, $class, $default ) = @_;
    $suffix=~s/\s/+/xmsg;
    $class //= q{};
    my $ft = $CACHE{categorytypes}{$REMOTE_USER} //= $self->replace_vars($FILETYPES);
    return $CACHE{category}{$REMOTE_USER}{$suffix}{$class} //=  $ft =~ /^($class\w+)[^\n]+\b\Q$suffix\E\b/xmsi ? 'category-' . $1  : $default // q{};
}
sub get_lang_filename {
    my ($self, $basepath, $basename, $suffix) = @_;
    my $filename = "${basename}_${LANG}.${suffix}";
    if (!-e "${basepath}${filename}") { $filename = "${basename}.${suffix}"; }
    if (!-e "${basepath}${filename}") { $filename = "${LANG}/${basename}.${suffix}"}
    return -e "${basepath}${filename}" ? $filename : undef;
}
sub get_help_filepath {
    return "${INSTALL_BASE}htdocs/views/${VIEW}/help/";
}
sub get_help_baseuri {
    my ($self) = @_;
    return $self->get_vbase()."${VHTDOCS}views/${VIEW}/help/";
}
sub handle_help {
    my ($self, $param) = @_;
    my $filepath = $self->get_help_filepath();
    my ($helpbase, $anchor) = $param=~/^(.*)(?:\#(.*))?$/xms ? ($1, $2 // $1) : ($param, $param);
    my $helpfile = $self->get_lang_filename($filepath, $helpbase, 'html') // $self->get_lang_filename($filepath, 'index','html');
    return $self->get_help_baseuri().${helpfile}.q{#}.${anchor};
}
sub handle_inc_help {
    my ($self, $param) = @_;
    my $filepath = $self->get_help_filepath();
    my ($helpbase, $anchor) = $param=~/^(.*)(?:\#(.*))?$/xms ? ($1, $2 // $1) : ($param, $param);
    my $helpfile = $self->get_lang_filename($filepath, $helpbase, 'html') // $self->get_lang_filename($filepath, 'index','html');
    my $content = FileUtils::get_local_file_content("${filepath}/$helpfile");
    return $self->{cgi}->escape($content=~m{<body>(.*)</body>}xmsi ? $1 : $content);
}
sub render_login {
    my ($self) = @_;
    return print_compressed_header_and_content( '200 OK', 'text/html', $self->render_template($PATH_TRANSLATED, $REQUEST_URI, $self->read_template('login')),
        {-Cache_Control=> 'no-cache, no-store', -X_Login_Required => '?logon=session' });
}
sub strip_slash {
    my ($self, $s) = @_;
    return $s=~m{^(.*)/$}xms ? $1 : $s;
}
1;
