#!/usr/bin/perl
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

package Backend::GIT::Driver;

use strict;
use warnings;

our $VERSION = '1.0';

use base qw ( Backend::FS::Driver );

use Fcntl qw(:flock);
use CGI::Carp;

sub init {
    my ( $self, $config ) = @_;
    $self->SUPER::init($config);
    $self->{GIT} = $main::BACKEND_CONFIG{GIT}{gitcmd} // '/usr/bin/git';
    $self->{LOCKFILE} =
      $main::BACKEND_CONFIG{GIT}{lockfile} || '/tmp/webdav-git.lock';
    if ( !$self->isDir( $main::DOCUMENT_ROOT . '.git' ) ) {
        $self->execGit('init');
        $self->execGit( 'config', 'user.email', $ENV{REMOTE_USER} );
        $self->autoAdd();
    }
    return $self;
}

sub mkcolhier {
    my ( $self, $dir ) = @_;
    $self->mkcolhier( $self->dirname($dir) ) unless -d $self->dirname($dir);
    $self->mkcol($dir);
    return;
}

sub unlinkFile {
    my ( $self, $fn ) = @_;
    my $ret = $self->SUPER::unlinkFile($fn);
    $self->execGit( 'rm', $fn );
    $self->mkcolhier( $self->dirname($fn) );
    return $ret;
}

sub unlinkDir {
    my ( $self, $fn ) = @_;
    my $ret = $self->SUPER::unlinkDir($fn);
    $self->execGit( 'rm', '-r', $fn );
    return $ret;
}

sub exists {
    my ( $self, $fn ) = @_;
    return !$self->gitFilter( $self->dirname($fn), $self->basename($fn) )
      && $self->SUPER::exists($fn);
}

sub isDir {
    my ( $self, $fn ) = @_;
    return !$self->gitFilter( $self->dirname($fn), $self->basename($fn) )
      && $self->SUPER::isDir($fn);
}

sub isFile {
    my ( $self, $fn ) = @_;
    return !$self->gitFilter( $self->dirname($fn), $self->basename($fn) )
      && $self->SUPER::isFile($fn);
}

sub readDir {
    my ( $self, $dirname, $limit, $filter ) = @_;
    my $gitfilter = sub {
        my ( $d, $f ) = @_;
        return $self->gitFilter( $d, $f )
          || (
            defined $filter
            && (   ( ref($filter) eq 'CODE' && $filter->( $d, $f ) )
                || ( ref($filter) ne 'CODE' && $filter->filter( $d, $f ) ) )
          );
    };
    return $self->SUPER::readDir( $dirname, $limit, $gitfilter );
}

sub gitFilter {
    my ( $self, $dirname, $file ) = @_;
    return
         ( $file eq '.git' && $main::DOCUMENT_ROOT =~ /^\Q$dirname\E\/?$/xms )
      || $dirname =~ /^\Q$main::DOCUMENT_ROOT\E\.git(\/.*)?$/xms
      || $self->filter( undef, $dirname, $file );
}

sub deltree {
    my ( $self, $fn, $errRef ) = @_;
    my $ret = $self->SUPER::deltree( $fn, $errRef );
    $self->execGit( 'rm', '-r', $fn );
    return $ret;
}

sub saveData {
    my $self = shift @_;
    my $ret  = $self->SUPER::saveData(@_);
    $self->autoAdd();
    return $ret;
}

sub saveStream {
    my $self = shift @_;
    my $ret  = $self->SUPER::saveStream(@_);
    $self->autoAdd();
    return $ret;
}

sub compress_files {
    my ( $self, $desthandle, $basepath, @files ) = @_;

    require Archive::Zip;
    my $zip       = Archive::Zip->new();
    my $gitfilter = sub {
        return !$self->gitFilter( $self->dirname($_), $self->basename($_) );
    };
    foreach my $file (@files) {
        if ( $self->isDir( $basepath . $file ) ) {
            $zip->addTree( $self->resolveVirt( $basepath . $file ),
                $file, $gitfilter );
        }
        elsif ($self->isReadable( $basepath . $file )
            && $self->exists( $basepath . $file ) )
        {
            $zip->addFile( $self->resolveVirt( $basepath . $file ), $file )
              unless $self->gitFilter( $basepath, $file );
        }
    }
    return $zip->writeToFileHandle( $desthandle, 0 );
}

sub uncompress_archive {
    my ( $self, $zipfile, $destination ) = @_;
    my $ret = 1;
    require Archive::Zip;
    my $zip    = Archive::Zip->new();
    my $status = $zip->read( $self->resolveVirt($zipfile) );
    $ret = $status eq $zip->AZ_OK;
    if ($ret) {
        foreach my $member ( $zip->members() ) {
            my $fn = $self->resolveVirt($destination) . $member->fileName();
            if (
                !$self->gitFilter( $self->dirname($fn), $self->basename($fn) ) )
            {
                $zip->extractMember( $member, $fn );
            }
        }
    }
    $self->autoAdd();
    return $ret;
}

sub createSymLink {
    my ( $self, @args ) = @_;
    my $ret = $self->SUPER::createSymLink(@args);
    $self->autoAdd();
    return $ret;
}

sub rename {
    my ( $self, $src, $dst ) = @_;
    $self->execGit( 'mv', $src, $dst );
    delete $SUPER::CACHE{$src};
    delete $SUPER::CACHE{$dst};
    return !-e $src && -e $dst;
}

sub copy {
    my ( $self, $src, $dst ) = @_;
    my $ret = $self->SUPER::copy( $src, $dst );
    $self->autoAdd();
    return $ret;
}

sub execGit {
    my ( $self, @args ) = @_;
    return $self->_exec_git(@args) && $self->commit();
}

sub _exec_git {
    my ( $self, @args ) = @_;
    my @params = map { /^\Q$main::DOCUMENT_ROOT\E(.*)/xms ? $1 : $_ } @args;
    my $ret = 1;

    #warn(join(" ",@_));
    if ( open my $fd, '>', $self->{LOCKFILE} ) {
        chdir $main::DOCUMENT_ROOT;
        if ( ( !$main::ENABLE_FLOCK || flock $fd, LOCK_EX  )
            && open my $git, q{-|}, $self->{GIT}, @params )
        {
            my @output = <$git>;
            close($git) || carp('Cannot close git command.');
        }
        if ($main::ENABLE_FLOCK) { flock $fd, LOCK_UN; }
        close($fd) || carp('Cannot close lockfile for git command.');
    }
    else {
        $ret = 0;
    }

    return $ret;
}

sub autoAdd {
    my ($self) = @_;
    my $ret = 1;
    my @add;
    if ( open my $fd, '>', $self->{LOCKFILE} ) {
        $ret = !$main::ENABLE_FLOCK || flock $fd, LOCK_EX;
        chdir $main::DOCUMENT_ROOT;
        if ( $ret && open my $git, q{-|}, $self->{GIT}, 'status', '-s' ) {
            while ( <$git> ) {
                chomp;
                if ( /^[?][?] (.*)$/xms ) {
                    push @add, $1;
                }
            }
        }
        close($fd) || carp('Cannot close lock file for git auto add.');
    }
    else {
        $ret = 0;
    }
    return $ret
      && ( ( scalar(@add) > 0 && $self->execGit( 'add', @add ) )
        || $self->commit() );
}

sub commit {
    my ($self) = @_;
    return $self->_exec_git( 'commit', '--allow-empty', '-a', '-m',
        $ENV{REMOTE_USER} || $ENV{REDIRECT_REMOTE_USER} );
}

1;
