#!/usr/bin/perl
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2013 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package Backend::RO::Driver;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Backend::Helper );

use DefaultConfig qw( $BACKEND %BACKEND_CONFIG );
use Backend::Manager;

sub init {
    my ( $self, $config ) = @_;
    $self->{BACKEND} =
      Backend::Manager::getinstance()
      ->get_backend( $BACKEND_CONFIG{$BACKEND}{backend} || 'FS',
        $self->{config} );
    $self->SUPER::init($config);
    return $self;
}

sub finalize {
    $_[0]{BACKEND}->finalize();
}

sub basename {
    return $_[0]{BACKEND}->basename( $_[1] );
}

sub dirname {
    return $_[0]{BACKEND}->dirname( $_[1] );
}

sub exists {
    return $_[0]{BACKEND}->exists( $_[1] );
}

sub isDir {
    return $_[0]{BACKEND}->isDir( $_[1] );
}

sub isFile {
    return $_[0]{BACKEND}->isFile( $_[1] );
}

sub isLink {
    return $_[0]{BACKEND}->isLink( $_[1] );
}

sub isBlockDevice {
    return $_[0]{BACKEND}->isBlockDevice( $_[1] );
}

sub isCharDevice {
    return $_[0]{BACKEND}->isCharDevice( $_[1] );
}

sub isEmpty {
    return $_[0]{BACKEND}->isEmpty( $_[1] );
}

sub isReadable {
    return $_[0]{BACKEND}->isReadable( $_[1] );
}

sub isWriteable {
    return 0;
}

sub isExecutable {
    return 0;
}

sub getParent {
    return $_[0]{BACKEND}->getParent( $_[1] );
}

sub mkcol {
    return 0;
}

sub unlinkFile {
    return 0;
}

sub unlinkDir {
    return 0;
}

sub readDir {
    my $self = shift @_;
    return $$self{BACKEND}->readDir(@_);
}

sub filter {
    my $self = shift @_;
    return $$self{BACKEND}->filter(@_);
}

sub stat {
    return $_[0]{BACKEND}->stat( $_[1] );
}

sub lstat {
    return $_[0]{BACKEND}->lstat( $_[1] );
}

sub deltree {
    return 0;
}

sub changeFilePermissions {
    return 0;
}

sub saveData {
    return 0;
}

sub saveStream {
    return 0;
}

sub uncompress_archive {
    return 0;
}

sub compress_files {
    my $self = shift @_;
    return $$self{BACKEND}->compress_files(@_);
}

sub changeMod {
    return 0;
}

sub createSymLink {
    return 0;
}

sub getLinkSrc {
    return $_[0]{BACKEND}->getLinkSrc( $_[1] );
}

sub resolveVirt {
    return $_[0]{BACKEND}->resolveVirt( $_[1] );
}

sub resolve {
    return $_[0]{BACKEND}->resolve( $_[1] );
}

sub getFileContent {
    return $_[0]{BACKEND}->getFileContent( $_[1] );
}

sub hasSetUidBit {
    return $_[0]{BACKEND}->hasSetUidBit( $_[1] );
}

sub hasSetGidBit {
    return $_[0]{BACKEND}->hasSetGidBit( $_[1] );
}

sub hasStickyBit {
    return $_[0]{BACKEND}->hasStickyBit( $_[1] );
}

sub getLocalFilename {
    return $_[0]{BACKEND}->getLocalFilename( $_[1] );
}

sub printFile {
    return $_[0]{BACKEND}->printFile( $_[1], $_[2], $_[3], $_[4] );
}

sub getDisplayName {
    return $_[0]{BACKEND}->getDisplayName( $_[1] );
}

sub rename {
    return 0;
}

sub getQuota {
    return $_[0]{BACKEND}->getQuota( $_[1] );
}

sub copy {
    return 0;
}

sub isVirtualLink {
    return $_[0]{BACKEND}->isVirtualLink( $_[1] );
}

sub getVirtualLinkTarget {
    return $_[0]{BACKEND}->getVirtualLinkTarget( $_[1] );
}
1;
