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
#
# SETUP:
# disallow_afsgroupchanges - disallows afs group changes 
# ptscmd - sets the AFS pts command (default: /usr/bin/pts)
# disable_fileactionpopup - disables fileaction entry in popup menu
# disable_apps - disables sidebar menu entry
# template - sets the template (default: afsgroupmanager)

package WebInterface::Extension::AFSGroupManager;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );

use JSON;

use vars qw( %CACHE );
sub init { 
	my($self, $hookreg) = @_; 
	my @hooks = ('css','locales','javascript', 'gethandler', 'posthandler');
	push @hooks, 'fileactionpopup' unless $self->config('disable_fileactionpopup',0);
	push @hooks, 'apps' unless $self->config('disable_apps',0);
	
	$$self{ptscmd} = $self->config('ptscmd','/usr/bin/pts');
	
	$hookreg->register(\@hooks, $self);
}
sub handle { 
	my ($self, $hook, $config, $params) = @_;
	my $ret = $self->SUPER::handle($hook, $config, $params);
	return $ret if $ret;
	if ($hook eq 'fileactionpopup') {
		$ret = { action=>'afsgroupmngr',  classes=>'listaction', label=>'afsgroup', title=>'afsgroup', path=>$$params{path}, type=>'li', template=>$self->config('template','afsgroupmanager')};
	} elsif ($hook eq 'apps') {
		$ret = $self->handleAppsHook($$self{cgi},'afsgroupmngr','afsgroup','afsgroup');
	} elsif ($hook eq 'gethandler') {
		if ($$self{cgi}->param('ajax') eq 'getAFSGroupManager') {
			my $content = $self->renderAFSGroupManager($main::PATH_TRANSLATED,$main::REQUEST_URI, $$self{cgi}->param('template') || $self->config('template','afsgroupmanager'));
			main::printCompressedHeaderAndContent('200 OK','text/html', $content,'Cache-Control: no-cache, no-store');	
			delete $CACHE{$self}{$main::PATH_TRANSLATED};
			$ret = 1;
		} 
	} elsif ($hook eq 'posthandler') {
		$ret = $self->doAFSGroupActions() if $self->checkCgiParamList('afschgrp', 'afscreatenewgrp', 'afsdeletegrp', 'afsrenamegrp', 'afsaddusr', 'afsremoveusr');
	}
	return $ret;
}
sub checkCgiParamList {
	my ($self, @params ) = @_;
	foreach my $param (@params) {
		return 1 if $$self{cgi}->param($param);
	}
	return 0;
}
sub readAFSGroupList {
	my ($self, $fn, $ru) = @_;
	return $CACHE{$self}{$fn}{afsgrouplist} if exists $CACHE{$self}{$fn}{afsgrouplist};
	my @groups = split(/\r?\n\s*?/, qx@$$self{ptscmd} listowned $main::REMOTE_USER@);
	shift @groups; # remove comment
	s/(^\s+|[\s\r\n]+$)//g foreach (@groups);
	@groups = sort @groups;
	$CACHE{$self}{$fn}{afsgrouplist} = \@groups;
	return \@groups;
}
sub renderAFSGroupList {
	my ($self, $fn, $ru, $tmplfile) = @_;
	my $content ="";
	my $tmpl = $self->renderTemplate($fn,$ru,$self->readTemplate($tmplfile));
	foreach my $group (@{$self->readAFSGroupList($fn,$ru)}) {
		my $t = $tmpl;
		$t=~s/\$afsgroupname/$group/g;
		$content.=$t;
	}
	return $content;
}
sub readAFSMembers {
	my ($self, $grp) = @_;
	return [] unless $grp;
	my @users = split(/\r?\n/, qx@$$self{ptscmd} members '$grp'@);
	shift @users; # remove comment
	s/^\s+//g foreach (@users);
	@users = sort @users;
	chomp @users;
	return \@users;
}
sub renderAFSMemberList {
	my ($self, $fn, $ru, $tmplfile) = @_;
	my $content = "";
	my $tmpl = $self->readTemplate($tmplfile);
	my $afsgrp = $$self{cgi}->param('afsgrp');
	foreach my $user (@{$self->readAFSMembers($afsgrp)}) {
		my $t = $tmpl;
		$t=~s/\$afsmember/$user/sg;
		$t=~s/\$afsgroupname/$afsgrp/sg;
		$content.=$t;
	}
	return $self->renderTemplate($fn,$ru,$content);
}
sub execTemplateFunction {
	my ($self, $fn, $ru, $func, $param) = @_;
	my $content;
	$content = $self->renderAFSGroupList($fn,$ru,$param) if $func eq 'afsgrouplist';
	$content = $self->renderAFSMemberList($fn,$ru,$param) if $func eq 'afsmemberlist';
	$content = $self->SUPER::execTemplateFunction($fn,$ru,$func,$param) unless defined $content;
	return $content;
}
sub renderAFSGroupManager {
	my ($self, $fn, $ru, $tmplfile) = @_;
	my $content = $self->renderTemplate($fn,$ru,$self->readTemplate($tmplfile));
	my $stdvars = {
		afsgroupeditorhead => sprintf($self->tl('afsgroups'), $$self{cgi}->escapeHTML($main::REMOTE_USER)),
		afsmembereditorhead=> $$self{cgi}->param('afsgrp') ? sprintf($self->tl('afsgrpusers'), $$self{cgi}->escapeHTML($$self{cgi}->param('afsgrp'))): "",
		user => $main::REMOTE_USER,
	};
	$content=~s/\$(\w+)/exists $$stdvars{$1} ? $$stdvars{$1} : "\$${1}"/egs;
	return $content;
}
sub isValidAFSGroupName { return $_[1] =~ /^[a-z0-9\_\@\:]+$/i; }
sub isValidAFSUserName  { return $_[1] =~ /^[a-z0-9\_\@]+$/i; }

sub doAFSGroupActions {
	my ( $self ) = @_;
	my ( $msg, $errmsg, $msgparam );
	my $grp = $$self{cgi}->param('afsgrp') || '';
	my $output;
	if ( $$self{cgi}->param('afschgrp') ) {
		if ( $$self{cgi}->param('afsgrp') ) {
			$msg      = '';
			$msgparam = [  $$self{cgi}->param('afsgrp') ] if $self->isValidAFSGroupName( $$self{cgi}->param('afsgrp') );
		}
		else {
			$errmsg = 'afsgrpnothingsel';
		}
	}
	elsif ( $self->config('disallow_afsgroupchanges') ) {
		## do nothing
	}
	elsif ( $$self{cgi}->param('afsdeletegrp') ) {
		if ( $self->isValidAFSGroupName($grp) ) {
			$output = qx@$$self{ptscmd} delete "$grp" 2>&1@;
			if ( $output eq "" ) {
				$msg      = 'afsgrpdeleted';
				$msgparam =  [ $grp ];
			}
			else {
				$errmsg   = 'afsgrpdeletefailed';
				$msgparam = [ $grp, $output ];
			}
		}
		else {
			$errmsg = 'afsgrpnothingsel';
		}
	}
	elsif ( $$self{cgi}->param('afscreatenewgrp') ) {
		$grp = $$self{cgi}->param('afsnewgrp');
		$grp =~ s/^\s+//;
		$grp =~ s/\s+$//;
		if ( $self->isValidAFSGroupName($grp) ) {
			$output = qx@$$self{ptscmd} creategroup $grp 2>&1@;
			if ( $output eq "" || $output =~ /^group \Q$grp\E has id/i ) {
				$msg      = 'afsgrpcreated';
				$msgparam = [ $grp ];
			}
			else {
				$errmsg   = 'afsgrpcreatefailed';
				$msgparam = [ $grp, $output ];
			}
		}
		else {
			$errmsg = 'afsgrpnogroupnamegiven';
		}
	}
	elsif ( $$self{cgi}->param('afsrenamegrp') ) {
		my $ngrp = $$self{cgi}->param('afsnewgrpname') || '';
		if ( $self->isValidAFSGroupName($grp) ) {
			if ( $self->isValidAFSGroupName($ngrp) ) {
				$output = qx@$$self{ptscmd} rename -oldname \"$grp\" -newname \"$ngrp\" 2>&1@;
				if ( $output eq "" ) {
					$msg      = 'afsgrprenamed';
					$msgparam = [ $grp, $ngrp ];
				}
				else {
					$errmsg   = 'afsgrprenamefailed';
					$msgparam = [ $grp, $ngrp, $output ];
				}
			}
			else {
				$errmsg   = 'afsnonewgroupnamegiven';
				$msgparam =  [ $grp ];
			}
		}
		else {
			$errmsg   = 'afsgrpnothingsel';
			$msgparam = [ $ngrp ];
		}
	}
	elsif ( $$self{cgi}->param('afsremoveusr') ) {
		$grp = $$self{cgi}->param('afsselgrp') || '';
		if ( $self->isValidAFSGroupName($grp) ) {
			my @users;
			my @afsusr = $$self{cgi}->param('afsusr[]') ? $$self{cgi}->param('afsusr[]') :  $$self{cgi}->param('afsusr');
			foreach (@afsusr) {
				push @users, $_
				  if $self->isValidAFSUserName($_)
				  || $self->isValidAFSGroupName($_);
			}
			if ( $#users > -1 ) {
				my $userstxt = '"' . join( '" "', @users ) . '"';
				$output = qx@$$self{ptscmd} removeuser -user $userstxt -group \"$grp\" 2>&1@;
				if ( $output eq "" ) {
					$msg      = 'afsuserremoved';
					$msgparam =  [ join( ', ', @users ) , $grp ];
				}
				else {
					$errmsg   = 'afsusrremovefailed';
					$msgparam =  [ join( ', ', @users ), $grp, $output ];
				}
			}
			else {
				$errmsg   = 'afsusrnothingsel';
				$msgparam = [ $grp ];
			}
		}
		else {
			$errmsg = 'afsgrpnothingsel';
		}
	}
	elsif ( $$self{cgi}->param('afsaddusr') ) {
		$grp = $$self{cgi}->param('afsselgrp') || '';
		if ( $self->isValidAFSGroupName($grp) ) {
			my @users;
			foreach ( split( /\s+/, $$self{cgi}->param('afsaddusers') ) ) {
				push @users, $_
				  if $self->isValidAFSUserName($_)
				  || $self->isValidAFSGroupName($_);
			}
			if ( $#users > -1 ) {
				my $userstxt = '"' . join( '" "', @users ) . '"';
				$output = qx@$$self{ptscmd} adduser -user $userstxt -group "$grp" 2>&1@;
				if ( $output eq "" ) {
					$msg      = 'afsuseradded';
					$msgparam = [ join( ', ', @users ), $grp ];
				}
				else {
					$errmsg   = 'afsadduserfailed';
					$msgparam = [ $$self{cgi}->param('afsaddusers'), $grp, $output ];
				}

			}
			else {
				$errmsg   = 'afsnousersgiven';
				$msgparam = [ $grp ];
			}
		}
		else {
			$errmsg = 'afsgrpnothingsel';
		}
	}

	my %jsondata = ();
	my @params = $msgparam ? map { $$self{cgi}->escapeHTML($_) } @{ $msgparam } : (); 
	$jsondata{error} = sprintf($self->tl("msg_$errmsg"), @params) if $errmsg;
	$jsondata{message} = sprintf($self->tl("msg_$msg"), @params ) if $msg;	
	my $json = new JSON();
	main::printCompressedHeaderAndContent('200 OK','application/json',$json->encode(\%jsondata),'Cache-Control: no-cache, no-store');
	return 1;
}	
1;