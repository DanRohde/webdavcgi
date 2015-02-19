#!/usr/bin/perl
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

use WebInterface::Common;
our @ISA = ('WebInterface::Common');

use JSON;

sub new {
	my $this  = shift;
	my $class = ref($this) || $this;
	my $self  = {};
	bless $self, $class;
	$$self{config} = shift;
	$$self{db}     = shift;
	$self->initialize();
	return $self;
}

sub printJSONResponse {
	my ($self, $msg, $errmsg, $msgparam) = @_;
	my %jsondata = ();
	my @params = $msgparam ? map { $$self{cgi}->escapeHTML($_) } @{ $msgparam } : (); 
	$jsondata{error} = sprintf($self->tl("msg_$errmsg"), @params) if $errmsg;
	$jsondata{message} = sprintf($self->tl("msg_$msg"), @params ) if $msg;		
	my $json = new JSON();
	main::printCompressedHeaderAndContent('200 OK','application/json',$json->encode(\%jsondata),'Cache-Control: no-cache, no-store');
}

sub handlePostUpload {
	my ( $self, $redirtarget ) = @_;
	my @filelist;
	my ( $msg, $errmsg, $msgparam ) = ( undef, undef, [] );
	foreach my $filename ( $$self{cgi}->param('file_upload') ) {
		next if $filename eq "";
		next unless $$self{cgi}->uploadInfo($filename);
		my $rfn = $filename;
		$rfn =~ s/\\/\//g;    # fix M$ Windows backslashes
		my $destination = $main::PATH_TRANSLATED . $$self{backend}->basename($rfn);
		push( @filelist, $$self{backend}->basename($rfn) );
		if (main::isLocked("$destination$filename")) {
			$errmsg = 'locked';
			$msgparam =  [ $rfn ];
		} elsif ( !$$self{backend}->saveStream( $destination, $filename ) ) {
			$errmsg = 'uploadforbidden';
			push @{$msgparam}, $rfn;
		} else {
			main::broadcastEvent('WEB-UPLOADED', { file=> $destination, size=>($$self{backend}->stat($destination))[7] })
		}
	}
	if ( !defined $errmsg ) {
		if ( $#filelist > -1 ) {
			$msg = ( $#filelist > 0 ) ? 'uploadmulti' : 'uploadsingle';
			$msgparam = [ scalar(@filelist) , substr( join( ', ', @filelist ), 0, 150 ) ];
		}
		else {
			$errmsg = 'uploadnothingerr';
		}
	}
	
	$self->printJSONResponse($msg, $errmsg, $msgparam);
}

sub handleClipboardAction {
	my ( $self, $redirtarget ) = @_;
	my ( $msg, $msgparam, $errmsg );
	my $srcuri = $$self{cgi}->param('srcuri');
	$srcuri =~ s/\%([a-f0-9]{2})/chr(hex($1))/eig;
	$srcuri =~ s/^$main::VIRTUAL_BASE//;
	my $srcdir = $main::DOCUMENT_ROOT . $srcuri;
	my ( @success, @failed );
	foreach my $file ( split( /\@\/\@/, $$self{cgi}->param('files') ) ) {
		if (main::isLocked("$srcdir$file") || main::isLocked("$main::PATH_TRANSLATED$file")) {
			$errmsg = 'locked';
			push @failed, $file;
		} elsif (main::rcopy("$srcdir$file",$main::PATH_TRANSLATED.$file, $$self{cgi}->param('action') eq 'cut')) {
			$msg = $$self{cgi}->param("action") . 'success';
			push @success, $file;
		}
		else {
			$errmsg = $$self{cgi}->param("action") . 'failed';
			push @failed, $file;
		}
	}
	$msg = undef if defined $errmsg;
	$msgparam =  [ substr( join( ', ', defined $msg ? @success : @failed ), 0, 150 ) ];
	$self->printJSONResponse($msg, $errmsg, $msgparam);
}

sub handleFileActions {
	my ( $self, $redirtarget ) = @_;
	my ( $msg, $errmsg, $msgparam );
	if ( $$self{cgi}->param('delete') ) {
		if ( defined $$self{cgi}->param('file') ) {
			my $count = 0;
			foreach my $file ( $$self{cgi}->param('file') ) {
				$file = "" if $file eq '.';
				my $fullname = $$self{backend}->resolve("$main::PATH_TRANSLATED$file");
				if (main::isLocked($fullname,1)) {
					$count=0;
					$errmsg='locked';
					$msgparam = [ $file ];
					last;
				} 
				if ( $fullname =~ /^\Q$main::DOCUMENT_ROOT\E/ ) {
					my $full = $main::PATH_TRANSLATED.$file;
					main::broadcastEvent('WEB-DELETE', {file => $full});
					if ($main::ENABLE_TRASH) {
						$count += main::moveToTrash( $full );
					}
					else {
						$count += $$self{backend}->deltree( $full, \my @err );
					}
					main::broadcastEvent('WEB-DELETED', {file => $full});
					main::logger("DELETE($main::PATH_TRANSLATED) via POST");
				}
			}
			if ( $count > 0 ) {
				$msg = ( $count > 1 ) ? 'deletedmulti' : 'deletedsingle';
				$msgparam =  [ $count ];
			}
			else {
				$errmsg = 'deleteerr';
			}
		}
		else {
			$errmsg = 'deletenothingerr';
		}
	}
	elsif ( $$self{cgi}->param('rename') ) {
		if ( defined $$self{cgi}->param('file') ) {
			if (main::isLocked($main::PATH_TRANSLATED.$$self{cgi}->param('file'))) {
				$errmsg = 'locked';
				$msgparam =  [ $$self{cgi}->param('file') ];
			} elsif ($$self{cgi}->param('newname') && main::isLocked($main::PATH_TRANSLATED.$$self{cgi}->param('newname'))) {
				$errmsg = 'locked';
				$msgparam =  [ $$self{cgi}->param('newname') ];
			} elsif (defined $$self{cgi}->param('newname') ) {
				my $newname = $$self{cgi}->param('newname');
				$newname =~ s/\/$//;
				my @files = $$self{cgi}->param('file');
				if (( $#files > 0 ) && ( !$$self{backend}->isDir( $main::PATH_TRANSLATED . $newname ) ) )
				{
					$errmsg = 'renameerr';
				}
				#elsif ( $newname =~ /\// ) {
				#	$errmsg = 'renamenotargeterr';
				#}
				else {
					$msgparam = [ join( ', ', @files), $newname ];
					foreach my $file (@files) {
						my $target = $main::PATH_TRANSLATED . $newname;
						$target .= '/' . $file
						  if $$self{backend}->isDir($target);
						if (main::rmove($main::PATH_TRANSLATED . $file, $target ) ) {
							$msg = 'rename';
							main::logger("MOVE $main::PATH_TRANSLATED$file to $target via POST");
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
	}
	elsif ( $$self{cgi}->param('mkcol') ) {
		my $colname = $$self{cgi}->param('colname1') // $$self{cgi}->param('colname') ;
		if ( $colname ne "" ) {
			$msgparam =  [ $colname ];
			if (   $colname !~ /\//
				&& $$self{backend}->mkcol( $main::PATH_TRANSLATED . $colname ) )
			{
				main::logger("MKCOL($main::PATH_TRANSLATED$colname via POST");
				$msg = 'foldercreated';
				main::broadcastEvent('WEB-FOLDERCREATED', { file=>$main::PATH_TRANSLATED.$colname});
			}
			else {
				$errmsg = 'foldererr';
				push @{$msgparam}, $$self{backend}->exists( $main::PATH_TRANSLATED . $colname ) ?  $self->tl('folderexists') : $self->tl($!);
			}
		}
		else {
			$errmsg = 'foldernothingerr';
		}
	}
	elsif ( $$self{cgi}->param('createsymlink') && $main::ALLOW_SYMLINK ) {
		my $lndst = $$self{cgi}->param('lndst');
		my $file  = $$self{cgi}->param('file');
		if ( defined $lndst && $lndst ne "" ) {
			if ( defined $file && $file ne "" ) {
				$msgparam = [ $lndst, $file ];
				$file = $$self{backend}->resolve("$main::PATH_TRANSLATED$file");
				$lndst =
				  $$self{backend}->resolve("$main::PATH_TRANSLATED$lndst");
				if (   $file =~ /^\Q$main::DOCUMENT_ROOT\E/
					&& $lndst =~ /^\Q$main::DOCUMENT_ROOT\E/
					&& $$self{backend}->createSymLink( $file, $lndst ) )
				{
					$msg = 'symlinkcreated';
					main::broadcastEvent('WEB-SYMLINKCREATED', {file=>$lndst, src=>$file});
				}
				else {
					$errmsg = 'createsymlinkerr';
					push @{$msgparam}, $!;
				}
			}
			else {
				$errmsg = 'createsymlinknoneselerr';
			}
		}
		else {
			$errmsg = 'createsymlinknolinknameerr';
		}
	}
	elsif ( $$self{cgi}->param('createnewfile') ) {
		my $fn   = $$self{cgi}->param('cnfname');
		my $full = $main::PATH_TRANSLATED . $fn;
		if (   $$self{backend}->isWriteable($main::PATH_TRANSLATED)
			&& !$$self{backend}->exists($full)
			&& ( $fn !~ /\// )
			&& $$self{backend}->saveData( $full, "", 1 ) )
		{
			$msg      = 'newfilecreated';
			$msgparam = [ $fn ];
			main::broadcastEvent('WEB-FILECREATED',{file=>$full, size=>0});
		}
		else {
			$msgparam = [ $fn , ( $$self{backend}->exists($full) ? $self->tl('fileexists') : $self->tl($!) ) ];
			$errmsg = 'createnewfileerr';
		}
	}
	else {
		return 0;
	}
	$self->printJSONResponse($msg,$errmsg,$msgparam);
}

1;