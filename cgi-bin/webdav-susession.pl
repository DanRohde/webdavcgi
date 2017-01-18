#!/usr/bin/perl
########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
# This script handles sessions and calls a setuid/setgid wrapper that
# calls webdav.pl.
# Requirements: - a session configuration (%SESSION) from $ENV{WEBDAVCONF}
#               - additionaly $SESSION{wrapper}

use strict;
use warnings;

our $VERSION = '1.1';

use CGI;
use CGI::Carp;
use English qw( -no_match_vars ) ;
use IO::Handle;
use IPC::Open3;

use DefaultConfig qw( init_defaults read_config %SESSION $REQUEST_METHOD $REQUEST_URI $CGI $RELEASE $READBUFSIZE $POST_MAX_SIZE);
use WebInterface;
use SessionAuthenticationHandler;
use WebDAVCGI;


sub letsplay {

    my $self = {};
    my $conf = $ENV{SESSIONCONF} // $ENV{WEBDAVCONF} // '/etc/webdav-session.conf';
    my $authheader = $ENV{AUTHHEADER};

    $RELEASE = $WebDAVCGI::RELEASE;
    $REQUEST_METHOD = $ENV{REQUEST_METHOD};
    $REQUEST_URI = $ENV{REQUEST_URI};
    $REQUEST_URI =~ s/[?].*$//xms;

    init_defaults();
    read_config($self, $conf);

    $SESSION{tokenname} //= 'TOKEN';

    *STDERR->autoflush(1);
    *STDOUT->autoflush(1);
    binmode STDIN;
    binmode STDOUT;


    $CGI::POST_MAX = $POST_MAX_SIZE;

    my ($file, $filename);
    if ($REQUEST_METHOD eq 'POST') {
        ($file, $filename) = _save_stdin();
        $CGI = CGI->new(_get_query( $file ));
    } else {
        $CGI = CGI->new();
    }

    my $handler = SessionAuthenticationHandler->new($CGI);
    my $ret = $handler->authenticate();

    if ($ret == 1) {
        $ENV{SESSION_WRAPPED} = 1;
        if ($file) {
            if (my $pid = open3(my $in, '>&STDOUT', '>&STDERR', $SESSION{wrapper})) {
                binmode $in;
                $in->autoflush(1);
                if (ref($file) eq 'GLOB') {
                    seek $file, 0, 0;
                    while (read $file, my $buffer, $READBUFSIZE) {
                        print {$in} $buffer;
                    }
                    close($file) || carp('Cannot close filehandle of temporary file with POST data.');
                    unlink $filename; ## only for modperl
                } else {
                    print ${in} $file;
                }
                waitpid $pid, 0;
                close($in) || carp("Cannot close $SESSION{wrapper}.");
            } else {
                carp("Cannot open session wrapper: $SESSION{wrapper}");
            }
        } else {
            system $SESSION{wrapper};
        }
        delete $ENV{SESSION_WRAPPED};
    } elsif ($ret == 0){
        require WebInterface;
        WebInterface->new()->init($self)->handle_login();
    }
    return;
}
sub _get_query {
    my ($file) = @_;
    my $rex = q{ ^ Content-Disposition: \s+ form-data; \s* name= ['"]? (}.$SESSION{tokenname}.q{) ['"]? \s* $};
    if (ref $file eq 'GLOB') {
        seek $file, 0, 0;
        my $content = q{};
        while (my $line = <$file>) {
            $content.=$line;
            if ($line =~ /$rex/xmsi) {
                $line = <$file>;
                $line = <$file>;
                $line =~ s/[\r\n]//xmsg;
                return "$SESSION{tokenname}=$line";
            }
        }
        return $content;
    }
    if ($file =~ / $rex  ^ \s* $  ^ \s* (\S+) \s* $/xmsi) {
        return "$1=$2";
    }
    return $file;
}
sub _save_stdin {
    my $rbs = $READBUFSIZE < $POST_MAX_SIZE ? $READBUFSIZE : $POST_MAX_SIZE;
    if (!$SESSION{usememtemp}) {
        require File::Temp;
        my ($fh, $filename) = File::Temp::tempfile('webdav-susession-XXXXXXX', TMPDIR=>1, SUFFIX=>'.POST', UNLINK=>1);
        $fh->autoflush(1);
        binmode $fh;
        my $size = 0;
        while ( my $rs = read STDIN, my $buffer, $rbs ) {
            print {$fh} $buffer;
            $size += $rs;
            if ($size >= $POST_MAX_SIZE) {
                last;
            }
            if ($size + $rbs > $POST_MAX_SIZE) {
                $rbs = $POST_MAX_SIZE - $size;
            }
        }
        close($fh) || carp("Cannot close filehandle for $filename");
        return _get_fh($filename);
    }
    my $file = q{};
    my $size = 0;
    while ( my $rs = read STDIN, my $buffer, $rbs ) {
        $file .= $buffer;
        $size += $rs;
        if ($size >= $POST_MAX_SIZE) {
            last;
        }
        if ($size + $rbs > $POST_MAX_SIZE) {
            $rbs = $POST_MAX_SIZE - $size;
        }
    }
    return $file;
}
sub _get_fh {
    my ($fn) = @_;
    my $fh;
    open($fh, '<', $fn) || carp("Cannot open $fn.");
    binmode $fh;
    $fh->autoflush(1);
    return ( $fh, $fn );
}
letsplay();

1;
