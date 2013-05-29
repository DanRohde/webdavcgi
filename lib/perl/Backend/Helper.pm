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

use Backend::FS::Driver;
our @ISA = qw( Backend::FS::Driver );

use File::Temp qw/ tempdir /;

our $VERSION = 0.1;

sub _copytolocal {
	my ( $self, $destdir, @files ) = @_;
	foreach my $file (@files) {
		my $ndestdir = $destdir . $self->basename($file);
		if ( $self->isDir($file) ) {
			$file .= '/' if $file !~ /\/$/;
			if ( $self->SUPER::mkcol($ndestdir) ) {
				foreach my $nfile ( @{ $self->readDir($file) } ) {
					next if $nfile =~ /^\.{1,2}$/;
					$self->_copytolocal( "$ndestdir/", "$file$nfile" );
				}
			}
		}
		else {
			if ( open( my $fh, ">$ndestdir" ) ) {
				$self->printFile( $file, $fh );
				close($fh);
			}
		}
		my @stat = $self->stat($file);
		utime( $stat[8], $stat[9], $ndestdir );
	}
}

sub compressFiles {
	my ( $self, $desthandle, $basepath, @files ) = @_;
	my $tempdir = tempdir( '/tmp/webdavcgi-compressFiles-XXXXX', CLEANUP => 1 );
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
	$zip->writeToFileHandle( $desthandle, 0 );
}

sub _copytodestination {
	my ( $self, $src, $dst ) = @_;
	my $ret = 0;
	if ( opendir( my $dir, $src ) ) {
		$ret = 1;
		while ( my $file = readdir($dir) ) {
			next if $file =~ /^\.{1,2}$/;
			my $nsrc = "$src$file";
			my $ndst = "$dst$file";
			if ( -d $nsrc ) {
				$self->mkcol($ndst);
				$ret &= $self->_copytodestination( "$nsrc/", "$ndst/" );
			}
			else {
				if ( open( my $fh, "<$nsrc" ) ) {
					$ret &= $self->saveStream( $ndst, $fh );
					close($fh);
				}
				else {
					$ret = 0;
				}
			}
		}
		closedir($dir);
	}
	return $ret;
}

sub __deltree {
	my ($file) = @_;
	if ( -l $file ) {
		CORE::unlink($file);
	}
	elsif ( -d $file ) {
		if ( opendir( my $dir, $file ) ) {
			foreach my $f ( grep { !/^\.{1,2}$/ } readdir($dir) ) {
				my $nf = $file . $f;
				$nf .= '/' if -d $nf;
				__deltree($nf);
			}
			closedir($dir);
			CORE::rmdir($file);
		}
	}
	elsif ( -e $file ) {
		CORE::unlink($file);
	}
}

sub uncompressArchive {
	my ( $self, $zipfile, $destination ) = @_;
	my $tempdir =
	  tempdir( '/tmp/webdav-uncompressArchive-XXXXX', CLEANUP => 1 );
	my $localzip = $self->getLocalFilename($zipfile);
	my $ret      =
	     $self->SUPER::uncompressArchive( $localzip, "$tempdir/" )
	  && $self->_copytodestination( "$tempdir/", $destination );
	CORE::unlink($localzip);
	__deltree("$tempdir/");    # fixes Speedy bug
	return $ret;
}

1;
