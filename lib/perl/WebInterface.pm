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

# for optimizing css/js:
use Fcntl qw (:flock);
#use IO::Compress::Gzip;
#use MIME::Base64;
use CGI::Carp;
use POSIX qw(strftime);
use Module::Load;

use HTTPHelper
  qw( print_header_and_content get_parent_uri print_local_file_header get_mime_type fix_mod_perl_response );
use FileUtils qw( get_local_file_content_and_type );
use DefaultConfig qw(
  $PATH_TRANSLATED $REMOTE_USER $REQUEST_URI $VHTDOCS $INSTALL_BASE
  $ENABLE_THUMBNAIL $ENABLE_DAVMOUNT $ALLOW_POST_UPLOADS $ENABLE_CLIPBOARD
  $OPTIMIZERTMP $THUMBNAIL_CACHEDIR $RELEASE $CONFIGFILE $READBUFSIZE
  $VIEW @SUPPORTED_VIEWS  $DB $CGI $BACKEND_INSTANCE $D $L
);

sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;
    return $self;
}
sub free {
    my ($self) = @_;
    foreach my $c ( qw(functions view thumbnailrenderer extensions) ) {
        if (!$self->{config}->{$c}) { next; }
        $self->{config}->{$c}->free();
        delete $self->{config}->{$c};
    }
    delete $self->{config}->{webinterface};
    foreach my $k ( qw(webinterface config db cgi backend debug logger isoptimized notoptimized) ) {
        delete $self->{$k};
    }
    return $self;
}

sub init {
    my ( $self, $config ) = @_;

    $config->{webinterface} = $self;

    $self->{config}  = $config;
    $self->{db}      = $DB;
    $self->{cgi}     = $CGI;
    $self->{backend} = $BACKEND_INSTANCE;
    $self->{debug}   = $D;
    $self->{logger}  = $L;

    return $self;
}

sub handle_thumbnail_get_request {
    my ( $self, $action ) = @_;
    if ( !$ENABLE_THUMBNAIL ) {
        return 0;
    }
    if (   $action eq 'thumb'
        && $self->{backend}->isReadable($PATH_TRANSLATED)
        && $self->{backend}->isFile($PATH_TRANSLATED) )
    {
        return $self->get_thumbnail_renderer()
          ->print_thumbnail($PATH_TRANSLATED);
    }
    if (   $action eq 'mediarss'
        && $self->{backend}->isDir($PATH_TRANSLATED)
        && $self->{backend}->isReadable($PATH_TRANSLATED) )
    {
        return $self->get_thumbnail_renderer()
          ->print_media_rss( $PATH_TRANSLATED, $REQUEST_URI );
    }
    if (   $action eq 'image'
        && $self->{backend}->isFile($PATH_TRANSLATED)
        && $self->{backend}->isReadable($PATH_TRANSLATED) )
    {
        return $self->get_thumbnail_renderer()->print_image($PATH_TRANSLATED);
    }
    return 0;
}

sub handle_get_request {
    my ($self) = @_;
    my $action = $self->{cgi}->param('action') // '_unknown_';
    if (   $PATH_TRANSLATED =~ m{\/webdav-ui(?:-[^./]+)?[.](?:js|css)/?$}xms
        || $PATH_TRANSLATED =~ /\Q$VHTDOCS\E(.*)$/xms )
    {
        $self->optimize_css_and_js();
        $self->print_styles_vhtdocs_files($PATH_TRANSLATED);
        return 1;
    }
    if ( $self->handle_thumbnail_get_request($action) ) {
        return 1;
    }
    if (   $ENABLE_DAVMOUNT
        && $action eq 'davmount'
        && $self->{backend}->exists($PATH_TRANSLATED) )
    {
        return $self->_print_dav_mount($PATH_TRANSLATED);
    }
    my $ret_by_ext =
      $self->get_extension_manager()->handle( 'gethandler', $self->{config} );
    my $handled_by_ext = $ret_by_ext ? join( q{}, @{$ret_by_ext} ) : q{};

    if ( $handled_by_ext =~ /1/xms ) {
        return 1;
    }

    if ( $self->{backend}->isDir($PATH_TRANSLATED) ) {
        $self->optimize_css_and_js();
        $self->render_web_interface();
        return 1;
    }
    return 0;
}

sub handle_head_request {
    my ($self) = @_;
    if ( $self->{backend}->isDir($PATH_TRANSLATED) ) {
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
        return 0;
    }
    return 1;
}

sub handle_post_request {
    my ($self) = @_;
    my $ret_by_ext =
      $self->get_extension_manager()->handle( 'posthandler', $self->{config} );
    my $handled_by_ext = $ret_by_ext ? join( q{}, @{$ret_by_ext} ) : q{};

    if (   $handled_by_ext =~ /1/xms
        || $self->get_functions()->handle_file_actions() )
    {
        return 1;
    }
    if (   $ALLOW_POST_UPLOADS
        && $self->{backend}->isDir($PATH_TRANSLATED)
        && defined $self->{cgi}->param('filesubmit') )
    {
        return $self->get_functions()->handle_post_upload();
    }
    elsif ( $ENABLE_CLIPBOARD && $self->{cgi}->param('action') && $self->{cgi}->param('action') =~/^(?:copy|cut)$/xms) {
        return $self->get_functions()->handle_clipboard_action();
    }
    if ( $self->{backend}->isDir($PATH_TRANSLATED) ) {
        $self->optimize_css_and_js();
        return $self->render_web_interface();
    }
    return 0;
}
sub handle_login {
    my ($self) = @_;
    return $self->_get_renderer()->render_login();
}

sub get_thumbnail_renderer {
    my ($self) = @_;
    require WebInterface::ThumbnailRenderer;
    return $self->{config}->{thumbnailrender} =
      WebInterface::ThumbnailRenderer->new( $self->{config} );
}

sub get_functions {
    my $self = shift;
    require WebInterface::Functions;
    $self->{config}->{functions} = WebInterface::Functions->new( $self->{config} );
    return $self->{config}->{functions}->init();
}

sub _get_renderer {
    my ($self) = @_;
    my $view = "WebInterface::View::\u${VIEW}::Renderer";
    $view =~ s/[.\/]+//xmsg;
    if ( !-f "${INSTALL_BASE}lib/perl/WebInterface/View/\u${VIEW}/Renderer.pm" )
    {
        $view = "WebInterface::View::\u$SUPPORTED_VIEWS[0]::Renderer";
    }
    load $view;
    $self->{config}->{view} = $view->new( ${$self}{config} );
    return $self->{config}->{view}->init();
}

sub render_web_interface {
    my ( $self ) = @_;
    return $self->_get_renderer()->render();
}


sub get_extension_manager {
    my ($self) = @_;
    require WebInterface::Extension::Manager;
    return $self->{config}->{extensions} =
      WebInterface::Extension::Manager->new( $self->{config} );
}

sub print_styles_vhtdocs_files {
    my ( $self, $fn ) = @_;
    my $file =
        $fn =~ /\Q$VHTDOCS\E(.*)/xms
      ? $INSTALL_BASE . 'htdocs/' . $1
      : $INSTALL_BASE . 'lib/' . $self->{backend}->basename($fn);
    if ( $fn =~ /\Q$VHTDOCS\E_EXTENSION[(]([^)]+)[)]_(.*)/xms ) {
        $file = $INSTALL_BASE . 'lib/perl/WebInterface/Extension/' . $1 . $2;
    }
    elsif ( $fn =~ /\Q$VHTDOCS\E_OPTIMIZED[(](js|css)[)]_/xms ) {
        $file = $self->optimizer_get_filepath($1);
    }
    $file =~ s{/[.][.]/}{}xmsg;
    my $compression = !-e $file && -e "$file.gz";
    my $nfile = $file;
    if ($compression) { $file = "$nfile.gz"; }
    no locale;
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
            print($buffer) || carp('Cannot write to STDOUT!');
        }
        close $f || carp("Cannot close $file.");
        fix_mod_perl_response($headerref);
    }
    else {
        print_header_and_content('404 Not Found');
    }
    return;
}

sub _print_dav_mount {
    my ( $self, $fn ) = @_;
    my $su = $ENV{REDIRECT_SCRIPT_URI} || $ENV{SCRIPT_URI};
    my $bn = $self->{backend}->basename($fn);
    $su =~ s/\Q$bn\E\/?//xms;
    $bn .= $self->{backend}->isDir($fn) && $bn !~ /\/$/xms ? q{/} : q{};
    print_header_and_content(
        '200 OK',
        'application/davmount+xml',
qq@<dm:mount xmlns:dm="http://purl.org/NET/webdav/mount"><dm:url>$su</dm:url><dm:open>$bn</dm:open></dm:mount>@
    );
    return 1;
}

sub optimizer_is_optimized {
    my ($self) = @_;
    return $self->{isoptimized};
}

sub optimizer_get_filepath {
    my ( $self, $ft ) = @_;
    my $tmp = $OPTIMIZERTMP || $THUMBNAIL_CACHEDIR || '/var/tmp';
    my $optimizerbasefn = "${CONFIGFILE}_${RELEASE}_${REMOTE_USER}";
    $optimizerbasefn =~ s{[/.]}{_}xmsg;
    my $optimizerbase = $tmp . q{/} . $optimizerbasefn;
    return "${optimizerbase}.$ft";
}

sub optimize_css_and_js {
    my ($self) = @_;
    return if $self->{isoptimized} || $self->{notoptimized};
    $self->{isoptimized} = 0;

    my $csstargetfile = $self->optimizer_get_filepath('css') . '.gz';
    my $jstargetfile  = $self->optimizer_get_filepath('js') . '.gz';
    if (   ( -e $csstargetfile && !-w $csstargetfile )
        || ( -e $jstargetfile && !-w $jstargetfile ) )
    {
        $self->{notoptimized} = 1;
        carp(
"Cannot write optimized CSS and JavaScript to $csstargetfile and/or $jstargetfile"
        );
        return;
    }
    if (   -r $jstargetfile
        && -r $csstargetfile
        && ( stat $jstargetfile )[10] > ( stat $CONFIGFILE )[10] )
    {
        $self->{isoptimized} = 1;
        return;
    }

    ## collect CSS:
    my $tags = join "\n",
      @{ $self->get_extension_manager()->handle('css') // [] };
    my $content =
      $self->optimizer_extract_content_from_tags_and_attributes( $tags, 'css' );
    if ($content) {
        $self->optimizer_write_content2zip( $csstargetfile, \$content );
    }

    ## collect JS:
    $tags = join "\n",
      @{ $self->get_extension_manager()->handle('javascript') // [] };
    $content =
      $self->optimizer_extract_content_from_tags_and_attributes( $tags, 'js' );
    if ($content) {
        $self->optimizer_write_content2zip( $jstargetfile, \$content );
    }

    return $self->{isoptimized} = 1;
}

sub optimizer_write_content2zip {
    my ( $self, $file, $contentref ) = @_;
    if ( open my $fh, '>', $file ) {
        flock( $fh, LOCK_EX ) || carp("Cannot get exclusive lock for $file.");
        require IO::Compress::Gzip;
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
        my $image = q{};
        binmode($ih) || carp("Cannot set binmode for $ifn.");
        while ( read $ih, $buffer, $READBUFSIZE ) {
            $image .= $buffer;
        }
        close($ih) || carp("Cannot close filehandle for $ifn.");
        require MIME::Base64;
        return
            'url(data:'
          . $mime
          . ';base64,'
          . MIME::Base64::encode_base64( $image, q{} ) . ')';
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
s/url[(](.*?)[)]/$self->optimizer_encode_image($basepath, $1)/exmsig;
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
s{<style[^>]*>(.*?)</style>}{$self->optimizer_collect(\$content, undef, $1, $type)}exmsig;
        $data =~
s{<link[ ].*?href="(.*?)"}{$self->optimizer_collect(\$content, $1, undef, $type)}exmsig;
    }
    else {
        $data =~
s{<script[ ].*?src="([^>"]+)".*?>(.*?)</script>}{$self->optimizer_collect(\$content, $1, $2, $type)}exmsig;
    }

    return $content;
}

1;
