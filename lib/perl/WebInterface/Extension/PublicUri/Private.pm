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

package WebInterface::Extension::PublicUri::Private;
use strict;

use WebInterface::Extension::PublicUri::Common;
use Events::EventListener;

our @ISA = qw( WebInterface::Extension::PublicUri::Common Events::EventListener );


use JSON;

#URI CRUD

sub setPublicUri {
	my ( $self, $fn, $code, $seed ) = @_;
	$$self{db}->db_insertProperty($fn, $self->getPropertyName(), $code );
	$$self{db}->db_insertProperty($fn, $self->getSeedName(), $seed);
}

sub getPublicUri {
	my ( $self, $fn ) = @_;
	return $$self{db}->db_getProperty($fn, $self->getPropertyName());
}
sub unsetPublicUri {
	my ( $self, $fn ) = @_;
	return $$self{db}->db_removeProperty($fn, $self->getPropertyName()) && $$self{db}->db_removeProperty($fn, $self->getSeedName());
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
		
	$hookreg->register(['css','javascript','locales','templates','fileattr','fileactionpopup','posthandler','fileaction','fileactionpopupnew'], $self);

	$self->initDefaults();
	
	$$self{json} = new JSON();  
}
sub receiveEvent {
	my ( $self, $event, $data ) = @_;
	my $dst = $$data{destination};
	$dst=~s/\/$//;
	$$self{db}->db_deletePropertiesRecursiveByName($dst, $self->getPropertyName());
	$$self{db}->db_deletePropertiesRecursiveByName($dst, $self->getSeedName());
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
	elsif ( $hook eq 'fileactionpopupnew') {
		return { action => 'puri', disabled => !$$self{backend}->isReadable( $$params{path} ), label => 'purifilesbutton', path  => $$params{path}, type=>'li' };
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

#Publish URI and show message
sub enablePuri () {
	my ($self) = @_;
	my %jsondata = ();
	if ( $$self{cgi}->param('file') ) {
		my $file   = $self->resolveFile( $$self{cgi}->param('file') );
		my $digest = $self->getPublicUri($file);
		my $seed = $self->getSeed($file);
		if (!$digest || $self->isPublicUri($file, $digest, $seed)) {
			do {
				($digest, $seed) = $self->genUrlHash($file);
			} until (!defined $self->getFileFromCode($$self{prefix}.$digest));
			main::debug( "Creating public URI: " . $digest );
			$self->unsetPublicUri($file);
			$self->setPublicUri( $file, $digest, $seed );
		}
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
		my $seed = $self->getSeed($file);
		main::debug( "Showing public URI: " . $digest );
		my $url = $$self{cgi}->escapeHTML($$self{uribase}.$digest);
		if ($digest && $seed && $self->isPublicUri($file, $digest, $seed)) {
			$jsondata{message} = sprintf($self->tl('msg_enabledpuri'), $$self{cgi}->escapeHTML($$self{cgi}->param('file')), $url, $url);
		} else {
			$self->disablePuri();
		}
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