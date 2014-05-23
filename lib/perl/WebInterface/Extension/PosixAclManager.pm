#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package WebInterface::Extension::PosixAclManager;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension );

use JSON;


sub new {
        my $this = shift;
        my $class = ref($this) || $this;
        my $self = { };
        bless $self, $class;
        $self->init(shift);
        return $self;
}

sub init { 
	my($self, $hookreg) = @_; 
	$hookreg->register(['css','javascript','gethandler','fileactionpopup','apps','locales','posthandler'], $self);
	
	## set some defaults:
	$$self{getfacl} = $main::EXTENSION_CONFIG{PosixAclManager}{getfacl} || '/usr/bin/getfacl';
	$$self{setfacl} = $main::EXTENSION_CONFIG{PosixAclManager}{setfacl} || '/usr/bin/setfacl';
}

sub handle { 
	my ($self, $hook, $config, $params) = @_; 
	my $ret = 0;
	$$self{cgi} = $$config{cgi};
	$$self{config} = $config;
	$$self{backend} = $$config{backend};
	$self->initialize(); ## Common::initialize to set correct LANG, ...
	$self->setLocale(); ## Common:setLocale to set right locale
	if ($hook eq 'fileaction') {
		$ret = { action=>'pacl', disabled=>0, label=>'pacl', path=>$$params{path}};
	} elsif( $hook eq 'fileactionpopup') {
		$ret = { action=>'pacl', disabled=>0, label=>'pacl', path=>$$params{path}, type=>'li', classes=>'sel-noneorone' };
	} elsif ( $hook eq 'css' ) {
		$ret = $self->handleCssHook('PosixAclManager');
	} elsif ( $hook eq 'javascript' ) {
		$ret = $self->handleJavascriptHook('PosixAclManager');
	} elsif ( $hook eq 'locales') {
		$ret = $self->handleLocalesHook('PosixAclManager');
	} elsif ( $hook eq 'apps') {
		$ret = $self->handleAppsHook($$self{cgi}, 'pacl listaction sel-noneorone disabled','pacl');
	} elsif ( $hook eq 'posthandler') {
		if ($$self{cgi}->param('ajax') eq 'getPosixAclManager') {
			$ret = $self->renderPosixAclManager();
		} elsif ($$self{cgi}->param('action') eq 'pacl_update') {
			$ret = $self->handleAclUpdate();
		} elsif ($$self{cgi}->param('ajax') eq 'searchUserOrGroupEntry') {
			$ret = $self->handleUserOrGroupEntrySearch();
		}
	}
	return $ret; 
}
sub quoteParam {
	my ($self,$v) = @_;
	$v =~ s@(["\$\\])@\\$1@g;
	return $v;
}
sub handleAclUpdate {
	my ($self) = @_;
	my $c = $$self{cgi};
	my $fn = $self->quoteParam($$self{backend}->resolveVirt($main::PATH_TRANSLATED));
	
	my $recursive = $c->param('recursive') eq 'yes' ? '-R' : '';
	my $output = "";
	foreach my $param ($c->param()) {
		my $val = join('',$c->param($param));
		my $cmd = undef;
		if ($val=~/^[rwxM\-]+$/ && $param =~/^acl:([a-z]+:[^"\s]*)$/i ) {
			my $e = $self->quoteParam($1);
			if ($val eq 'M') {
				if ($e=~/^\S+:$/) {
					$cmd = sprintf('%s %s -m "%s:"- -- "%s"',$$self{setfacl}, $recursive, $e, $fn);
				} else {
					$cmd = sprintf('%s %s -x "%s" -- "%s"',$$self{setfacl}, $recursive, $e, $fn);
				}
			} else {
				$val=~s/M//g;
				if ($val=~/---/) {
					$cmd = sprintf('%s %s -m "%s:-" -- "%s"',$$self{setfacl}, $recursive, $e, $fn);	
				} else {
					$cmd = sprintf('%s %s -m "%s:%s" -- "%s"',$$self{setfacl}, $recursive, $e,$val, $fn);
				}
			}
			
		} elsif ($param eq 'newacl' && $val=~/^[a-z]+:[^"\s]*$/i) {
			my $e = $self->quoteParam(join("",$c->param('newaclpermissions')));
			if ($e && $e=~/^[rwx\-]+$/) {
				if ($e =~ /---/) {
					$cmd = sprintf('%s %s -m "%s:-" -- "%s"',$$self{setfacl}, $recursive, $val, $fn);
				} else {
					$cmd = sprintf('%s %s -m "%s:%s" -- "%s"',$$self{setfacl}, $recursive, $val, $e, $fn);
				}
			}			
		}
		if (defined $cmd) {
			main::debug($cmd);
			$output .=qx@$cmd 2>&1@;
			#$output.= $?==-1 ? 'command failed' : ( $? & 127 ? 'child died with '.($? & 127) : 'command failed with exit code '.($? >>8)) if $?;
		}
	}
	my %jsondata;
	if ($output ne "") {
		$jsondata{error} = $c->escapeHTML($output); 
	} else {
		$jsondata{msg} = sprintf($self->tl('pacl_msg_success'), $c->escapeHTML($c->param('filename')));
	}
	my $json = new JSON();
	main::printCompressedHeaderAndContent('200 OK','application/json',$json->encode(\%jsondata),'Cache-Control: no-cache, no-store');
	return 1;
}
sub renderPosixAclManager {
	my ($self) = @_;
	my $content = "";
	my $c = $$self{cgi};
	
	my @defaultpermissions = ('r','w','x','---');

	my $f = $c->param('files');
	$f='.' if $f eq '';
	my $fn = $self->normalizeFilename($f);
	
	$content .= $c->start_form(-method=>'POST',-action=>"$main::REQUEST_URI$f",-class=>'pacl form');
	$content .= $c->hidden(-name=>'filename', -value=>$f).$c->hidden(-name=>'action',-value=>'pacl_update');
	$content .= $c->start_table({-class=>'pacl table'});
	
	$content.= $c->Tr($c->th({-title=>$self->getStatInfo($fn),-colspan=>2},$c->escapeHTML($f)));
	#$content.= $c->Tr($c->th($self->tl('pacl_entry')).$c->th($self->tl('pacl_rights')));
	foreach my $e (@{$self->getAclEntries($fn)}) {
		my $row = "";
		
		$row.=$c->td($$e{type}.':'.$$e{uid});
		my $permentry = "";
		my @perms = $$e{permission} eq '---' ? ('---') : split(//, $$e{permission});
		$permentry.=$c->checkbox_group(-name=>'acl:'.$$e{type}.':'.$$e{uid}, -values=>\@defaultpermissions, -class=>'permissions', -defaults=>\@perms);
		$permentry.=$c->hidden(-name=>'acl:'.$$e{type}.':'.$$e{uid}, -value=>'M');		
		$row.=$c->td($permentry);
		$content.=$c->Tr({-title=>"$$e{type}:$$e{uid}"},$row);	
	};
	$content.=$c->Tr($c->td($c->textfield(-name=>'newacl', -class=>'pacl newacl')),$c->td({-class=>'pacl newaclpermissions'},$c->checkbox_group(-name=>'newaclpermissions', -class=>'permissions',-values=>\@defaultpermissions)));
	$content.=$c->Tr($c->td($c->checkbox(-name=>'recursive',-value=>'yes',-label=>$self->tl('pacl_recursive'))).$c->td($c->submit(-name=>'pacl_update',-value=>$self->tl('pacl_update'))));
	$content.=$c->end_table().$c->end_form();
	$content.=$c->div({-class=>'pacl legend'}, $self->tl('pacl_legend')); 
	$content.=$c->div({-class=>'template',-id=>'pacl_msg_err_usergroup'}, $self->tl('pacl_msg_err_usergroup'));
	$content.=$c->div({-class=>'template',-id=>'pacl_msg_err_perm'}, $self->tl('pacl_msg_err_perm'));
	
	main::printCompressedHeaderAndContent('200 OK','text/html',$c->div({-class=>'pacl manager',-title=>$self->tl('pacl')},$content), 'Cache-Control: no-cache, no-store');
	return 1;
}
sub getStatInfo {
	my($self,$fn) = @_;
	my @stat = $$self{backend}->stat($fn);
	return "uid=".scalar(getpwuid($stat[4]))." ($stat[4]), gid=".scalar(getgrgid($stat[5]))." ($stat[5]), mode=".sprintf("%04o\n",$stat[2] & 07777).' ('.$self->mode2str($fn,$stat[2]).')';
}
sub handleUserOrGroupEntrySearch {
	my ($self) = @_;
	my $term = $$self{cgi}->param('term');
	my $result = [];
	if ($term) {
		if ($term=~/^group:(.*)/i) {
			$result = $self->searchGroupEntry($1, $main::EXTENSION_CONFIG{PosixAclManager}{listlimit}, $main::EXTENSION_CONFIG{PosixAclManager}{searchlimit});	
		} else {
			$result = $self->searchUserEntry($term=~/^user:(.*)/? $1: $term, $main::EXTENSION_CONFIG{PosixAclManager}{listlimit}, $main::EXTENSION_CONFIG{PosixAclManager}{searchlimit});
			push @{$result},@{$self->searchGroupEntry($term, $main::EXTENSION_CONFIG{PosixAclManager}{listlimit}, $main::EXTENSION_CONFIG{PosixAclManager}{searchlimit})}
				unless $term=~/^user:(.*)/;
		} 
	} else {
		push @{$result},@{$self->searchUserEntry($term, $main::EXTENSION_CONFIG{PosixAclManager}{listlimit}, $main::EXTENSION_CONFIG{PosixAclManager}{searchlimit})},
				@{$self->searchGroupEntry($term, $main::EXTENSION_CONFIG{PosixAclManager}{listlimit}, $main::EXTENSION_CONFIG{PosixAclManager}{searchlimit})};
	} 
	my $json = new JSON;
	main::printCompressedHeaderAndContent('200 OK','application/json', $json->encode({result=>$result}) , 'Cache-Control: no-cache, no-store');
	return 1;
}
sub searchUserEntry {
	my ($self, $term,$listlimit, $searchlimit) = @_;
	my @ret = ();
	my $counter = 0;
	setpwent();
	while (my @ent = getpwent()) {
		push @ret, "user:$ent[0]" if !$term || ($ent[0] =~ /^\Q$term\E/i || $ent[6] =~ /\Q$term\E/i);
		last if $searchlimit && $#ret+1 >= $searchlimit;
		$counter++;
		last if $listlimit && $counter >= $listlimit;
	}
	endpwent();
	return \@ret;
}
sub searchGroupEntry {
	my ($self, $term,$listlimit, $searchlimit) = @_;
	my @ret = ();
	my $counter = 0;
	setgrent();
	while (my @ent = getgrent()) {
		push @ret, "group:$ent[0]" if !$term || $ent[0] =~ /^\Q$term\E/i;
		last if $searchlimit && $#ret+1 >=$searchlimit;
		$counter++;
		last if $listlimit && $counter >= $listlimit;
	}
	endgrent();
	return \@ret;
}
sub normalizeFilename {
	my($self,$f) = @_;
	my $fn = $f;
	$fn=~s/\/$//;
	$fn=~s/\/[^\/]+\/\.\.$//;
	$fn=~s/(["\$\\])/\\$1/g;
	return $$self{backend}->resolveVirt($main::PATH_TRANSLATED.$fn);
}
sub getAclEntries {
	my($self, $fn) = @_;
	open(my $g, sprintf('%s -c -- "%s"|', $$self{getfacl}, $fn)) || return [];
	my @rights = ();
	while (<$g>) {
		chomp;
		next if /^\#/;
		next unless /^\S+:\S*:[rwx\-]+$/;
		my ($type, $uid, $permission) = split(/:/);
		push @rights, { type=>$type, uid=>$uid, permission=>$permission};
	}
	close($g);
	return \@rights;
}

1;