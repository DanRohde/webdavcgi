#!/usr/bin/perl
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

package WebInterface;

use strict;
use warnings;

our $VERSION = '2.0';

use WebInterface::Extension::Manager;

# for optimizing css/js:
use Fcntl qw (:flock);
use IO::Compress::Gzip;
use MIME::Base64;
use CGI::Carp;

use HTTPHelper
  qw( print_header_and_content get_parent_uri print_local_file_header get_mime_type );
use FileUtils qw( get_local_file_content_and_type stat2h );

use DefaultConfig qw(
  $PATH_TRANSLATED $REMOTE_USER $REQUEST_URI $VHTDOCS $INSTALL_BASE
  $ENABLE_THUMBNAIL $ENABLE_DAVMOUNT $ALLOW_POST_UPLOADS $ENABLE_CLIPBOARD
  $OPTIMIZERTMP $THUMBNAIL_CACHEDIR $RELEASE $CONFIGFILE
);

sub new {
    my ($this) = @_;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub init {
    my ( $self, $config ) = @_;

    $config->{webinterface} = $self;

    ${$self}{config}  = $config;
    ${$self}{db}      = $config->{db};
    ${$self}{cgi}     = $config->{cgi};
    ${$self}{backend} = $config->{backend};
    ${$self}{debug}   = $config->{debug};
    ${$self}{config}{extensions} =
      WebInterface::Extension::Manager->new($config);
    $self->optimize_css_and_js();

    return $self;
}

sub handle_thumbnail_get_request {
    my ( $self, $action ) = @_;
    if ( !$ENABLE_THUMBNAIL ) {
        return 0;
    }
    if (   $action eq 'mediarss'
        && ${$self}{backend}->isDir($PATH_TRANSLATED)
        && ${$self}{backend}->isReadable($PATH_TRANSLATED) )
    {
        $self->get_renderer()
          ->print_media_rss( $PATH_TRANSLATED, $REQUEST_URI );
        return 1;
    }
    if (   $action eq 'image'
        && ${$self}{backend}->isFile($PATH_TRANSLATED)
        && ${$self}{backend}->isReadable($PATH_TRANSLATED) )
    {
        $self->get_renderer()->print_image($PATH_TRANSLATED);
        return 1;
    }
    if (   $action eq 'thumb'
        && ${$self}{backend}->isReadable($PATH_TRANSLATED)
        && ${$self}{backend}->isFile($PATH_TRANSLATED) )
    {
        $self->get_renderer()->print_thumbnail($PATH_TRANSLATED);
        return 1;
    }
    return 0;
}

sub handle_get_request {
    my ($self) = @_;
    my $action = ${$self}{cgi}->param('action') // '_unknown_';

    my $ret_by_ext =
      ${$self}{config}{extensions}->handle( 'gethandler', ${$self}{config} );
    my $handled_by_ext = $ret_by_ext ? join( q{}, @{$ret_by_ext} ) : q{};

    if (   $handled_by_ext =~ /1/xms
        || $self->handle_thumbnail_get_request($action) )
    {
        return 1;
    }
    if (   $PATH_TRANSLATED =~ /\/webdav-ui(-[^.\/]+)?[.](js|css)\/?$/xms
        || $PATH_TRANSLATED =~ /\Q$VHTDOCS\E(.*)$/xms )
    {
        $self->get_renderer()->print_styles_vhtdocs_files($PATH_TRANSLATED);
        return 1;
    }
    if (   $ENABLE_DAVMOUNT
        && $action eq 'davmount'
        && ${$self}{backend}->exists($PATH_TRANSLATED) )
    {
        $self->get_renderer()->print_dav_mount($PATH_TRANSLATED);
        return 1;
    }

    if ( ${$self}{backend}->isDir($PATH_TRANSLATED) ) {
        $self->get_renderer()
          ->render_web_interface( $PATH_TRANSLATED, $REQUEST_URI );
        return 1;
    }
    return 0;
}

sub handle_head_request {
    my ($self) = @_;
    my $handled = 1;
    if ( ${$self}{backend}->isDir($PATH_TRANSLATED) ) {
        print_header_and_content( '200 OK', 'httpd/unix-directory' );
    }
    elsif ( $PATH_TRANSLATED =~ /\/webdav-ui[.](js|css)$/xms ) {
        print_local_file_header(
            -e ( $INSTALL_BASE . basename($PATH_TRANSLATED) )
            ? $INSTALL_BASE . basename($PATH_TRANSLATED)
            : "${INSTALL_BASE}lib/" . basename($PATH_TRANSLATED)
        );
    }
    else {
        $handled = 0;
    }
    return $handled;
}

sub handle_post_request {
    my ($self) = @_;
    my $handled = 1;

    my $ret_by_ext =
      ${$self}{config}{extensions}->handle( 'posthandler', ${$self}{config} );
    my $handled_by_ext = $ret_by_ext ? join( q{}, @{$ret_by_ext} ) : q{};

    if (   $handled_by_ext =~ /1/xms
        || $self->get_functions()->handle_file_actions() )
    {
        $handled = 1;
    }
    elsif ($ALLOW_POST_UPLOADS
        && ${$self}{backend}->isDir($PATH_TRANSLATED)
        && defined ${$self}{cgi}->param('filesubmit') )
    {
        $self->get_functions()->handle_post_upload();
    }
    elsif ( $ENABLE_CLIPBOARD && ${$self}{cgi}->param('action') ) {
        $self->get_functions()->handle_clipboard_action();
    }
    else {
        $handled = 0;
    }
    return $handled;
}

sub get_functions {
    my $self = shift;
    require WebInterface::Functions;
    return WebInterface::Functions->new( ${$self}{config} );
}

sub get_renderer {
    my $self = shift;
    require WebInterface::Renderer;
    return WebInterface::Renderer->new( ${$self}{config} );
}

sub optimizer_is_optimized {
    my ($self) = @_;
    return ${$self}{isoptimized};
}

sub optimizer_get_filepath {
    my ( $self, $ft ) = @_;
    my $tmp = $OPTIMIZERTMP || $THUMBNAIL_CACHEDIR || '/var/tmp';
    my $optimizerbasefn = "${CONFIGFILE}_${RELEASE}_${REMOTE_USER}";
    $optimizerbasefn =~ s/[\/.]/_/xmsg;
    my $optimizerbase = $tmp . q{/} . $optimizerbasefn;
    return "${optimizerbase}.$ft";
}

sub optimize_css_and_js {
    my ($self) = @_;
    return if ${$self}{isoptimized} || ${$self}{notoptimized};
    ${$self}{isoptimized} = 0;

    my $csstargetfile = $self->optimizer_get_filepath('css') . '.gz';
    my $jstargetfile  = $self->optimizer_get_filepath('js') . '.gz';
    if (   ( -e $csstargetfile && !-w $csstargetfile )
        || ( -e $jstargetfile && !-w $jstargetfile ) )
    {
        ${$self}{notoptimized} = 1;
        carp(
"Cannot write optimized CSS and JavaScript to $csstargetfile and/or $jstargetfile"
        );
        return;
    }
    if (   -r $jstargetfile
        && -r $csstargetfile
        && stat2h( \stat $jstargetfile )->{ctime} >
        stat2h( \stat $CONFIGFILE )->{ctime} )
    {
        ${$self}{isoptimized} = 1;
        return;
    }

    ## collect CSS:
    my $tags = join "\n",
      @{ ${$self}{config}{extensions}->handle('css') || [] };
    my $content =
      $self->optimizer_extract_content_from_tags_and_attributes( $tags, 'css' );
    if ($content) {
        $self->optimizer_write_content2zip( $csstargetfile, \$content );
    }

    ## collect JS:
    $tags = join "\n",
      @{ ${$self}{config}{extensions}->handle('javascript') || [] };
    $content =
      $self->optimizer_extract_content_from_tags_and_attributes( $tags, 'js' );
    if ($content) {
        $self->optimizer_write_content2zip( $jstargetfile, \$content );
    }

    return ${$self}{isoptimized} = 1;
}

sub optimizer_write_content2zip {
    my ( $self, $file, $contentref ) = @_;
    if ( open my $fh, '>', $file ) {
        flock $fh, LOCK_EX || carp("Cannot get exclusive lock for $file.");
        my $z = IO::Compress::Gzip->new($fh);
        $z->print( ${$contentref} );
        $z->close();
        flock( $fh, LOCK_UN ) || carp("Cannot unlock $file.");
        close($fh) || carp("Cannot close filehandle for $file.");
        return 1;
    }
    return 0;
}

sub optimizer_encode_image {
    my ( $self, $basepath, $url ) = @_;
    return "url($url)" if $url =~ /^data:image/xms;
    my $ifn  = "$basepath/$url";
    my $mime = get_mime_type($ifn);
    if ( open my $ih, '<', $ifn ) {
        $self->{debug}->("encode image $ifn");
        my $buffer;
        binmode($ih) || carp("Cannot set binmode for $ifn.");
        read( $ih, $buffer, stat2h( \stat $ih )->{size} )
          || carp("Cannot read $ifn.");
        close($ih) || carp("Cannot close filehandle for $ifn.");
        return
            'url(data:'
          . $mime
          . ';base64,'
          . encode_base64( $buffer, q{} ) . ')';
    }
    else {
        carp("Cannot read $ifn.");
    }
    return;
}

sub optimizer_collect {
    my ( $self, $contentref, $filename, $data, $type ) = @_;
    if ($filename) {
        my $full = $filename;
        $full =~
s{^.*${VHTDOCS}_EXTENSION[(](.*?)[)]_(.*)}{${INSTALL_BASE}lib/perl/WebInterface/Extension/$1$2}xmsg;
        $self->{debug}->("collect $type from $full");
        my $fc =
          ( get_local_file_content_and_type($full) )[1];
        if ( $type eq 'css' ) {
            my $basepath = get_parent_uri($full);
            $fc =~
s/url[(](.*?)[)]/$self->optimizer_encode_image($basepath, $1)/iegxms;
        }
        ${$contentref} .= $fc;
        $self->{debug}->("optimizer_collect: $full collected.");
    }
    return ${$contentref} .= $data ? $data : q{};
}

sub optimizer_extract_content_from_tags_and_attributes {
    my ( $self, $data, $type ) = @_;
    my $content = q{};
    if ( $type eq 'css' ) {
        $data =~
s{<style[^>]*>(.*?)</style>}{$self->optimizer_collect(\$content, undef, $1, $type)}xmiegs;
        $data =~
s{<link[ ].*?href="(.*?)"}{$self->optimizer_collect(\$content, $1, undef, $type)}xmiegs;
    }
    else {
        $data =~
s{<script[ ].*?src="([^>"]+)".*?>(.*?)</script>}{$self->optimizer_collect(\$content, $1, $2, $type)}xmiegs;
    }

    return $content;
}

1;
