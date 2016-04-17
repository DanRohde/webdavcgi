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

package Backend::Driver;

use strict;
use warnings;

use CGI::Carp;

our $VERSION = '2.0';

sub new {
    my $this  = shift;
    my $class = ref($this) || $this;
    my $self  = {};
    bless $self, $class;
    return $self;
}

sub init {
    my ( $self, $config ) = @_;

    $self->{config} = $config;
    $self->{db}     = $config->{db};
    $self->{method} = $config->{method};
    $self->{cgi}    = $config->{cgi};

    return $self;
}

sub finalize {
    confess('implement finalize!');
}

sub basename {
    confess('implement basename!');
}

sub dirname {
    confess('implement dirname!');
}

sub exists {
    confess('implement exists!');
}

sub isDir {
    confess('implement isDir!');
}

sub isFile {
    confess('implement isFile!');
}

sub isLink {
    confess('implement isLink!');
}

sub isBlockDevice {
    confess('implement isBlockDevice!');
}

sub isCharDevice {
    confess('implement isCharDevice!');
}

sub isEmpty {
    confess('implement isEmpty!');
}

sub isReadable {
    confess('implement isReadable!');
}

sub isWriteable {
    confess('implement isWriteable!');
}

sub isExecutable {
    confess('implement isExecutable!');
}

sub getParent {
    confess('implement getParent!');
}

sub mkcol {
    confess('implement mkcol!');
}

sub unlinkFile {
    confess('implement unlinkFile!');
}

sub unlinkDir {
    confess('implement unlinkDir!');
}

sub readDir {
    confess('implement readDir!');
}

sub filter {
    my ( $self, $filter, $dirname, $file ) = @_;
    return 1 if defined $file && $file =~ /^[.]{1,2}$/xms;
    return defined $filter
      && ( ( ref($filter) eq 'CODE' && $filter->( $dirname, $file ) )
        || ( ref($filter) ne 'CODE' && $filter->filter( $dirname, $file ) ) );
}

sub stat {
    confess('implement stat!');
}

sub lstat {
    confess('implement lstat!');
}

sub deltree {
    confess('implement deltree!');
}

sub changeFilePermissions {
    carp(
'implement changeFilePermissions because some extensions like Permissions need it!'
    );
}

sub saveData {
    confess('implement saveData!');
}

sub saveStream {
    confess('implement saveStream!');
}

sub uncompress_archive {
    carp(
        'implement uncompress_archive because some extensions like Zip need it!'
    );
}

sub compress_files {
    carp(
'implement compress_files because some extensions like Zip, SendByMail need it!'
    );
}

sub changeMod {
    confess('implement changeMod if you allow ACL requests!');
}

sub createSymLink {
    confess('implement createSymLink if you allow symlinks!');
}

sub getLinkSrc {
    confess('implement getLinkSrc if you allow symlinks!');
}

sub resolveVirt {
    confess('implement resolveVirt!');
}

sub resolve {
    confess('implement resolve!');
}

sub getFileContent {
    confess('implement getFileContent!');
}

sub hasSetUidBit {
    confess('implement hasSetUidBit!');
}

sub hasSetGidBit {
    confess('implement hasSetGidBit!');
}

sub hasStickyBit {
    confess('implement hasStickyBit!');
}

sub getLocalFilename {
    confess('implement getLocalFilename!');
}

sub printFile {
    confess('implement printFile!');
}

sub getDisplayName {
    confess('implement getDisplayName!');
}

sub rename {
    confess('implement rename!');
}

sub getQuota {
    confess('implement getQuota!');
}

sub copy {
    confess('implement copy!');
}

1;
