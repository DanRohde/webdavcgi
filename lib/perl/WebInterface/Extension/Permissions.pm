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
# disable_fileactionpopup - disables popup menu entry
# disable_apps - disables apps entry
package WebInterface::Extension::Permissions;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );

sub init { 
	my($self, $hookreg) = @_; 
	my @hooks = ('css','locales','javascript', 'gethandler', 'posthandler');
	push @hooks, 'fileactionpopup' unless $self->config('disable_fileactionpopup',0);
	push @hooks, 'apps' unless $self->config('disable_apps',0);
	
	$hookreg->register(\@hooks, $self);
}
sub handle { 
	my ($self, $hook, $config, $params) = @_;
	my $ret = $self->SUPER::handle($hook, $config, $params);
	return $ret if $ret;
	if ($hook eq 'fileactionpopup') {
		$ret = { action=>'permissions', label=>'mode', title=>'mode', accesskey=>'p', path=>$$params{path}, type=>'li', classes=>'sep', template=>$self->config('template','permissions')};
	} elsif ($hook eq 'apps') {
		$ret = $self->handleAppsHook($$self{cgi},'permissions sel-multi','mode','mode');
	} elsif ($hook eq 'gethandler') {
		if ($$self{cgi}->param('ajax') eq 'getPermissionsDialog') {
			my $content = $self->renderPermissionsDialog($main::PATH_TRANSLATED,$main::REQUEST_URI, $$self{cgi}->param('template') || $self->config('template','permissions'));
			main::printCompressedHeaderAndContent('200 OK','text/html',$content,'Cache-Control: no-cache, no-store');
			$ret  = 1;
		}
	} elsif ($hook eq 'posthandler') {
		my $ru = $main::REQUEST_URI;
		$ru=~s/\?[^\?]+$//;
		$ret=$self->changePermissions($ru);
	}
	return $ret;
}
sub checkPermAllowed {
	my ($self,$p,$r) = @_;
	my $perms;
	$perms = join("",@{$self->config('user',['r','w','x','s'])}) if $p eq 'u';
	$perms = join("",@{$self->config('group', ['r','w','x','s'])}) if $p eq 'g';
	$perms = join("",@{$self->config('others', ['r','w','x','t'])}) if $p eq 'o';
	return $perms =~ m/\Q$r\E/;
}
sub renderPermissionsDialog {
	my ($self, $fn, $ru, $tmplfile) = @_;
	my $content = $self->readTemplate($tmplfile);
	$content =~ s/\$disabled\((\w)(\w)\)/$self->checkPermAllowed($1,$2) ? '' : 'disabled="disabled"'/egs;	
	return $self->renderTemplate($fn, $ru, $content);
}
sub changePermissions {
	my($self) = @_;
	
	if ( $$self{cgi}->param('changeperm') ) {
		my ($msg,$msgparam, $errmsg);
		if ( $$self{cgi}->param('files[]') || $$self{cgi}->param('files') ) {
			my $perm_user = join("", @{ $self->config('user',['r','w','x','s']) });
			my $perm_group = join("", @{ $self->config('group',['r','w','x','s']) });
			my $perm_others = join("", @{ $self->config('others',['r','w','x','t']) });
			my $mode = 0000;
			foreach my $userperm ( $$self{cgi}->param('fp_user') ) {
				$mode = $mode | 0400  if $userperm eq 'r' && $perm_user=~/r/;
				$mode = $mode | 0200  if $userperm eq 'w' && $perm_user=~/w/;
				$mode = $mode | 0100  if $userperm eq 'x' && $perm_user=~/x/;
				$mode = $mode | 04000 if $userperm eq 's' && $perm_user=~/s/;
			}
			foreach my $grpperm ( $$self{cgi}->param('fp_group') ) {
				$mode = $mode | 0040  if $grpperm eq 'r' && $perm_group=~/r/;
				$mode = $mode | 0020  if $grpperm eq 'w' && $perm_group=~/w/;
				$mode = $mode | 0010  if $grpperm eq 'x' && $perm_group=~/x/;
				$mode = $mode | 02000 if $grpperm eq 's' && $perm_group=~/s/;
			}
			foreach my $operm ( $$self{cgi}->param('fp_others') ) {
				$mode = $mode | 0004  if $operm eq 'r' && $perm_others =~/r/;
				$mode = $mode | 0002  if $operm eq 'w' && $perm_others =~/w/;
				$mode = $mode | 0001  if $operm eq 'x' && $perm_others =~/x/;
				$mode = $mode | 01000 if $operm eq 't' && $perm_others =~/t/;
			}

			$msg = 'changeperm';
			$msgparam = sprintf( "p1=%04o", $mode );
			my @files = $$self{cgi}->param('files[]') ? $$self{cgi}->param('files[]') : $$self{cgi}->param('files') ;
			foreach my $file ( @files ) {
				$file = "" if $file eq '.';
				$$self{backend}->changeFilePermissions($main::PATH_TRANSLATED . $file, $mode, $$self{cgi}->param('fp_type'), $self->config('allow_changepermrecursive',1) && $$self{cgi}->param('fp_recursive'));
			}
		}
		else {
			$errmsg = 'chpermnothingerr';
		}
		my %jsondata = ();
		$jsondata{error} = sprintf($self->tl("msg_$errmsg"),$msgparam) if $errmsg;
		$jsondata{message} = sprintf($self->tl("msg_$msg"), $msgparam) if $msg;	
		my $json = new JSON();
		main::printCompressedHeaderAndContent('200 OK','application/json',$json->encode(\%jsondata),'Cache-Control: no-cache, no-store');
		return 1;
	}
	return 0;
}
1;