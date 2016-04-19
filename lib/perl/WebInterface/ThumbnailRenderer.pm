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

package WebInterface::ThumbnailRenderer;

use strict;
use warnings;

our $VERSION = '2.0';

use English qw( -no_match_vars );
use CGI::Carp;

use HTTPHelper qw( get_mime_type get_etag print_header_and_content );
use FileUtils qw( get_file_limit );

use DefaultConfig
  qw( $ENABLE_THUMBNAIL_CACHE $THUMBNAIL_CACHEDIR $THUMBNAIL_WIDTH $ICON_WIDTH $CGI $BACKEND_INSTANCE );

sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;
    $self->{config}  = shift;
    $self->{backend} = $BACKEND_INSTANCE;
    $self->{cgi}     = $CGI;
    return $self;
}
sub free {
    my ($self) = @_;
    delete $self->{config};
    delete $self->{backend};
    delete $self->{cgi};
    return $self;
}
sub _create_empty_thumbnail {
    my ( $filename, $outputfilename ) = @_;
    require Graphics::Magick;
    my $image = Graphics::Magick->new( size => '1x1' );
    $image->Read('xc:white');
    #$image->Transparent(color=>'white');
    $image->Write($outputfilename);
    undef $image;
    return;
}

sub _create_thumbnail {
    my ( $self, $filename, $outputfilename ) = @_;
    require Graphics::Magick;

    if ( $self->{backend}->isEmpty($filename) ) {
        return _create_empty_thumbnail( $filename, $outputfilename );
    }

    my $image = Graphics::Magick->new();
    my $width = $THUMBNAIL_WIDTH // $ICON_WIDTH // 18;
    my $lfn   = $self->{backend}->getLocalFilename($filename);
    my $x;
    my ( $w, $h, $s, $f ) = $image->Ping($lfn);
    $w //= 0;
    $h //= 0;
    if ( $image->Read($lfn) ) {
        return _create_empty_thumbnail( $filename, $outputfilename );
    }
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
    undef $image;
    return;
}

sub print_thumbnail {
    my ( $self, $fn ) = @_;

    if ($ENABLE_THUMBNAIL_CACHE) {
        my $uniqname = $fn;
        $uniqname =~ s{/}{_}xmsg;
        my $cachefile = "$THUMBNAIL_CACHEDIR/$uniqname.thumb.gif";
        if ( !-e $THUMBNAIL_CACHEDIR ) {
            mkdir($THUMBNAIL_CACHEDIR)
              || carp("Cannot make $THUMBNAIL_CACHEDIR");
        }
        if ( !-e $cachefile
            || ( $self->{backend}->stat($fn) )[9] > ( stat $cachefile )[9] )
        {
            $self->_create_thumbnail( $fn, $cachefile );
        }
        print $self->{cgi}->header(
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
        print $self->{cgi}->header(
            -status => '200 OK',
            -type   => 'image/png',
            -ETag   => get_etag($fn)
        );
        binmode(STDOUT) || carp('Cannot set binmode for STDOUT');
        $self->_create_thumbnail( $fn, 'png:-' );
    }
    return 1;
}

sub print_media_rss {
    my ( $self, $fn, $ru ) = @_;
    my $renderer = $self->{config}{webinterface}->get_renderer();
    my $content =
qq@<?xml version="1.0" encoding="utf-8" standalone="yes"?><rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/" xmlns:atom="http://www.w3.org/2005/Atom"><channel><title>$ENV{SCRIPT_URI} media data</title><description>$ENV{SCRIPT_URI} media data</description><link>$ENV{SCRIPT_URI}</link>@;
    foreach my $file ( sort { $a cmp $b }
        @{ $self->{backend}->readDir( $fn, get_file_limit($fn), $renderer ) } )
    {
        my $mime = get_mime_type($file);
        if ( $renderer->has_thumb_support($mime) && $mime !~ /^image/xmsi ) {
            $mime = 'image/gif';
        }

        if (   $renderer->has_thumb_support($mime)
            && $self->{backend}->isReadable("$fn$file")
            && $self->{backend}->isFile("$fn$file")
            && !$self->{backend}->isEmpty("$fn$file") )
        {
            $content .=
qq@<item><title>$file</title><link>$ru$file</link><media:thumbnail type="image/gif" url="$ENV{SCRIPT_URI}$file?action=thumb"/><media:content type="$mime" url="$ENV{SCRIPT_URI}$file?action=image"/></item>@;
        }
    }
    $content .= q@</channel></rss>@;
    print_header_and_content( '200 OK', 'appplication/rss+xml', $content );
    return 1;
}

sub print_image {
    my ( $self, $fn ) = @_;
    if ( !$self->{backend}->isFile($fn) || $self->{backend}->isEmpty($fn) ) {
        print_header_and_content('404 Not Found');
        return;
    }
    $fn = $self->{backend}->getLocalFilename($fn);
    require Graphics::Magick;
    my $image = Graphics::Magick->new();
    my $x     = $image->Read($fn);
    carp "$x" if "$x";
    $image->Set( delay => 200 );
    binmode(STDOUT) || carp('Cannot set binmode for STDOUT');
    print $self->{cgi}->header(
        -status => '200 OK',
        -type   => 'image/gif',
        -ETag   => get_etag($fn)
    );
    $x = $image->Write('gif:-');
    carp "$x" if "$x";
    undef $image;
    return 1;
}

1;
