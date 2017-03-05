#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2016 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
package WebInterface::Translations;

use strict;
use warnings;
our $VERSION = '2.0';

use base qw( Exporter );
our @EXPORT_OK = qw( read_all_tl );

use CGI::Carp;
use Fcntl qw(:flock);
use English qw( -no_match_vars );

use DefaultConfig
  qw( $INSTALL_BASE %TRANSLATION $OPTIMIZERTMP $CONFIGFILE $RELEASE $REMOTE_USER );

use vars qw( %_FILESREAD %CACHE );

sub _read_tl_file {
    my ( $fn, $dataref ) = @_;
    if ( open my $fh, '<', $fn ) {
        local $RS = undef;
        my $content = <$fh>;
        close($fh) || carp("Cannot close $fn.");
        foreach ( split /\r?\n/xms, $content ) {
            chomp;
            if ( /^\#/xms || /^\s*$/xms ) { next; }
            if (/^(\S+)\s+"(.*)"\s*$/xms) {
                $dataref->{$1} = $2;
            }
        }
    }
    else { carp("Cannot read $fn!"); }
    return;
}

sub _replace_syms {
    my ($str) = @_;
    $str =~ s{[/.]}{_}xmsg;
    return $str;
}

sub _get_translation_tmpfilename {
    my ($lang) = @_;
    my $tmpbasefn = sprintf '%s-%s-%s-%s-%s', $CONFIGFILE, $RELEASE, $REMOTE_USER, $ENV{SESSION_DOMAIN} // q{0}, $lang;
    return "$OPTIMIZERTMP/". _replace_syms($tmpbasefn) . '.msg';
}

sub _load_translation {
    my ($lang) = @_;
    if ( $lang ne 'default' && !_load_translation('default') ) { return 0; }
    my $fn = $CACHE{$lang}{$REMOTE_USER}{$ENV{SESSION_DOMAIN}//q{0}} //= _get_translation_tmpfilename($lang);
    if ( $_FILESREAD{$fn} || !-e $fn ) { return $_FILESREAD{$fn} || -e $fn; }
    _read_tl_file( $fn, $TRANSLATION{$lang} //= {} );
    $_FILESREAD{$fn} = 1;
    return 1;
}

sub _save_translation {
    my ($lang) = @_;
    if ( $lang ne 'default' && !-e _get_translation_tmpfilename('default') ) {
        _save_translation('default');
    }
    my $fn      = _get_translation_tmpfilename($lang);
    my $content = q{};
    foreach my $k ( keys %{ $TRANSLATION{$lang} } ) {
        $content .= qq{$k "$TRANSLATION{$lang}{$k}"\n};
    }
    if ( open my $fh, '>', $fn ) {
        if ( flock $fh, LOCK_EX ) {
            print( {$fh} $content ) || carp("Cannot write $fn.");
            flock $fh, LOCK_UN;
        }
        close($fh) || carp("Cannot close $fn.");
    }
    else {
        carp("Cannot open $fn.");
    }

    return;
}

sub _handle_default_and_lang {
    my ( $lang, $fndefault, $fn ) = @_;
    if ( $_FILESREAD{$fn} ) { return; }
    if ( $lang eq 'default' || !$_FILESREAD{$fndefault} ) {
        if ( -e $fndefault ) {
            _read_tl_file( $fndefault, $TRANSLATION{default} //= {} );
        }
        $_FILESREAD{$fndefault} = 1;
        if ( $lang eq 'default' ) { return; }
    }
    if ( -e $fn ) {
        _read_tl_file( $fn, $TRANSLATION{$lang} //= {} );
    }
    $_FILESREAD{$fn} = 1;
    return;
}

sub _read_tl {
    my ($lang)    = @_;
    $lang //= 'default';
    my $fn        = "${INSTALL_BASE}locale/webdav-ui_${lang}.msg";
    my $fndefault = "${INSTALL_BASE}locale/webdav-ui_default.msg";
    _handle_default_and_lang( $lang, $fndefault, $fn );
    return;
}

sub _read_extensions_tl {
    my ( $extensions, $lang ) = @_;
    if ( _load_translation($lang) ) { return; }
    _read_tl($lang);
    if (!$extensions) { return; }
    my $locales = $extensions->handle('locales') || [];
    foreach my $lfn ( @{$locales} ) {
        my $fn        = $lfn . '_' . $lang . '.msg';
        my $fndefault = $lfn . '_default.msg';
        _handle_default_and_lang( $lang, $fndefault, $fn );
    }
    _save_translation($lang);
    return;
}

sub read_all_tl {
    my ( $extensions, $lang ) = @_;
    $REMOTE_USER //= 'unknown';
    _read_extensions_tl( $extensions, $lang );
    return;
}

1;
