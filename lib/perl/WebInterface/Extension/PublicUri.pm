#########################################################################
# (C) ssystems, Harald Strack
# Written 2012 by Harald Strack <hstrack@ssystems.de>
# Modified 2013,2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
# SETUP:
# uribase - base URI for the public link (default: https://$ENV{HTTP_HOST}/public/)
# propname - property name for the share digest
# namespace - XML namespace for public uri property (default: {http://webdavcgi.sf.net/extension/PublicUri/})

package WebInterface::Extension::PublicUri;
use strict;

use WebInterface::Extension;
use Events::EventListener;

our @ISA = qw( WebInterface::Extension Events::EventListener );

use Digest::MD5 qw(md5 md5_hex md5_base64);

use JSON;

#URI CRUD
sub getPropertyName {
	my ($self) = @_;
	return $$self{namespace}.$$self{propname};
}
sub setPublicUri {
	my ( $self, $fn, $value ) = @_;
	$$self{db}->db_insertProperty($fn, $self->getPropertyName(), $value );
}

sub getPublicUri {
	my ( $self, $fn ) = @_;
	return $$self{db}->db_getProperty($fn, $self->getPropertyName());
}

sub unsetPublicUri {
	my ( $self, $fn ) = @_;
	return $$self{db}->db_removeProperty($fn, $self->getPropertyName());
}
sub getFileFromCode {
	my ( $self, $code ) = @_;
	my $fna = $$self{db}->db_getPropertyFnByValue( $$self{namespace}.$$self{propname}, $code );
	return $fna ? $$fna[0] : undef;
}

sub resolveFile {
	my ( $self, $file ) = @_;
	main::debug("PURI($main::PATH_TRANSLATED via POST");
	my $rfile = $$self{backend}->resolve($$self{backend}->resolveVirt("$main::PATH_TRANSLATED$file"));
	return $rfile;
}

sub init {
	my ( $self, $hookreg ) = @_;

	main::getEventChannel()->addEventListener('FILECOPIED', $self);
		
	$hookreg->register(['css','javascript','locales','templates','fileattr','fileactionpopup','posthandler','fileaction'], $self);

	$$self{namespace} = $self->config('namespace', '{http://webdavcgi.sf.net/extension/PublicUri/}');
	$$self{propname} = $self->config('propname', 'public_prop');
	$$self{uribase} = $self->config('uribase', 'https://'.$ENV{HTTP_HOST}.'/public/');  

	$$self{json} = new JSON();  
}
sub receiveEvent {
	my ( $self, $event, $data ) = @_;
	my $dst = $$data{destination};
	$dst=~s/\/$//;
	$$self{db}->db_deletePropertiesRecursiveByName($dst, $self->getPropertyName());
}
#Show icons and handle actions
sub handle {
	my ( $self, $hook, $config, $params ) = @_;

	my $ret = $self->SUPER::handle($hook, $config, $params);
	return $ret if $ret;

	
	if ( $hook eq 'posthandler' ) {

		#handle actions
		if ( $$self{cgi}->param('puri') ) {
			enablePuri($self);
		}
		elsif ( $$self{cgi}->param('depuri') ) {
			disablePuri($self);
		}
		elsif ( $$self{cgi}->param('spuri') ) {
			showPuri($self);
		}
		else {
			return 0;    #not handled
		}
		return 1;
	}
	elsif ( $hook eq 'fileaction' ) {
		return [ { action => 'puri', disabled => !$$self{backend}->isReadable( $$params{path} ), label => 'purifilesbutton', path  => $$params{path} },
			 { action => 'spuri', disabled => !$$self{backend}->isReadable( $$params{path} ), label => 'spurifilesbutton', path  => $$params{path} },
			 { action => 'depuri', disabled => !$$self{backend}->isReadable( $$params{path} ), label => 'depurifilesbutton', path  => $$params{path} },
		];
	}
	elsif ( $hook eq 'fileactionpopup') {
		return [ { action => 'puri', disabled => !$$self{backend}->isReadable( $$params{path} ), label => 'purifilesbutton', path  => $$params{path}, type=>'li' },
			 { action => 'spuri', disabled => !$$self{backend}->isReadable( $$params{path} ), label => 'spurifilesbutton', path  => $$params{path}, type=>'li' },
			 { action => 'depuri', disabled => !$$self{backend}->isReadable( $$params{path} ), label => 'depurifilesbutton', path  => $$params{path}, type=>'li' },
		];
	}
	elsif ( $hook eq 'fileattr' ) {
		my $prop = $self->getPublicUri( $$params{path} );
		my ($attr,$classes);
		if ( !defined($prop) ) {
			($classes, $attr) = ('unshared','no');
		}
		else {
			($classes, $attr) = ('shared', $prop);
		}
		return { "ext_classes"=>$classes, "ext_attributes" => sprintf('data-puri="%s"',$$self{cgi}->escapeHTML($attr)) }
	}
	elsif ( $hook eq 'templates' ) {
		return q@<div id="purifileconfirm">$tl(purifileconfirm)</div><div id="depurifileconfirm">$tl(depurifileconfirm)</div>@;
	}
	return 0;                                         #not handled
}

sub genUrlHash {
	my $self   = shift;
	my $f      = shift;
	my $seed   = time().int(rand(time())) . md5_hex($main::REMOTE_USER);
	my $digest = md5_hex( $f . $seed );
	return substr( $digest, 0, 16 );
}

#Publish URI and show message
sub enablePuri () {
	my ($self) = @_;
	my %jsondata = ();
	if ( $$self{cgi}->param('file') ) {
		my $file   = $self->resolveFile( $$self{cgi}->param('file') );
		my $digest;
		do {
			$digest= $self->genUrlHash($file);
		} until (!defined $self->getFileFromCode($digest));
		$digest = $self->config('public_prefix').$digest;
		main::debug( "Creating public URI: " . $digest );
		$self->setPublicUri( $file, $digest );
		my $url = $$self{cgi}->escapeHTML($$self{uribase}.$digest);
		$jsondata{message} = sprintf($self->tl('msg_enabledpuri'), $$self{cgi}->escapeHTML($$self{cgi}->param('file')), $url, $url);
		
	}
	else {
		$jsondata{error}= $self->tl('foldernothingerr');
	}
	
	main::printCompressedHeaderAndContent('200 OK','application/json',$$self{json}->encode(\%jsondata),'Cache-Control: no-cache, no-store');
	
	return 1;
}

sub showPuri () {
	my ($self) = @_;
	my %jsondata = ();
	if ( $$self{cgi}->param('file') ) {
		my $file   = $self->resolveFile( $$self{cgi}->param('file') );
		my $digest = $self->getPublicUri($file);
		main::debug( "Showing public URI: " . $digest );
		my $url = $$self{cgi}->escapeHTML($$self{uribase}.$digest);
		$jsondata{message} = sprintf($self->tl('msg_enabledpuri'), $$self{cgi}->escapeHTML($$self{cgi}->param('file')), $url, $url);
	}
	else {
		$jsondata{error} = $self->tl('foldernothingerr');

	}
	main::printCompressedHeaderAndContent('200 OK','application/json',$$self{json}->encode(\%jsondata),'Cache-Control: no-cache, no-store');
	return 1;
}

#Unpublish URI and show message
sub disablePuri () {
	my ($self) = @_;
	my %jsondata = ();
	if ( $$self{cgi}->param('file') ) {
		my $file = $self->resolveFile( $$self{cgi}->param('file') );
		main::debug( "Deleting public URI for file " . $file );
		$self->unsetPublicUri($file);
		$jsondata{message} = sprintf($self->tl('msg_disabledpuri'), $$self{cgi}->escapeHTML($$self{cgi}->param('file')));
	}
	else {
		$jsondata{error} = $self->tl('foldernothingerr');
	}
	main::printCompressedHeaderAndContent('200 OK','application/json',$$self{json}->encode(\%jsondata),'Cache-Control: no-cache, no-store');
	return 1;
}

1;