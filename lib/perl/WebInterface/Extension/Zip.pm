#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
#
# SETUP:
# disable_fileaction - disables fileaction entry
# disable_filelistaction - disables fileaction entry
# disable_fileactionpopup - disables fileaction entry in popup menu
# disable_new - disables new menu entry
# enable_apps - enables sidebar menu entry

package WebInterface::Extension::Zip;

use strict;
use warnings;

our $VERSION = '2.0';
use base qw( WebInterface::Extension  );

#use JSON;
use File::Temp qw(tempfile);
use POSIX qw(strftime);
use CGI::Carp;

#use Archive::Zip;    # for zipinfo + www.jstree.com

use DefaultConfig qw( $PATH_TRANSLATED $REQUEST_URI %EXTENSION_CONFIG );
use HTTPHelper qw( print_compressed_header_and_content );

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw( css locales javascript posthandler body templates );
    push @hooks, 'fileaction'
      unless $EXTENSION_CONFIG{Zip}{disable_fileaction};
    push @hooks, 'filelistaction'
      unless $EXTENSION_CONFIG{Zip}{disable_filelistaction};
    push @hooks, 'fileactionpopup'
      unless $EXTENSION_CONFIG{Zip}{disable_fileactionpopup};
    push @hooks, 'fileactionpopupnew'
      unless $EXTENSION_CONFIG{Zip}{disable_fileactionpopup};
    push @hooks, 'apps' if $EXTENSION_CONFIG{Zip}{enable_apps};
    push @hooks, 'new' unless $EXTENSION_CONFIG{Zip}{disable_fnew};

    $hookreg->register( \@hooks, $self );
    return $self;
}

sub handle_hook_fileaction {
    my ( $self, $config, $params ) = @_;
    return {
        action    => 'zipdwnload',
        accesskey => 'z',
        label     => 'zipdwnload',
        path      => $params->{path},
        classes   => 'access-readable'
    };
}

sub handle_hook_filelistaction {
    my ( $self, $config, $params ) = @_;
    return {
        action => 'zipdwnload',
        label      => 'zipdwnload',
        title      => 'zipdwnload',
        path       => ${$params}{path},
        classes    => 'sel-multi uibutton'
    };

}

sub handle_hook_fileactionpopup {
    my ( $self, $config, $params ) = @_;
    return {
        title        => $self->tl('zip.menu'),
        classes      => 'zip-popup',
        subpopupmenu => [
            {
                action  => 'zipup',
                label   => 'zipup',
                title   => 'zipup',
                path    => ${$params}{path},
                type    => 'li',
                classes => 'access-writeable sep'
            },
            {
                action  => 'zipdwnload',
                label   => 'zipdwnload',
                title   => 'zipdwnloadtext',
                path    => ${$params}{path},
                type    => 'li',
                classes => 'action'
            },
            {
                action  => 'zipcompress',
                label   => 'zip.compress',
                title   => 'zip.compress.title',
                path    => ${$params}{path},
                type    => 'li',
                classes => 'access-writeable'
            },
            {
                action  => 'zipuncompress',
                label   => 'zip.uncompress',
                title   => 'zip.uncompress.title',
                path    => ${$params}{path},
                type    => 'li',
                classes => 'access-writeable'
            }
        ]
    };
}

sub handle_hook_fileactionpopupnew {
    my ( $self, $config, $params ) = @_;
    return {
        action  => 'zipup',
        label   => 'zipup',
        title   => 'zipup',
        path    => ${$params}{path},
        type    => 'li',
        classes => 'access-writeable sep'
    };
}

sub handle_hook_new {
    my ( $self, $config, $params ) = @_;
    return {
        action    => 'zipup',
        label     => 'zipup',
        title     => 'zipup',
        path      => ${$params}{path},
        classes   => 'access-writeable sep',
        accesskey => 'w'
    };
}

sub handle_hook_apps {
    my ($self) = @_;
    return $self->handle_apps_hook( $self->{cgi},
        'action zipdwnload sel-multi disabled ',
        'zipdwnload', 'zipdwnload' );
}

sub handle_hook_body {
    my ($self) = @_;
    return $self->renderUploadFormTemplate();
}

sub handle_hook_templates {
    my ($self) = @_;
    return $self->renderMessageTemplate();
}

sub handle_hook_posthandler {
    my ( $self, $config, $params ) = @_;
    my $action = $self->{cgi}->param('action');
    if ( !defined $action || $action !~ /^(?:zipdwnload|zipup|zipcompress|zipuncompress)$/xms) {
        return 0;
    }
    if ( $action eq 'zipdwnload' ) {
        return $self->handleZipDownload();
    }
    if ( $action eq 'zipup' ) {
        return $self->handleZipUpload();
    }
    if ( $action eq 'zipcompress' ) {
        return $self->handleZipCompress();
    }
    if ( $action eq 'zipuncompress' ) {
        return $self->handleZipUncompress();
    }
    return 0;
}

sub renderUploadFormTemplate {
    my ($self) = @_;
    return $self->replace_vars( $self->read_template('zipfileuploadform') );
}

sub renderMessageTemplate {
    my ($self) = @_;
    return $self->replace_vars( $self->read_template('messages') );
}

sub handleZipUpload {
    my ($self) = @_;
    my @zipfiles;
    my ( $msg, $errmsg, $msgparam );
    foreach my $fh ( $self->get_cgi_multi_param('files') ) {
        my $rfn = $fh;
        $rfn =~ s/\\/\//xmsg;    # fix M$ Windows backslashes
        $rfn = $self->{backend}->basename($rfn);
        if ( $self->{config}->{method}->is_locked("$PATH_TRANSLATED$rfn") ) {
            $errmsg   = 'locked';
            $msgparam = [$rfn];
            last;
        }
        elsif ( $self->{backend}->saveStream( "$PATH_TRANSLATED$rfn", $fh ) ) {
            push @zipfiles, $rfn;
            $self->{backend}->unlinkFile( $PATH_TRANSLATED . $rfn )
              if $self->{backend}
              ->uncompress_archive( "$PATH_TRANSLATED$rfn", $PATH_TRANSLATED );
        }
    }
    if ( $#zipfiles > -1 ) {
        $msg = ( $#zipfiles > 0 ) ? 'zipupmulti' : 'zipupsingle';
        $msgparam =
          [ scalar(@zipfiles), substr( join( ', ', @zipfiles ), 0, 150 ) ];
    }
    else {
        $errmsg = 'zipupnothingerr';
    }
    my %jsondata = ();
    my @params =
      $msgparam ? map { $self->{cgi}->escapeHTML($_) } @{$msgparam} : ();
    if ($errmsg) {
        $jsondata{error} = sprintf( $self->tl("msg_$errmsg"), @params );
    }
    if ($msg) {
        $jsondata{message} = sprintf( $self->tl("msg_$msg"), @params );
    }
    require JSON;
    print_compressed_header_and_content(
        '200 OK',
        'application/json',
        JSON->new()->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}

sub getZipFilename {
    my ( $self, $files ) = @_;
    my $time = strftime( '%Y-%m-%d-%H:%M:%S', localtime );
    my $zipfilename = $self->{backend}->basename(
        scalar( @{$files} ) > 1
          || ${$files}[0] eq q{.} ? $REQUEST_URI : ${$files}[0],
        '.zip'
    ) . "-$time.zip";
    $zipfilename =~ s/[\/\ ]/_/xmsg;
    return $zipfilename;
}

sub handleZipDownload {
    my $self  = shift;
    my @files = $self->get_cgi_multi_param('files');
    my $zfn   = $self->getZipFilename( \@files );
    print $self->{cgi}->header(
        -status              => '200 OK',
        -type                => 'application/zip',
        -Content_disposition => 'attachment; filename=' . $zfn
    );
    $self->{backend}->compress_files( \*STDOUT, $PATH_TRANSLATED, @files );
    return 1;
}

sub handleZipCompress {
    my $self        = shift;
    my @files       = $self->get_cgi_multi_param('files');
    my $zipfilename = $self->getZipFilename( \@files );

    my ( $zipfh, $zipfn ) = tempfile(
        TEMPLATE => '/tmp/webdavcgi-Zip-XXXXX',
        CLEANUP  => 1,
        SUFFIX   => ".zip"
    );
    my $error;
    if ( open( $zipfh, ">", "$zipfn" ) ) {
        $self->{backend}->compress_files( $zipfh, $PATH_TRANSLATED, @files );
        close($zipfh) || carp("Cannot close $zipfn");
        if ( ( stat $zipfn )[7] > 0 ) {
            my ( $quotahrd, $quotacur ) = $self->{backend}->getQuota();
            if ( $quotahrd == 0
                || ( stat $zipfn )[7] + $quotacur < $quotahrd )
            {
                if ( open( $zipfh, '<', $zipfn ) ) {
                    ;
                    $self->{backend}
                      ->saveStream( $PATH_TRANSLATED . $zipfilename, $zipfh );
                    close($zipfh) || carp("Cannot close $zipfn");
                }
            }
            else {
                $error = $self->tl('msg_zipcompress_quotaexceeded');
            }
        }
        else {
            $error = $self->tl('msg_zipcompress_failed');
        }
    }
    my %jsondata = ();

    if ($error) {
        $jsondata{error} = $error;
    }
    else {
        $jsondata{message} = sprintf(
            $self->tl('msg_zipcompress'),
            $self->{cgi}->escapeHTML($zipfilename),
            $self->{cgi}->escapeHTML(
                scalar(@files) > 1 ? $files[0] . ",..." : $files[0]
            )
        );
    }
    unlink $zipfn;
    require JSON;
    print_compressed_header_and_content(
        '200 OK',
        'application/json',
        JSON->new()->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}

sub handleZipUncompress {
    my ($self) = @_;
    my @files = $self->get_cgi_multi_param('files');
    foreach my $file (@files) {
        $self->{backend}
          ->uncompress_archive( $PATH_TRANSLATED . $file, $PATH_TRANSLATED );
    }
    my %jsondata = ();
    $jsondata{message} = sprintf(
        $self->tl('msg_zipuncompress'),
        $self->{cgi}->escapeHTML( join( ', ', @files ) )
    );
    require JSON;
    print_compressed_header_and_content(
        '200 OK',
        'application/json',
        JSON->new()->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}

# TODO: implement zip info dialog
sub handleZipInfo {
    my ($self) = @_;
    my @files = $self->get_cgi_multi_param('files');
    ## common:comment, compressionMethod, chunkSize  tree: filename, lastmodified, fileattributes, comments, uncompressedISize
    return;
}
1;
