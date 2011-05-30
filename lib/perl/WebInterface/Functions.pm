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
our @ISA = ( 'WebInterface::Common' );


use File::Basename;

sub new {
       my $this = shift;
       my $class = ref($this) || $this;
       my $self = { };
       bless $self, $class;
       $$self{cgi}=shift;
       $$self{backend}=shift;
       $$self{db}=shift;
       return $self;
}
sub handlePostUpload {
	my ($self,$redirtarget) = @_;
	my @filelist;
	my ($msg, $errmsg, $msgparam) = (undef,undef, '');
	foreach my $filename ($$self{cgi}->param('file_upload')) {
		next if $filename eq "";
		next unless $$self{cgi}->uploadInfo($filename);
		my $rfn= $filename;
		$rfn=~s/\\/\//g; # fix M$ Windows backslashes
		my $destination = $main::PATH_TRANSLATED.basename($rfn);
		push(@filelist, basename($rfn));
		if (!$$self{backend}->saveStream($destination, $filename)) {
			$errmsg='uploadforbidden';
			if ($msgparam eq '') { $msgparam='p1='.$rfn; } else { $msgparam.=', '.$rfn; }
		}
	}
	if (!defined $errmsg) {
		if ($#filelist>-1) {
			$msg=($#filelist>0)?'uploadmulti':'uploadsingle';
			$msgparam='p1='.($#filelist+1).';p2='.$$self{cgi}->escape(substr(join(', ',@filelist), 0, 150));
		} else {
			$errmsg='uploadnothingerr';
		}
	}
	print $$self{cgi}->redirect($redirtarget.$self->createMsgQuery($msg,$msgparam,$errmsg,$msgparam));
}
sub handleZipUpload {
	my ($self,$redirtarget) = @_;;
        my @zipfiles;
	my ($msg,$errmsg, $msgparam);
	foreach my $fh ($$self{cgi}->param('zipfile_upload')) {
		my $rfn= $fh;
		$rfn=~s/\\/\//g; # fix M$ Windows backslashes
		$rfn=basename($rfn);

		if ($$self{backend}->saveStream("$main::PATH_TRANSLATED$rfn", $fh)) {
			push @zipfiles, $rfn;
			$$self{backend}->unlinkFile($main::PATH_TRANSLATED.$rfn) if $$self{backend}->uncompressArchive("$main::PATH_TRANSLATED$rfn", $main::PATH_TRANSLATED);
		}
	}
	if ($#zipfiles>-1) {
		$msg=($#zipfiles>0)?'zipuploadmulti':'zipuploadsingle';
		$msgparam='p1='.($#zipfiles+1).';p2='.$$self{cgi}->escape(substr(join(', ',@zipfiles), 0, 150));
	} else {
		$errmsg='zipuploadnothingerr';
	}
	print $$self{cgi}->redirect($redirtarget.$self->createMsgQuery($msg,$msgparam,$errmsg,$msgparam));
}
sub createMsgQuery {
        my ($self,$msg,$msgparam,$errmsg,$errmsgparam,$prefix) = @_;
        $prefix='' unless defined $prefix;
        my $query ="";
        $query.=";${prefix}msg=$msg" if defined $msg;
        $query.=";$msgparam" if $msgparam;
        $query.=";${prefix}errmsg=$errmsg" if defined $errmsg;
        $query.=";$errmsgparam" if defined $errmsg && $errmsgparam;
        return "?t=".time().$query;
}
sub handleClipboardAction {
	my ($self,$redirtarget) = @_;
	my ($msg,$msgparam, $errmsg) ;
	my $srcuri = $$self{cgi}->param('srcuri');
	$srcuri=~s/\%([a-f0-9]{2})/chr(hex($1))/eig;
	$srcuri=~s/^$main::VIRTUAL_BASE//;
	my $srcdir = $main::DOCUMENT_ROOT.$srcuri;
	my (@success,@failed);
	foreach my $file (split(/\@\/\@/, $$self{cgi}->param('files'))) {
		if (main::rcopy("$srcdir$file", "$main::PATH_TRANSLATED$file", $$self{cgi}->param('action') eq 'cut')) {
			$msg=$$self{cgi}->param("action").'success';
			push @success,$file;
		} else {
			$errmsg=$$self{cgi}->param("action").'failed';
			push @failed,$file;
		}
	}
	$msg= undef if defined $errmsg;
	$msgparam='p1='.$$self{cgi}->escape(substr(join(', ', defined $msg ? @success : @failed),0,150));
	print $$self{cgi}->redirect($redirtarget.$self->createMsgQuery($msg,$msgparam,$errmsg,$msgparam));
}
sub handleZipDownload {
	my $self = shift;
	my $zfn = basename($main::PATH_TRANSLATED).'.zip';
	$zfn=~s/ /_/;
	print $$self{cgi}->header(-status=>'200 OK', -type=>'application/zip',-Content_disposition=>'attachment; filename='.$zfn);
	$$self{backend}->compressFiles(\*STDOUT, $main::PATH_TRANSLATED, $$self{cgi}->param('file'));

}
sub handleFileActions {
	my ($self,$redirtarget) = @_;
	my ($msg,$errmsg, $msgparam);
	if ($$self{cgi}->param('delete')) {
		if ($$self{cgi}->param('file')) {
			my $count = 0;
			foreach my $file ($$self{cgi}->param('file')) {
				$file = "" if $file eq '.';
				my $fullname = $$self{backend}->resolve("$main::PATH_TRANSLATED$file");
				if ($fullname=~/^\Q$main::DOCUMENT_ROOT\E/) {
					if ($main::ENABLE_TRASH) {
						$$self{backend}->moveToTrash($main::PATH_TRANSLATED.$file);
					} else {
						$count += $$self{backend}->deltree($main::PATH_TRANSLATED.$file, \my @err);
					}
					main::logger("DELETE($main::PATH_TRANSLATED) via POST");
				}
			}
			if ($count>0) {
				$msg= ($count>1)?'deletedmulti':'deletedsingle';
				$msgparam="p1=$count";
			} else {
				$errmsg='deleteerr';
			}
		} else {
			$errmsg='deletenothingerr';
		}
	} elsif ($$self{cgi}->param('rename')) {
		if ($$self{cgi}->param('file')) {
			if ($$self{cgi}->param('newname')) {
				my @files = $$self{cgi}->param('file');
				if (($#files > 0)&&(! $$self{backend}->isDir($main::PATH_TRANSLATED.$$self{cgi}->param('newname')))) {
					$errmsg='renameerr';
				} elsif ($$self{cgi}->param('newname')=~/\//) {
					$errmsg='renamenotargeterr';
				} else {
					$msg='rename';
					$msgparam = 'p1='.$$self{cgi}->escape(join(', ',@files))
						  . ';p2='.$$self{cgi}->escape($$self{cgi}->param('newname'));
					foreach my $file (@files) {
						my $target = $main::PATH_TRANSLATED.$$self{cgi}->param('newname');
						$target.='/'.$file if $$self{backend}->isDir($target);
						if (main::rmove($main::PATH_TRANSLATED.$file, $target)) {
							main::logger("MOVE $main::PATH_TRANSLATED$file to $target via POST");
						} else {
							$errmsg='renameerr';
						}
					}
				}
			} else {
				$errmsg='renamenotargeterr';
			}
		} else {
			$errmsg='renamenothingerr';
		}
	} elsif ($$self{cgi}->param('mkcol'))  {
		my $colname = $$self{cgi}->param('colname') || $$self{cgi}->param('colname1');
		if ($colname ne "") {
			$msgparam="p1=".$$self{cgi}->escape($colname);
			if ($colname!~/\// && $$self{backend}->mkcol($main::PATH_TRANSLATED.$colname)) {
				main::logger("MKCOL($main::PATH_TRANSLATED$colname via POST");
				$msg='foldercreated';
			} else {
				$errmsg='foldererr';
				$msgparam.=';p2='.($$self{backend}->exists($main::PATH_TRANSLATED.$colname) ? $$self{cgi}->escape($self->tl('folderexists')) : $$self{cgi}->escape($self->tl($!)));
			}
		} else {
			$errmsg='foldernothingerr';
		}
	} elsif ($$self{cgi}->param('createsymlink') && $main::ALLOW_SYMLINK) {
		my $lndst = $$self{cgi}->param('lndst');
		my $file = $$self{cgi}->param('file');
		if ($lndst && $lndst ne "") {
			if ($file && $file ne "") {
				$msgparam.="p1=".$$self{cgi}->escape($lndst);
				$msgparam.=";p2=".$$self{cgi}->escape($file);
				$file = $$self{backend}->resolve("$main::PATH_TRANSLATED$file");
				$lndst = $$self{backend}->resolve("$main::PATH_TRANSLATED$lndst");
				if ($file=~/^\Q$main::DOCUMENT_ROOT\E/ && $lndst=~/^\Q$main::DOCUMENT_ROOT\E/ && $$self{backend}->createSymLink($file, $lndst)) {
					$msg='symlinkcreated';
				}  else {
					$errmsg='createsymlinkerr';
					$msgparam.=";p3=".$$self{cgi}->escape($!);
				}
			} else {
				$errmsg='createsymlinknoneselerr';
			}
		} else {
			$errmsg='createsymlinknolinknameerr';
		}
	} elsif ($$self{cgi}->param('changeperm')) {
		if ($$self{cgi}->param('file')) {
			my $mode = 0000;
			foreach my $userperm ($$self{cgi}->param('fp_user')) {
				$mode = $mode | 0400 if $userperm eq 'r' && grep(/^r$/,@{$main::PERM_USER}) == 1;
				$mode = $mode | 0200 if $userperm eq 'w' && grep(/^w$/,@{$main::PERM_USER}) == 1;
				$mode = $mode | 0100 if $userperm eq 'x' && grep(/^x$/,@{$main::PERM_USER}) == 1;
				$mode = $mode | 04000 if $userperm eq 's' && grep(/^s$/,@{$main::PERM_USER}) == 1;
			}
			foreach my $grpperm ($$self{cgi}->param('fp_group')) {
				$mode = $mode | 0040 if $grpperm eq 'r' && grep(/^r$/,@{$main::PERM_GROUP}) == 1;
				$mode = $mode | 0020 if $grpperm eq 'w' && grep(/^w$/,@{$main::PERM_GROUP}) == 1;
				$mode = $mode | 0010 if $grpperm eq 'x' && grep(/^x$/,@{$main::PERM_GROUP}) == 1;
				$mode = $mode | 02000 if $grpperm eq 's' && grep(/^s$/,@{$main::PERM_GROUP}) == 1;
			}
			foreach my $operm ($$self{cgi}->param('fp_others')) {
				$mode = $mode | 0004 if $operm eq 'r' && grep(/^r$/,@{$main::PERM_OTHERS}) == 1;
				$mode = $mode | 0002 if $operm eq 'w' && grep(/^w$/,@{$main::PERM_OTHERS}) == 1;
				$mode = $mode | 0001 if $operm eq 'x' && grep(/^x$/,@{$main::PERM_OTHERS}) == 1;
				$mode = $mode | 01000 if $operm eq 't' && grep(/^t$/,@{$main::PERM_OTHERS}) == 1;
			}

			$msg='changeperm';
			$msgparam=sprintf("p1=%04o",$mode);
			foreach my $file ($$self{cgi}->param('file')) {
				$file="" if $file eq '.';
				$$self{backend}->changeFilePermissions($main::PATH_TRANSLATED.$file, $mode, $$self{cgi}->param('fp_type'), $main::ALLOW_CHANGEPERMRECURSIVE && $$self{cgi}->param('fp_recursive'));
			}
		} else {
			$errmsg='chpermnothingerr';
		}
	} elsif ($$self{cgi}->param('edit')) {
		my $file = $$self{cgi}->param('file');
		my $full = $main::PATH_TRANSLATED. $file;
		my $regex = '('.join('|',@main::EDITABLEFILES).')';
		if ($file!~/\// && $file=~/$regex/ && $$self{backend}->isFile($full) && $$self{backend}->isWriteable($full)) {
			$msgparam='edit='.$$self{cgi}->escape($file).'#editpos';
		} else {
			$errmsg='editerr';
			$msgparam='p1='.$$self{cgi}->escape($file);
		}
	} elsif ($$self{cgi}->param('savetextdata') || $$self{cgi}->param('savetextdatacont')) {
		my $file = $main::PATH_TRANSLATED . $$self{cgi}->param('filename');
		if ($$self{backend}->isFile($file) && $$self{backend}->isWriteable($file) && $$self{backend}->saveData($file, $$self{cgi}->param('textdata'))) {
			$msg='textsaved';
		} else {
			$errmsg='savetexterr';
		}
		$msgparam='p1='.$$self{cgi}->escape(''.$$self{cgi}->param('filename'));
		$msgparam.=';edit='.$$self{cgi}->escape($$self{cgi}->param('filename')) if $$self{cgi}->param('savetextdatacont');
	} elsif ($$self{cgi}->param('createnewfile')) {
		my $fn = $$self{cgi}->param('cnfname');
		my $full = $main::PATH_TRANSLATED.$fn;
		if ($$self{backend}->isWriteable($main::PATH_TRANSLATED) && !$$self{backend}->exists($full) && ($fn !~ /\//) && $$self{backend}->saveData($full,"",1)) {
			$msg='newfilecreated';
			$msgparam='p1='.$$self{cgi}->escape($fn);
		} else {
			$msgparam='p1='.$$self{cgi}->escape($fn).';p2='.($$self{backend}->exists($full) ? $$self{cgi}->escape($self->tl('fileexists')) : $$self{cgi}->escape($self->tl($!)));
			$errmsg='createnewfileerr';
		}
	}
	print $$self{cgi}->redirect($redirtarget.$self->createMsgQuery($msg,$msgparam, $errmsg, $msgparam));
}
sub isValidAFSGroupName { return $_[1] =~ /^[a-z0-9\_\@\:]+$/i; }
sub isValidAFSUserName { return $_[1] =~ /^[a-z0-9\_\@]+$/i; }
sub isValidAFSACL { return $_[1] =~ /^[rlidwka]+$/; }
sub doAFSSaveACL() {
        my ($self,$redirtarget) = @_;
        my ($pacls, $nacls) = ( "","");
        my ($msg,$errmsg,$msgparam);
        foreach my $param ($$self{cgi}->param()) {
                my $value = join("", $$self{cgi}->param($param));
                if ($param eq "up") {
                        $pacls .= sprintf("\"%s\" \"%s\" ", $$self{cgi}->param("up_add"), $value)
                                if ($self->isValidAFSUserName($$self{cgi}->param("up_add")) || $self->isValidAFSGroupName($$self{cgi}->param("up_add"))) && $self->isValidAFSACL($value);
                } elsif ($param eq "un") {
                        $nacls .= sprintf("\"%s\" \"%s\" ", $$self{cgi}->param("un_add"), $value)
                                if ($self->isValidAFSUserName($$self{cgi}->param("un_add")) || $self->isValidAFSGroupName($$self{cgi}->param("un_add"))) && $self->isValidAFSACL($value);
                } elsif ($param =~ /^up\[([^\]]+)\]$/) {
                        $pacls .= sprintf("\"%s\" \"%s\" ", $1, $value)
                                if ($self->isValidAFSUserName($1) || $self->isValidAFSGroupName($1)) && $self->isValidAFSACL($value);
                } elsif ($param =~ /^un\[([^\]]+)\]$/) {
                        $nacls .= sprintf("\"%s\" \"%s\" ", $1, $value)
                                if ($self->isValidAFSUserName($1) || $self->isValidAFSGroupName($1)) && $self->isValidAFSACL($value);
                }
        }
        my $output = "";
        if ($pacls ne "") {
                my $cmd;
                my $fn = $main::PATH_TRANSLATED;
                $fn=~s/(["\$\\])/\\$1/g;
                $cmd= qq@$main::AFS_FSCMD setacl -dir \"$fn\" -acl $pacls -clear 2>&1@;
                $output = qx@$cmd@;
                if ($nacls ne "") {
                        $cmd = qq@$main::AFS_FSCMD setacl -dir \"$fn\" -acl $nacls -negative 2>&1@;
                        $output .= qx@$cmd@;
                }
        } else { $output = $self->tl('empty normal rights'); }
        if ($output eq "") {
                $msg='afsaclchanged';
                $msgparam='p1='.$$self{cgi}->escape($pacls).';p2='.$$self{cgi}->escape($nacls);
        } else {
                $errmsg='afsaclnotchanged';
                $msgparam='p1='.$$self{cgi}->escape($output);
        }
        print $$self{cgi}->redirect($redirtarget.$self->createMsgQuery($msg, $msgparam, $errmsg, $msgparam,'acl').'#afsaclmanagerpos');
}
sub doAFSGroupActions {
        my ($self,$redirtarget ) = @_;
        my ($msg, $errmsg, $msgparam);
        my $grp = $$self{cgi}->param('afsgrp') || '';
        my $output;
        if ($$self{cgi}->param('afschgrp')) {
                if ($$self{cgi}->param('afsgrp')) {
                        $msg = '';
                        $msgparam='afsgrp='.$$self{cgi}->escape($$self{cgi}->param('afsgrp')) if $self->isValidAFSGroupName($$self{cgi}->param('afsgrp'));
                } else {
                        $errmsg = 'afsgrpnothingsel';
                }
        } elsif (!$main::ALLOW_AFSGROUPCHANGES)  {
                ## do nothing
        } elsif ($$self{cgi}->param('afsdeletegrp')) {
                if ($self->isValidAFSGroupName($grp)) {
                        $output = qx@$main::AFS_PTSCMD delete "$grp" 2>&1@;
                        if ($output eq "") {
                                $msg = 'afsgrpdeleted';
                                $msgparam='p1='.$$self{cgi}->escape($grp);
                        } else {
                                $errmsg = 'afsgrpdeletefailed';
                                $msgparam='afsgroup='.$$self{cgi}->escape($grp).';p1='.$$self{cgi}->escape($grp).';p2='.$$self{cgi}->escape($output);
                        }
                } else {
                        $errmsg = 'afsgrpnothingsel';
                }
        } elsif ($$self{cgi}->param('afscreatenewgrp')) {
                $grp = $$self{cgi}->param('afsnewgrp');
                $grp=~s/^\s+//; $grp=~s/\s+$//;
                if ($self->isValidAFSGroupName($grp)) {
                        $output = qx@$main::AFS_PTSCMD creategroup $grp 2>&1@;
                        if ($output eq "" || $output =~ /^group \Q$grp\E has id/i) {
                                $msg = 'afsgrpcreated';
                                $msgparam='afsgrp='.$$self{cgi}->escape($grp).';p1='.$$self{cgi}->escape($grp);
                        } else {
                                $errmsg = 'afsgrpcreatefailed';
                                $msgparam='p1='.$$self{cgi}->escape($grp).';p2='.$$self{cgi}->escape($output);
                        }
                } else {
                        $errmsg = 'afsgrpnogroupnamegiven';
                }
        } elsif ($$self{cgi}->param('afsrenamegrp')) {
                my $ngrp = $$self{cgi}->param('afsnewgrpname') || '';
                if ($self->isValidAFSGroupName($grp)) {
                        if ($self->isValidAFSGroupName($ngrp)) {
                                $output = qx@$main::AFS_PTSCMD rename -oldname \"$grp\" -newname \"$ngrp\" 2>&1@;
                                if ($output eq "") {
                                        $msg = 'afsgrprenamed';
                                        $msgparam = 'afsgrp='.$$self{cgi}->escape($ngrp).';p1='.$$self{cgi}->escape($grp).';p2='.$$self{cgi}->escape($ngrp);
                                } else {
                                        $errmsg = 'afsgrprenamefailed';
                                        $msgparam = 'afsgrp='.$$self{cgi}->escape($grp).';afsnewgrpname='.$$self{cgi}->escape($ngrp).';p1='.$$self{cgi}->escape($grp).';p2='.$$self{cgi}->escape($ngrp).';p3='.$$self{cgi}->escape($output);
                                }
                        } else {
                                $errmsg = 'afsnonewgroupnamegiven';
                                $msgparam='afsgrp='.$$self{cgi}->escape($grp).';p1='.$$self{cgi}->escape($grp);
                        }
                } else {
                        $errmsg = 'afsgrpnothingsel';
                        $msgparam=';afsnewgrpname='.$$self{cgi}->escape($ngrp);
                }
        } elsif ($$self{cgi}->param('afsremoveusr')) {
                $grp = $$self{cgi}->param('afsselgrp') || '';
                if ($self->isValidAFSGroupName($grp)) {
                        my @users;
                        foreach ($$self{cgi}->param('afsusr')) { push @users,$_ if $self->isValidAFSUserName($_)||$self->isValidAFSGroupName($_); }
                        if ($#users >-1) {
                                my $userstxt = '"'.join('" "', @users).'"';
                                $output = qx@$main::AFS_PTSCMD removeuser -user $userstxt -group \"$grp\" 2>&1@;
                                if ($output eq "") {
                                        $msg = 'afsuserremoved';
                                        $msgparam = 'afsgrp='.$$self{cgi}->escape($grp).';p1='.$$self{cgi}->escape(join(', ',@users)).';p2='.$$self{cgi}->escape($grp);
                                } else {
                                        $errmsg = 'afsusrremovefailed';
                                        $msgparam = 'afsgrp='.$$self{cgi}->escape($grp).';p1='.$$self{cgi}->escape(join(', ',@users)).';p2='.$$self{cgi}->escape($grp).';p3='.$$self{cgi}->escape($output);
                                }
                        } else {
                                $errmsg = 'afsusrnothingsel';
                                $msgparam='afsgrp='.$$self{cgi}->escape($grp);
                        }
                } else {
                        $errmsg = 'afsgrpnothingsel';
                }
        } elsif ($$self{cgi}->param('afsaddusr')) {
                $grp = $$self{cgi}->param('afsselgrp') || '';
                if ($self->isValidAFSGroupName($grp)) {
                        my @users;
                        foreach (split(/\s+/, $$self{cgi}->param('afsaddusers'))) { push @users,$_ if $self->isValidAFSUserName($_)||$self->isValidAFSGroupName($_); }
                        if ($#users > -1) {
                                my $userstxt = '"'.join('" "', @users).'"';
                                $output = qx@$main::AFS_PTSCMD adduser -user $userstxt -group "$grp" 2>&1@;
                                if ($output eq "") {
                                        $msg = 'afsuseradded';
                                        $msgparam = 'afsgrp='.$$self{cgi}->escape($grp).';p1='.$$self{cgi}->escape(join(', ',@users)).';p2='.$$self{cgi}->escape($grp);
                                } else {
                                        $errmsg = 'afsadduserfailed';
                                        $msgparam = 'afsgrp='.$$self{cgi}->escape($grp).';afsaddusers='.$$self{cgi}->escape($$self{cgi}->param('afsaddusers')).';p1='.$$self{cgi}->escape($$self{cgi}->param('afsaddusers')).';p2='.$$self{cgi}->escape($grp).';p3='.$$self{cgi}->escape($output);
                                }

                        } else {
                                $errmsg = 'afsnousersgiven';
                                $msgparam='afsgrp='.$$self{cgi}->escape($grp).';p1='.$$self{cgi}->escape($grp);
                        }
                } else {
                        $errmsg = 'afsgrpnothingsel';
                }
        }

        print $$self{cgi}->redirect($redirtarget.$self->createMsgQuery($msg, $msgparam, $errmsg, $msgparam, 'afs').'#afsgroupmanagerpos');
}


1;
