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

package Backend::Helper;

use strict;
use warnings;

use base qw( Backend::FS::Driver );
use File::Temp qw/ tempdir /;
use CGI::Carp;

use FileUtils qw( stat2h );

our $VERSION = '2.0';

sub _copytolocal {
    my ( $self, $destdir, @files ) = @_;
    foreach my $file (@files) {
        my $ndestdir = $destdir . $self->basename($file);
        if ( $self->isDir($file) ) {
            $file .= $file !~ m{/$}xms ? q{/} : q{};
            if ( $self->SUPER::mkcol($ndestdir) ) {
                foreach my $nfile ( @{ $self->readDir($file) } ) {
                    if ( $nfile !~ /^[.]{1,2}$/xms ) {
                        $self->_copytolocal( "$ndestdir/", "$file$nfile" );
                    }
                }
            }
        }
        else {
            if ( open my $fh, '>', $ndestdir ) {
                $self->printFile( $file, $fh );
                close($fh) || carp("Cannot close $ndestdir");
            }
        }
        my $stat = stat2h( $self->stat($file) );
        utime $stat->{atime}, $stat->{mtime}, $ndestdir;
    }
    return;
}

sub compress_files {
    my ( $self, $desthandle, $basepath, @files ) = @_;
    my $tempdir =
      tempdir( '/tmp/webdavcgi-compress-files-XXXXX', CLEANUP => 1 );
    require Archive::Zip;
    my $zip = Archive::Zip->new();
    foreach my $file (@files) {
        $self->_copytolocal( "$tempdir/", "$basepath$file" );
        if ( -d "$tempdir/$file" ) {
            $zip->addTree( "$tempdir/$file", $file );
        }
        elsif ( -e "$tempdir/$file" ) {
            $zip->addFile( "$tempdir/$file", $file );
        }
    }
    return $zip->writeToFileHandle( $desthandle, 0 );
}

sub _copytodestination {
    my ( $self, $src, $dst ) = @_;
    my $ret = 0;
    if ( opendir my $dir, $src ) {
        $ret = 1;
        while ( my $file = readdir $dir ) {
            if ( $file =~ /^[.]{1,2}$/xms ) { next; }
            my $nsrc = "$src$file";
            my $ndst = "$dst$file";
            if ( -d $nsrc ) {
                $self->mkcol($ndst);
                $ret &= $self->_copytodestination( "$nsrc/", "$ndst/" );
            }
            else {
                if ( open my $fh, '<', $nsrc ) {
                    $ret &= $self->saveStream( $ndst, $fh );
                    close($fh) || carp("Cannot close $nsrc.");
                }
                else {
                    $ret = 0;
                }
            }
        }
        closedir $dir;
    }
    return $ret;
}

sub __deltree {
    my ($file) = @_;
    if ( -l $file ) {
        return CORE::unlink($file);
    }
    if ( -d $file ) {
        if ( opendir my $dir, $file ) {
            foreach my $f ( grep { !/^[.]{1,2}$/xms } readdir $dir ) {
                my $nf = $file . $f;
                $nf .= -d $nf ? q{/} : q{};
                __deltree($nf);
            }
            closedir $dir;
            return CORE::rmdir($file);
        }
        return 0;
    }
    if ( -e $file ) {
        return CORE::unlink($file);
    }
    return 0;
}

sub uncompress_archive {
    my ( $self, $zipfile, $destination ) = @_;
    my $tempdir =
      tempdir( '/tmp/webdav-uncompress_archive-XXXXX', CLEANUP => 1 );
    my $localzip = $self->getLocalFilename($zipfile);
    my $ret = $self->SUPER::uncompress_archive( $localzip, "$tempdir/" )
      && $self->_copytodestination( "$tempdir/", $destination );
    CORE::unlink($localzip);
    __deltree("$tempdir/");    # fixes Speedy bug
    return $ret;
}
sub getLocalFilename {
    my ( $self, $file ) = @_;
    if ( $self->exists($file) ) {
        my $suffix = $file =~ m{([.][^./]+)$}xms ? $1 : undef;
        require File::Temp; 
        my ( $fh, $filename ) = File::Temp::tempfile(
            TEMPLATE => '/tmp/webdavcgiXXXXX',
            CLEANUP  => 1,
            SUFFIX   => $suffix
        );
        $self->printFile( $file, $fh );
        close($fh) || carp("Cannot close $file.");
        my $stat = stat2h( $self->stat($file) );
        utime $stat->{atime}, $stat->{mtime}, $filename;
        return $filename;
    }
    return $file;
}

1;
