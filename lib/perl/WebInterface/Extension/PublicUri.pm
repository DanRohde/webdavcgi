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

package WebInterface::Extension::PublicUri;
use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension );

use Digest::MD5 qw(md5 md5_hex md5_base64);

use JSON;

#URI CRUD
sub setPublicUri {
	my ( $self, $fn, $value ) = @_;
	$$self{db}->db_insertProperty($self->config('public_prop_prefix') . $fn, $self->config('public_prop'), $value );
}

sub getPublicUri {
	my ( $self, $fn ) = @_;
	return $$self{db}->db_getProperty($self->config('public_prop_prefix') . $fn, $self->config('public_prop') );
}

sub unsetPublicUri {
	my ( $self, $fn ) = @_;
	return $$self{db}->db_removeProperty( $self->config('public_prop_prefix') . $fn, $self->config('public_prop') );
}

sub resolveFile {
	my ( $self, $file ) = @_;
	main::logger("PURI($main::PATH_TRANSLATED via POST");
	my $rfile = $$self{backend}->resolve($$self{backend}->resolveVirt("$main::PATH_TRANSLATED$file"));
	return $rfile;
}

sub init {
	my ( $self, $hookreg ) = @_;
		
	$hookreg->register(['css','javascript','locales','templates','fileattr','fileactionpopup','posthandler','fileaction'], $self);

	$main::EXTENSION_CONFIG{PublicUri}{public_prop} =
	  '{http://webdavcgi.sf.net/extension/PublicUri/'.$main::REMOTE_USER.'}publicurl'
	  unless defined $main::EXTENSION_CONFIG{PublicUri}{public_prop};
	$main::EXTENSION_CONFIG{PublicUri}{public_prop_prefix} = 'PublicUri:'
	  unless defined $main::EXTENSION_CONFIG{PublicUri}{public_prop_prefix};  
	  
	$$self{json} = new JSON();  
}

sub handleZipDownloadRequest {
	my ($self) = @_;
	my $redirtarget = $main::REQUEST_URI;
	$redirtarget =~ s/\?.*$//;    # remove query
	my $handled = 1;
	if ( $main::ALLOW_ZIP_DOWNLOAD && defined $$self{cgi}->param('zip') ) {
		main::logger("Handling ZIP download.");
		$self->getFunctions()->handleZipDownload($redirtarget);
	}
	else {
		$handled = 0;
	}
	return $handled;
}

#Show icons and handle actions
sub handle {
	my ( $self, $hook, $config, $params ) = @_;

	my $ret = $self->SUPER::handle($hook, $config, $params);
	return $ret if $ret;

	if ( $hook eq 'posthandler' ) {

		#handle actions
		if ( $self->handleZipDownloadRequest() ) {

		}
		elsif ( $$self{cgi}->param('puri') ) {
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
	my $seed   = time() . md5_hex($main::REMOTE_USER);
	my $digest = md5_hex( $f . $seed );
	return substr( $digest, 0, 16 );
}

#Publish URI and show message
sub enablePuri () {
	my ($self) = @_;
	my %jsondata = ();
	if ( $$self{cgi}->param('file') ) {
		my $file   = $self->resolveFile( $$self{cgi}->param('file') );
		my $digest = $self->genUrlHash($file);
		$digest = $self->config('public_prefix').$digest;
		main::logger( "Creating public URI: " . $digest );
		$self->setPublicUri( $file, $digest );
		
		$jsondata{message} = sprintf($self->tl('msg_enabledpuri'), $$self{cgi}->param('file'), $self->config('public_url_base').$digest, $self->config('public_url_base').$digest);
		
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
		main::logger( "Showing public URI: " . $digest );
		$jsondata{message} = sprintf($self->tl('msg_enabledpuri'), $$self{cgi}->param('file'), $self->config('public_url_base').$digest, $self->config('public_url_base').$digest);
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
		main::logger( "Deleting public URI for file " . $file );
		$jsondata{message} = sprintf($self->tl('msg_disabledpuri'), $$self{cgi}->param('file'));
	}
	else {
		$jsondata{error} = $self->tl('foldernothingerr');
	}
	main::printCompressedHeaderAndContent('200 OK','application/json',$$self{json}->encode(\%jsondata),'Cache-Control: no-cache, no-store');
	return 1;
}

1;