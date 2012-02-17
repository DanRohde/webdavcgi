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
        my ($self, $destdir, @files) = @_;
        foreach my $file (@files) {
                my $ndestdir=$destdir.$self->basename($file);
                if ($self->isDir($file)) {
                        $file.='/' if $file!~/\/$/;
                        if ($self->SUPER::mkcol($ndestdir)) {
                                foreach my $nfile (@{$self->readDir($file)}) {
                                        next if $nfile =~ /^\.{1,2}$/;
                                        $self->_copytolocal("$ndestdir/", "$file$nfile");
                                }
                        }
                } else {
                        if (open(my $fh, ">$ndestdir")) {
                                $self->printFile($file, $fh);
                                close($fh);
                        }
                }
                my @stat = $self->stat($file);
                utime($stat[8],$stat[9],$ndestdir);
        }
}
sub compressFiles {
        my ($self, $desthandle, $basepath, @files) = @_;

        my $tempdir = tempdir(CLEANUP => 1);
        foreach my $file (@files) {
                $self->_copytolocal("$tempdir/", "$basepath$file");
        }
        $self->SUPER::compressFiles($desthandle, "$tempdir/", @{$self->SUPER::readDir("$tempdir/")});
}

1;
