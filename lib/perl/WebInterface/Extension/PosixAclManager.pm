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
		}
	}
	return $ret; 
}
sub handleAclUpdate {
	my ($self) = @_;
	my $c = $$self{cgi};
	my $fn = $$self{backend}->resolveVirt($main::PATH_TRANSLATED);
	my $output = "";
	foreach my $param ($c->param()) {
		my $val = join('',$c->param($param));
		my $cmd = undef;
		if ($val=~/^[rwxM]+$/ && $param =~/^acl:(\S+:\S*)$/ ) {
			my $e = $1;
			if ($val eq 'M') {
				$cmd = 	sprintf('%s -x %s -- "%s"',$$self{setfacl}, $e, $fn);
			} else {
				$val=~s/M//g;
				$cmd = sprintf('%s -m %s:%s -- "%s"',$$self{setfacl},$e,$val, $fn);
			}
			
		} elsif ($param eq 'newacl' && $val=~/^\S+:\S*$/) {
			my $e = join("",$c->param('newaclpermissions'));
			if ($e && $e=~/^[rwx]+$/) {
				$cmd = sprintf('%s -m %s:%s -- "%s"',$$self{setfacl}, $val, $e, $fn);
			}			
		}
		if (defined $cmd) {
			#$cmd.=" 2>&1";
			print STDERR "$cmd\n";
			$output .=qx@$cmd 2>&1@;
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
	
	my @defaultpermissions = ('r','w','x');

	my $f = $c->param('files');
	$f='.' if $f eq '';
	$content .= $c->start_form(-method=>'POST',-action=>"$main::REQUEST_URI$f",-class=>'pacl form');
	$content .= $c->hidden(-name=>'filename', -value=>$f).$c->hidden(-name=>'action',-value=>'pacl_update');
	$content .= $c->start_table();
	
	$content.= $c->Tr($c->th({-colspan=>2},$c->escapeHTML($f)));
	#$content.= $c->Tr($c->th($self->tl('pacl_entry')).$c->th($self->tl('pacl_rights')));
	foreach my $e (@{$self->getAclEntries($f)}) {
		my $row = "";
		
		$row.=$c->td($$e{type}.':'.$$e{uid});
		my $permentry = "";
		my @perms = split(//, $$e{permission});
		$permentry.=$c->checkbox_group(-name=>'acl:'.$$e{type}.':'.$$e{uid}, -values=>\@defaultpermissions, -defaults=>\@perms);
		$permentry.=$c->hidden(-name=>'acl:'.$$e{type}.':'.$$e{uid}, -value=>'M');		
		$row.=$c->td($permentry);
		$content.=$c->Tr($row);	
	};
	$content.=$c->Tr($c->td($c->textfield(-name=>'newacl')),$c->td($c->checkbox_group(-name=>'newaclpermissions',-values=>\@defaultpermissions)));
	$content.=$c->Tr($c->td($c->submit(-name=>'pacl_update',-value=>$self->tl('pacl_update'))));#   .$c->td($c->submit(-name=>'pacl_cancel',-value=>$self->tl('cancel'))));
	$content .= $c->end_table();
	$content .= $c->end_form();
	
	main::printCompressedHeaderAndContent('200 OK','text/html',$c->div({-class=>'pacl manager',-title=>$self->tl('pacl')},$content), 'Cache-Control: no-cache, no-store');
	return 1;
}
sub getAclEntries {
	my($self, $fn) = @_;
	$fn = $$self{backend}->resolveVirt($fn);
	$fn=~s/\/$//;
	$fn=~s/\/[^\/]+\/\.\.$//;
	$fn=~s/(["\$\\])/\\$1/g;
	my $command = sprintf('%s -c -- "%s%s"|', $$self{getfacl}, $main::PATH_TRANSLATED, $fn);
	open(my $g, sprintf('%s -c -- "%s%s"|', $$self{getfacl}, $main::PATH_TRANSLATED, $fn)) || return [];
	my @rights = ();
	while (<$g>) {
		chomp;
		next if /^\#/;
		next unless /^\S+:\S*:[rwxts\-]+$/;
		my ($type, $uid, $permission) = split(/:/);
		push @rights, { type=>$type, uid=>$uid, permission=>$permission};
	}
	close($g);
	return \@rights;
}

1;