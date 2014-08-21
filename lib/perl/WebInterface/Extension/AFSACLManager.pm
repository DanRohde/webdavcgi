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
# allow_afsaclchanges - (dis)allows AFS ACL changes
# template - default template
# disable_fileactionpopup - disables popup menu entry
# disable_apps - disables apps entry
# ptscmd - path to the pts command (default: /usr/bin/pts)


package WebInterface::Extension::AFSACLManager;

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
	
	$$self{ptscmd} = $self->config('ptscmd', '/usr/bin/pts');
	
	$hookreg->register(\@hooks, $self);
}
sub handle { 
	my ($self, $hook, $config, $params) = @_;
	my $ret = $self->SUPER::handle($hook, $config, $params);
	return $ret if $ret;
	if ($hook eq 'fileactionpopup') {
		$ret = { action=>'afsaclmanager', label=>'afs', title=>'afs', path=>$$params{path}, type=>'li', classes=>'sel-noneorone sel-dir sep', template=>$self->config('template','afsaclmanager')};
	} elsif ($hook eq 'apps') {
		$ret = $self->handleAppsHook($$self{cgi},'afsaclmanager sel-noneorone sel-dir','afs','afs');
	} elsif ($hook eq 'gethandler') {
		my $ajax = $$self{cgi}->param('ajax');
		my $content;
		my $contenttype = 'text/html';
		if ($ajax eq 'getAFSACLManager') {
			$content = $self->renderAFSACLManager($main::PATH_TRANSLATED,$main::REQUEST_URI, $$self{cgi}->param('template') || $self->config('template','afsaclmanager'));
		} elsif ($ajax eq 'searchAFSUserOrGroupEntry') {
                        $content = $self->searchAFSUserOrGroupEntry($$self{cgi}->param('term'));
                        $contenttype='application/json';	

		}
		if ($content) {
			delete $CACHE{$self}{$main::PATH_TRANSLATED};
			main::printCompressedHeaderAndContent('200 OK',$contenttype,$content,'Cache-Control: no-cache, no-store', $self->getCookies());
			$ret = 1;
		}
	} elsif ($hook eq 'posthandler') {	
		if ($self->config('allow_afsaclchanges',1) && $$self{cgi}->param('saveafsacl')) {
			$self->doAFSSaveACL();
		}
	}
	return $ret;
}

sub execTemplateFunction {
	my ($self, $fn, $ru, $func, $param) = @_;
	my $content;
	$content = $self->renderAFSACLList($fn,$ru,1,$param) if $func eq 'afsnormalacllist';
	$content = $self->renderAFSACLList($fn,$ru,0,$param) if $func eq 'afsnegativeacllist';
	$content = $$self{backend}->_checkCallerAccess($fn, $param) if $func eq 'checkAFSCallerAccess';
	$content = $self->SUPER::execTemplateFunction($fn,$ru,$func,$param) unless defined $content;
	return $content;
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
sub searchAFSUserOrGroupEntry {
        my ($self, $term) = @_;
        my $result = [];
        #push @{$result}, @{$self->searchAFSUser($term,undef,20)} unless $term=~/:/;
        my @groups = grep(/\Q$term\E/i,@{$self->readAFSGroupList($main::PATH_TRANSLATED, $main::REQUEST_URI)});
        splice(@groups, 9 - $#$result) if ($#$result + $#groups>=10); 
        push @{$result}, @groups;
        my $json = new JSON();
        return $json->encode({result=>$result});
}
#sub searchAFSUser {
#       my ($self, $term,$listlimit, $searchlimit) = @_;
#       my @ret = ();
#       my $counter = 0;
#       setpwent();
#       while (my @ent = getpwent()) {
#               push @ret, $ent[0] if !$term || ($ent[0] =~ /^\Q$term\E/i || $ent[6] =~ /\Q$term\E/i);
#               last if $searchlimit && $#ret+1 >= $searchlimit;
#               $counter++;
#               last if $listlimit && $counter >= $listlimit;
#       }
#       endpwent();
#       return \@ret;
#}
sub renderAFSACLManager {
        my ($self, $fn, $ru, $tmplfile) = @_;
        my $content = "";
        if ($$self{backend}->_getCallerAccess($fn) eq "") {
                $content = $$self{cgi}->div({-title=>$self->tl('afs')},$self->tl('afsnorights'));
        } else {
                $content = $self->renderTemplate($fn,$ru,$self->readTemplate($tmplfile));
                my $stdvars = {
                        afsaclscurrentfolder => sprintf($self->tl('afsaclscurrentfolder'), 
                                                                                        $$self{cgi}->escapeHTML(uridecode($$self{backend}->basename($ru))), 
                                                                                        $$self{cgi}->escapeHTML(uridecode($ru))),
                };
                $content=~s/\$(\w+)/exists $$stdvars{$1} ? $$stdvars{$1} : ''/egs;
        }
        return $content;
}
sub readAFSAcls {
	my ($self, $fn, $ru) = @_;
	return $CACHE{$self}{$fn}{afsacls} if exists $CACHE{$self}{$fn}{afsacls};

	$fn=$$self{backend}->resolveVirt($fn);
	$fn=~s/(["\$\\])/\\$1/g;
	open(my $afs, sprintf("%s listacl \"%s\"|", $main::BACKEND_CONFIG{$main::BACKEND}{fscmd}, $fn)) or die("cannot execute $main::BACKEND_CONFIG{$main::BACKEND}{fscmd} list \"$fn\"");
	my @lines = <$afs>;
	close($afs);

	shift @lines; # skip first line

	my @entries;
	my $ispositive = 1;
	foreach my $line (@lines) {
		chomp($line);
		$line=~s/^\s+//;
		next if $line=~ /^\s*$/; # skip empty lines
		if ($line=~/^(Normal|Negative) rights:/) {
			$ispositive = 0 if $line=~/^Negative/;
		} else {
			my ($user, $right) = split(/\s+/, $line);
			push @entries, { user=> $user, right=> $right, ispositive=> $ispositive };
		}
	}

	$CACHE{$self}{$fn}{afsacls} = \@entries;
	return \@entries;
}
sub renderAFSAclEntries {
	my ($self, $entries, $positive, $tmpl, $disabled) = @_;
	my $content = "";
	my $prohiregex = '^('.join('|',map { $_ ? $_ : '__undef__'} @{ $self->config('prohibit_afs_acl_changes_for',['^$']) }).')$';
	foreach my $entry (sort { $$a{user} cmp $$b{user} || $$b{right} cmp $$a{right} } @{$entries}) {
		next if $$entry{ispositive} != $positive;	
		my $t = $tmpl;
		$t=~s/\$entry/$$entry{user}/sg;
		$t=~s/\$checked\((\w)\)/$$entry{right}=~m@$1@?'checked="checked"':""/egs;
		$t=~s/\$readonly/$$entry{user}=~m@$prohiregex@ ? 'readonly="readonly"' : ""/egs;
		$t=~s/\$disabled/$self->config('allow_afsaclchanges',1) && !$disabled ? '' : 'disabled="disabled"'/egs;
		$content.=$t;
	}
	return $content;
}
sub renderAFSACLList {
	my ($self, $fn, $ru, $positive, $tmplfile) = @_;
	return $self->renderTemplate($fn,$ru, $self->renderAFSAclEntries($self->readAFSAcls($fn,$ru), $positive, $self->readTemplate($tmplfile), !$$self{backend}->_checkCallerAccess($fn,"a")));
}
sub isValidAFSACL       { return $_[1] =~ /^[rlidwka]+$/; }
sub isValidAFSGroupName { return $_[1] =~ /^[a-z0-9\_\@\:]+$/i; }
sub isValidAFSUserName  { return $_[1] =~ /^[a-z0-9\_\@]+$/i; }

sub buildAFSFSSETACLParam {
	my ($self) = @_;
	my ( $pacls, $nacls ) = ( "", "" );

	foreach my $param ( $$self{cgi}->param() ) {
		my $value = join( "", $$self{cgi}->param($param) );
		if ( $param eq "up" ) {
			$pacls .=
			  sprintf( "\"%s\" \"%s\" ", $$self{cgi}->param("up_add"), $value )
			  if ( $self->isValidAFSUserName( $$self{cgi}->param("up_add") )
				|| $self->isValidAFSGroupName( $$self{cgi}->param("up_add") ) )
			  && $self->isValidAFSACL($value);
		}
		elsif ( $param eq "un" ) {
			$nacls .=
			  sprintf( "\"%s\" \"%s\" ", $$self{cgi}->param("un_add"), $value )
			  if ( $self->isValidAFSUserName( $$self{cgi}->param("un_add") )
				|| $self->isValidAFSGroupName( $$self{cgi}->param("un_add") ) )
			  && $self->isValidAFSACL($value);
		}
		elsif ( $param =~ /^up\[([^\]]+)\]$/ ) {
			$pacls .= sprintf( "\"%s\" \"%s\" ", $1, $value )
			  if ( $self->isValidAFSUserName($1)
				|| $self->isValidAFSGroupName($1) )
			  && $self->isValidAFSACL($value);
		}
		elsif ( $param =~ /^un\[([^\]]+)\]$/ ) {
			$nacls .= sprintf( "\"%s\" \"%s\" ", $1, $value )
			  if ( $self->isValidAFSUserName($1)
				|| $self->isValidAFSGroupName($1) )
			  && $self->isValidAFSACL($value);
		}
	}
	return ( $pacls, $nacls );
}

sub doAFSFSSETACLCmd {
	my ( $self, $fn, $pacls, $nacls ) = @_;
	my ( $msg, $errmsg, $msgparam );
	my $output = "";
	if ( $pacls ne "" ) {
		my $cmd;
		$fn =~ s/(["\$\\])/\\$1/g;
		$cmd = sprintf( '%s setacl -dir "%s" -acl %s -clear 2>&1',
			$main::BACKEND_CONFIG{$main::BACKEND}{fscmd}, $$self{backend}->resolveVirt($fn), $pacls );
		$output = qx@$cmd@;
		if ( $nacls ne "" ) {
			$cmd = sprintf( '%s setacl -dir "%s" -acl %s -negative 2>&1',
				$main::BACKEND_CONFIG{$main::BACKEND}{fscmd}, $$self{backend}->resolveVirt($fn), $nacls );
			$output .= qx@$cmd@;
		}
	}
	else { $output = $self->tl('empty normal rights'); }
	if ( $output eq "" ) {
		$msg      = 'afsaclchanged';
		$msgparam = [ $$self{cgi}->escapeHTML($pacls), $$self{cgi}->escapeHTML($nacls) ];
	}
	else {
		$errmsg   = 'afsaclnotchanged';
		$msgparam = [ $self->formatHTML($$self{cgi}->escapeHTML($output)) ];
	}
	return ( $msg, $errmsg, $msgparam );
}
sub formatHTML {
	my ($self,$text) = @_;
	$text=~s/\r?\n/<br\/>/sg;
	return $text;
}
sub doAFSFSSETAclCmdRecursive {
	my ( $self, $fn, $pacls, $nacls ) = @_;
	$fn.='/' if $fn!~/\/$/ && $$self{backend}->isDir($fn);
	my ($msg, $errmsg, $msgparam); 
	foreach my $f ( @{$$self{backend}->readDir($fn)}) {
		my $nf = "$fn$f";
		if ($$self{backend}->isDir($nf) && !$$self{backend}->isLink($nf) && $$self{backend}->_checkCallerAccess($nf,"a","a")) {
			$nf.='/';
			($msg, $errmsg, $msgparam) = $self->doAFSFSSETACLCmd($nf, $pacls, $nacls);
			($msg, $errmsg, $msgparam) = $self->doAFSFSSETAclCmdRecursive($nf, $pacls, $nacls);
		}
	}
	return ($msg, $errmsg, $msgparam);
}

sub doAFSSaveACL {
	my ( $self, $redirtarget ) = @_;
	my ( $pacls, $nacls ) = ( "", "" );
	my ( $msg, $errmsg, $msgparam );

	( $pacls, $nacls ) = $self->buildAFSFSSETACLParam();
	( $msg, $errmsg, $msgparam ) = $self->doAFSFSSETACLCmd( $main::PATH_TRANSLATED, $pacls, $nacls );
	
	$self->doAFSFSSETAclCmdRecursive( $main::PATH_TRANSLATED, $pacls, $nacls) if ($$self{cgi}->param("setafsaclrecursive"));
	
	my %jsondata = ();
	$jsondata{error} = sprintf($self->tl('msg_'.$errmsg), $msgparam ? @{ $msgparam } : '') if $errmsg;
	$jsondata{message} = sprintf($self->tl('msg_'.$msg), $msgparam ? @{ $msgparam } : '') if $msg;
	my $json = new JSON();
	main::printCompressedHeaderAndContent('200 OK','application/json', $json->encode(\%jsondata),'Cache-Control: no-cache, no-store', $self->getCookies());
}
sub uridecode {
	my ($txt) = @_;
	$txt=~s/\%([a-f0-9]{2})/chr(hex($1))/eigs;
	return $txt;
}
1;