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

package WebInterface::Functions;

use strict;
use warnings;

our $VERSION = '2.0';
use base qw(WebInterface::Common);

use English qw(-no_match_vars);
use JSON;

use FileUtils qw( rcopy rmove move2trash );
use HTTPHelper qw( print_compressed_header_and_content );

sub new {
    my ( $this, $config ) = @_;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    $self->{config}   = $config;
    $self->{db}       = $config->{db};
    $self->{cgi}      = $config->{cgi};
    $self->{backend}  = $config->{backend};
    $self->{msglimit} = 150;
    $self->initialize();
    return $self;
}

sub _print_json_response {
    my ( $self, $msg, $errmsg, $msgparam ) = @_;
    my %jsondata = ();
    my @params
        = $msgparam ? map { ${$self}{cgi}->escapeHTML($_) } @{$msgparam} : ();
    if ($errmsg) {
        $jsondata{error} = sprintf $self->tl("msg_$errmsg"), @params;
    }
    if ($msg) {
        $jsondata{message} = sprintf $self->tl("msg_$msg"), @params;
    }
    print_compressed_header_and_content(
        '200 OK', 'application/json',
        JSON::encode_json( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return;
}

sub handle_post_upload {
    my ($self) = @_;
    my @filelist;
    my ( $msg, $errmsg, $msgparam ) = ( undef, undef, [] );
    foreach my $filename ( ${$self}{cgi}->param('file_upload') ) {
        if ( $filename eq q{} || !${$self}{cgi}->uploadInfo($filename) ) {
            next;
        }
        my $rfn = $filename;
        $rfn =~ s{\\}{/}xmsg;    # fix M$ Windows backslashes
        my $destination
            = $main::PATH_TRANSLATED . ${$self}{backend}->basename($rfn);
        push @filelist, ${$self}{backend}->basename($rfn);
        if ( main::isLocked("$destination$filename") ) {
            $errmsg   = 'locked';
            $msgparam = [$rfn];
        }
        elsif ( !${$self}{backend}->saveStream( $destination, $filename ) ) {
            $errmsg = 'uploadforbidden';
            push @{$msgparam}, $rfn;
        }
        else {
            main::broadcast(
                'WEB-UPLOADED',
                {   file => $destination,
                    size => ( ${$self}{backend}->stat($destination) )
                        [ ${$self}{STATIDX}{size} ]
                }
            );
        }
    }
    if ( !defined $errmsg ) {
        if ( $#filelist >= 0 ) {
            $msg = ( $#filelist > 0 ) ? 'uploadmulti' : 'uploadsingle';
            $msgparam = [
                scalar(@filelist), substr join( ', ', @filelist ),
                0,                 ${$self}{msglimit}
            ];
        }
        else {
            $errmsg = 'uploadnothingerr';
        }
    }

    return $self->_print_json_response( $msg, $errmsg, $msgparam );
}

sub handle_clipboard_action {
    my ($self) = @_;
    my ( $msg, $msgparam, $errmsg );
    my $srcuri = ${$self}{cgi}->param('srcuri');
    $srcuri =~ s/\%([a-f\d]{2})/chr(hex($1))/xmseig;
    $srcuri =~ s/^$main::VIRTUAL_BASE//xms;
    my $srcdir = $main::DOCUMENT_ROOT . $srcuri;
    my ( @success, @failed );
    foreach my $file ( split /\@\/\@/xms, ${$self}{cgi}->param('files') ) {

        if (   main::isLocked("$srcdir$file")
            || main::isLocked("$main::PATH_TRANSLATED$file") )
        {
            $errmsg = 'locked';
            push @failed, $file;
        }
        elsif (
            rcopy(
                "$srcdir$file",
                $main::PATH_TRANSLATED . $file,
                ${$self}{cgi}->param('action') eq 'cut'
            )
            )
        {
            $msg = ${$self}{cgi}->param('action') . 'success';
            push @success, $file;
        }
        else {
            $errmsg = ${$self}{cgi}->param('action') . 'failed';
            push @failed, $file;
        }
    }
    if ( defined $errmsg ) { $msg = undef; }
    $msgparam = [
        substr join( ', ', defined $msg ? @success : @failed ), 0,
        ${$self}{msglimit}
    ];
    return $self->_print_json_response( $msg, $errmsg, $msgparam );
}

sub _handle_delete_action {
    my ($self) = @_;
    my ( $msg, $errmsg, $msgparam );
    if ( defined ${$self}{cgi}->param('file') ) {
        my $count = 0;
        foreach my $file ( ${$self}{cgi}->param('file') ) {
            if ( $file eq q{.} ) { $file = q{}; }
            my $fullname
                = ${$self}{backend}->resolve("$main::PATH_TRANSLATED$file");
            if ( main::isLocked( $fullname, 1 ) ) {
                $count    = 0;
                $errmsg   = 'locked';
                $msgparam = [$file];
                last;
            }
            if ( $fullname =~ /^\Q$main::DOCUMENT_ROOT\E/xms ) {
                my $full = $main::PATH_TRANSLATED . $file;
                main::broadcast( 'WEB-DELETE', { file => $full } );
                if ($main::ENABLE_TRASH) {
                    $count += move2trash($full);
                }
                else {
                    $count
                        += ${$self}{backend}->deltree( $full, \my @err );
                }
                main::broadcast( 'WEB-DELETED', { file => $full } );
                main::logger("DELETE($main::PATH_TRANSLATED) via POST");
            }
        }
        if ( $count > 0 ) {
            $msg = ( $count > 1 ) ? 'deletedmulti' : 'deletedsingle';
            $msgparam = [$count];
        }
        else {
            $errmsg = 'deleteerr';
        }
    }
    else {
        $errmsg = 'deletenothingerr';
    }
    return ( $msg, $errmsg, $msgparam );
}

sub _handle_rename_action {
    my ($self) = @_;
    my ( $msg, $errmsg, $msgparam );
    if ( defined ${$self}{cgi}->param('file') ) {
        if (main::isLocked(
                $main::PATH_TRANSLATED . ${$self}{cgi}->param('file')
            )
            )
        {
            $errmsg   = 'locked';
            $msgparam = [ ${$self}{cgi}->param('file') ];
        }
        elsif (
            ${$self}{cgi}->param('newname')
            && main::isLocked(
                $main::PATH_TRANSLATED . ${$self}{cgi}->param('newname')
            )
            )
        {
            $errmsg   = 'locked';
            $msgparam = [ ${$self}{cgi}->param('newname') ];
        }
        elsif ( defined ${$self}{cgi}->param('newname') ) {
            my $newname = ${$self}{cgi}->param('newname');
            $newname =~ s/\/$//xms;
            my @files = ${$self}{cgi}->param('file');
            if (( $#files > 0 )
                && ( !${$self}{backend}
                    ->isDir( $main::PATH_TRANSLATED . $newname ) )
                )
            {
                $errmsg = 'renameerr';
            }

            #elsif ( $newname =~ /\// ) {
            #   $errmsg = 'renamenotargeterr';
            #}
            else {
                $msgparam = [ join( ', ', @files ), $newname ];
                foreach my $file (@files) {
                    my $target = $main::PATH_TRANSLATED . $newname;
                    $target .=
                        ${$self}{backend}->isDir($target)
                        ? q{/} . $file
                        : q{};
                    if ( rmove( $main::PATH_TRANSLATED . $file, $target ) ) {
                        $msg = 'rename';
                        main::logger(
                            "MOVE $main::PATH_TRANSLATED$file to $target via POST"
                        );
                    }
                    else {
                        $errmsg = 'renameerr';
                        $msg    = undef;
                    }
                }
            }
        }
        else {
            $errmsg = 'renamenotargeterr';
        }
    }
    else {
        $errmsg = 'renamenothingerr';
    }
    return ( $msg, $errmsg, $msgparam );
}

sub _handle_mkcol_action {
    my ($self) = @_;
    my ( $msg, $errmsg, $msgparam );
    my $colname = ${$self}{cgi}->param('colname1')
        // ${$self}{cgi}->param('colname');
    if ( $colname ne q{} ) {
        $msgparam = [$colname];
        if ( $colname !~ /\//xms
            && ${$self}{backend}->mkcol( $main::PATH_TRANSLATED . $colname ) )
        {
            main::logger("MKCOL($main::PATH_TRANSLATED$colname via POST");
            $msg = 'foldercreated';
            main::broadcast( 'WEB-FOLDERCREATED',
                { file => $main::PATH_TRANSLATED . $colname } );
        }
        else {
            $errmsg = 'foldererr';
            push @{$msgparam},
                ${$self}{backend}->exists( $main::PATH_TRANSLATED . $colname )
                ? $self->tl('folderexists')
                : $self->tl($ERRNO);
        }
    }
    else {
        $errmsg = 'foldernothingerr';
    }
    return ( $msg, $errmsg, $msgparam );
}

sub _handle_createsymlink_action {
    my ($self) = @_;
    my ( $msg, $errmsg, $msgparam );
    my $lndst = ${$self}{cgi}->param('lndst');
    my $file  = ${$self}{cgi}->param('file');
    if ( defined $lndst && $lndst ne q{} ) {
        if ( defined $file && $file ne q{} ) {
            $msgparam = [ $lndst, $file ];
            $file = ${$self}{backend}->resolve("$main::PATH_TRANSLATED$file");
            $lndst
                = ${$self}{backend}->resolve("$main::PATH_TRANSLATED$lndst");
            if (   $file =~ /^\Q$main::DOCUMENT_ROOT\E/xms
                && $lndst =~ /^\Q$main::DOCUMENT_ROOT\E/xms
                && ${$self}{backend}->createSymLink( $file, $lndst ) )
            {
                $msg = 'symlinkcreated';
                main::broadcast( 'WEB-SYMLINKCREATED',
                    { file => $lndst, src => $file } );
            }
            else {
                $errmsg = 'createsymlinkerr';
                push @{$msgparam}, $ERRNO;
            }
        }
        else {
            $errmsg = 'createsymlinknoneselerr';
        }
    }
    else {
        $errmsg = 'createsymlinknolinknameerr';
    }
    return ( $msg, $errmsg, $msgparam );
}

sub _handle_createnewfile_action {
    my ($self) = @_;
    my ( $msg, $errmsg, $msgparam );
    my $fn   = ${$self}{cgi}->param('cnfname');
    my $full = $main::PATH_TRANSLATED . $fn;
    if (   ${$self}{backend}->isWriteable($main::PATH_TRANSLATED)
        && !${$self}{backend}->exists($full)
        && ( $fn !~ /\//xms )
        && ${$self}{backend}->saveData( $full, q{}, 1 ) )
    {
        $msg      = 'newfilecreated';
        $msgparam = [$fn];
        main::broadcast( 'WEB-FILECREATED', { file => $full, size => 0 } );
    }
    else {
        $msgparam = [
            $fn,
            (   ${$self}{backend}->exists($full)
                ? $self->tl('fileexists')
                : $self->tl($ERRNO)
            )
        ];
        $errmsg = 'createnewfileerr';
    }
    return ( $msg, $errmsg, $msgparam );
}

sub handle_file_actions {
    my ($self) = @_;
    if ( ${$self}{cgi}->param('delete') ) {
        return $self->_print_json_response( $self->_handle_delete_action() );
    }
    if ( ${$self}{cgi}->param('rename') ) {
        return $self->_print_json_response( $self->_handle_rename_action() );
    }
    if ( ${$self}{cgi}->param('mkcol') ) {
        return $self->_print_json_response( $self->_handle_mkcol_action() );
    }
    if ( ${$self}{cgi}->param('createsymlink') && $main::ALLOW_SYMLINK ) {
        return $self->_print_json_response(
            $self->_handle_createsymlink_action() );
    }
    if ( ${$self}{cgi}->param('createnewfile') ) {
        return $self->_print_json_response(
            $self->_handle_createnewfile_action() );
    }
    return 0;
}

1;
