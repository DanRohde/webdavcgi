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

package WebInterface::Renderer;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( WebInterface::Common );

use Module::Load;
use Graphics::Magick;
use POSIX qw(strftime);

use CGI::Carp;
use English qw( -no_match_vars );

use DefaultConfig
  qw( $INSTALL_BASE $VHTDOCS $VIEW @SUPPORTED_VIEWS $READBUFSIZE $THUMBNAIL_WIDTH $ICON_WIDTH
  $ENABLE_THUMBNAIL_CACHE $THUMBNAIL_CACHEDIR );
use HTTPHelper
  qw( get_etag print_header_and_content print_local_file_header fix_mod_perl_response get_mime_type);
use FileUtils qw( get_file_limit );
use vars qw( %_RENDERER );

sub _get_renderer {
    my ($self) = @_;
    my $view = "WebInterface::View::\u${VIEW}::Renderer";
    $view =~ s/[.\/]+//xmsg;
    if ( !-f "${INSTALL_BASE}lib/perl/WebInterface/View/\u${VIEW}/Renderer.pm" )
    {
        $view = "WebInterface::View::\u$SUPPORTED_VIEWS[0]::Renderer";
    }
    if ( exists $_RENDERER{$self}{$view} ) {
        return $_RENDERER{$self}{$view};
    }
    load $view;
    $_RENDERER{$self}{$view} = $view->new( ${$self}{config} );
    return $_RENDERER{$self}{$view};
}

sub render_web_interface {
    my ( $self, $fn, $ru ) = @_;
    my $_RENDERER = $self->_get_renderer();
    return $_RENDERER->render( $fn, $ru );
}

sub print_styles_vhtdocs_files {
    my ( $self, $fn ) = @_;
    my $file =
        $fn =~ /\Q$VHTDOCS\E(.*)/xms
      ? $INSTALL_BASE . 'htdocs/' . $1
      : $INSTALL_BASE . 'lib/' . ${$self}{backend}->basename($fn);
    if ( $fn =~ /\Q$VHTDOCS\E_EXTENSION[(]([^)]+)[)]_(.*)/xms ) {
        $file = $INSTALL_BASE . 'lib/perl/WebInterface/Extension/' . $1 . $2;
    }
    elsif ( $fn =~ /\Q$VHTDOCS\E_OPTIMIZED[(](js|css)[)]_/xms ) {
        $file = $self->{config}->{webinterface}->optimizer_get_filepath($1);
    }
    $file =~ s{/[.][.]/}{}xmsg;
    my $compression = !-e $file && -e "$file.gz";
    my $nfile = $file;
    if ($compression) { $file = "$nfile.gz"; }
    my $header = {
        -Expires => strftime( '%a, %d %b %Y %T GMT', gmtime( time + 604_800 ) ),
        -Vary    => 'Accept-Encoding'
    };
    if ($compression) {
        ${$header}{-Content_Encoding} = 'gzip';
        ${$header}{-Content_Length}   = ( stat $file )[7];
    }
    if ( open my $f, '<', $file ) {
        my $headerref = print_local_file_header( $nfile, $header );
        binmode(STDOUT) || carp("Cannot set binmode for $file");
        while ( read $f, my $buffer, $READBUFSIZE ) {
            print $buffer;
        }
        close $f || carp("Cannot close $file.");
        fix_mod_perl_response($headerref);
    }
    else {
        print_header_and_content('404 Not Found');
    }
    return;
}

sub print_media_rss {
    my ( $self, $fn, $ru ) = @_;
    my $_RENDERER = $self->_get_renderer();
    my $content =
qq@<?xml version="1.0" encoding="utf-8" standalone="yes"?><rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/" xmlns:atom="http://www.w3.org/2005/Atom"><channel><title>$ENV{SCRIPT_URI} media data</title><description>$ENV{SCRIPT_URI} media data</description><link>$ENV{SCRIPT_URI}</link>@;
    foreach my $file ( sort { $_RENDERER->cmp_files }
        @{ ${$self}{backend}->readDir( $fn, get_file_limit($fn), $_RENDERER ) }
      )
    {
        my $mime = get_mime_type($file);
        if ( $_RENDERER->has_thumb_support($mime) && $mime !~ /^image/xmsi ) {
            $mime = 'image/gif';
        }

        if (   $_RENDERER->has_thumb_support($mime)
            && ${$self}{backend}->isReadable("$fn$file")
            && ${$self}{backend}->isFile("$fn$file")
            && !${$self}{backend}->isEmpty("$fn$file") )
        {
            $content .=
qq@<item><title>$file</title><link>$ru$file</link><media:thumbnail type="image/gif" url="$ENV{SCRIPT_URI}$file?action=thumb"/><media:content type="$mime" url="$ENV{SCRIPT_URI}$file?action=image"/></item>@;
        }
    }
    $content .= q@</channel></rss>@;
    return print_header_and_content( '200 OK', 'appplication/rss+xml',
        $content );
}

sub _create_thumbnail {
    my ( $self, $filename, $outputfilename ) = @_;
    my $image = Graphics::Magick->new();
    my $width = $THUMBNAIL_WIDTH // $ICON_WIDTH // 18;
    my $lfn   = ${$self}{backend}->getLocalFilename($filename);
    my $x;
    my ( $w, $h, $s, $f ) = $image->Ping($lfn);
    $w //= 0;
    $h //= 0;
    $x = $image->Read($lfn) && carp($x);
    $image->Set( delay => 200 );

    if ( $h > $width && $w < $width ) {
        $image->Crop( height => $h / ${width} );
    }
    if ( $w > $width ) {
        $image->Resize( geometry => $width, filter => 'Gaussian' );
    }
    $image->Frame(
        width  => 2,
        height => 2,
        outer  => 0,
        inner  => 2,
        fill   => 'black'
    );
    $x = $image->Write($outputfilename) && carp($x);
    return;
}

sub print_thumbnail {
    my ( $self, $fn ) = @_;

    if ($ENABLE_THUMBNAIL_CACHE) {
        my $uniqname = $fn;
        $uniqname =~ s/\//_/xmsg;
        my $cachefile = "$THUMBNAIL_CACHEDIR/$uniqname.thumb.gif";
        if ( !-e $THUMBNAIL_CACHEDIR ) {
            mkdir($THUMBNAIL_CACHEDIR)
              || carp("Cannot make $THUMBNAIL_CACHEDIR");
        }
        if ( !-e $cachefile
            || ( ${$self}{backend}->stat($fn) )[9] > ( stat $cachefile )[9] )
        {
            $self->_create_thumbnail( $fn, $cachefile );
        }
        print ${$self}{cgi}->header(
            -status         => '200 OK',
            -type           => get_mime_type($cachefile),
            -ETag           => get_etag($cachefile),
            -Content_length => ( stat $cachefile )[7]
        );
        if ( open my $cf, '<', $cachefile ) {
            binmode($cf) || carp("Cannot set binmode for $cachefile");
            binmode(STDOUT) || carp('Cannot set binmode for STDOUT');
            local $RS = undef;
            print scalar <$cf>;
            close($cf) || carp("Cannot close $cachefile.");
        }
    }
    else {
        print ${$self}{cgi}->header(
            -status => '200 OK',
            -type   => 'image/png',
            -ETag   => get_etag($fn)
        );
        binmode(STDOUT) || carp('Cannot set binmode for STDOUT');
        $self->_create_thumbnail( $fn, 'png:-' );
    }
    return;
}

sub print_image {
    my ( $self, $fn ) = @_;
    if ( !${$self}{backend}->isFile($fn) || ${$self}{backend}->isEmpty($fn) ) {
        print_header_and_content('404 Not Found');
        return;
    }
    $fn = ${$self}{backend}->getLocalFilename($fn);
    my $image = Graphics::Magick->new;
    my $x     = $image->Read($fn);
    carp "$x" if "$x";
    $image->Set( delay => 200 );
    binmode(STDOUT) || carp('Cannot set binmode for STDOUT');
    print ${$self}{cgi}->header(
        -status => '200 OK',
        -type   => 'image/gif',
        -ETag   => get_etag($fn)
    );
    $x = $image->Write('gif:-');
    carp "$x" if "$x";
    return;
}

sub print_dav_mount {
    my ( $self, $fn ) = @_;
    my $su = $ENV{REDIRECT_SCRIPT_URI} || $ENV{SCRIPT_URI};
    my $bn = ${$self}{backend}->basename($fn);
    $su =~ s/\Q$bn\E\/?//xms;
    $bn .= ${$self}{backend}->isDir($fn) && $bn !~ /\/$/xms ? q{/} : q{};
    return print_header_and_content(
        '200 OK',
        'application/davmount+xml',
qq@<dm:mount xmlns:dm="http://purl.org/NET/webdav/mount"><dm:url>$su</dm:url><dm:open>$bn</dm:open></dm:mount>@
    );
}
1;
