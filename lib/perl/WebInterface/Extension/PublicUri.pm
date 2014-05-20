#########################################################################
# (C) ssystems, Harald Strack
# Written 2012 by Harald Strack <hstrack@ssystems.de>
# Modified 2013 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

#CONSTRUCTOR
sub new {
	my $this  = shift;
	my $class = ref($this) || $this;
	my $self  = {};
	bless $self, $class;
	$self->init(shift);
	return $self;
}

#URI CRUD
sub setPublicUri {
	my ( $self, $fn, $value ) = @_;
	$$self{db}->db_insertProperty(
		$main::EXTENSION_CONFIG{PublicUri}{public_prop_prefix} . $fn,
		$main::EXTENSION_CONFIG{PublicUri}{public_prop}, $value );
}

sub getPublicUri {
	my ( $self, $fn ) = @_;
	return $$self{db}->db_getProperty(
		$main::EXTENSION_CONFIG{PublicUri}{public_prop_prefix} . $fn,
		$main::EXTENSION_CONFIG{PublicUri}{public_prop}
	);
}

sub unsetPublicUri {
	my ( $self, $fn ) = @_;
	return $$self{db}->db_removeProperty(
		$main::EXTENSION_CONFIG{PublicUri}{public_prop_prefix} . $fn,
		$main::EXTENSION_CONFIG{PublicUri}{public_prop}
	);
}

sub resolveFile {
	my ( $self, $file ) = @_;
	main::logger("PURI($main::PATH_TRANSLATED via POST");
	my $rfile = $$self{backend}->resolve("$main::PATH_TRANSLATED$file");
	return $rfile;
}

sub init {
	my ( $self, $hookreg ) = @_;
	$hookreg->register( 'posthandler', $self );
	$hookreg->register( 'fileaction',  $self );
	$hookreg->register( 'fileprop',    $self );

	## dro: added some handlers:
	$hookreg->register(['css','javascript','filelistentrydata','locales','templates','gethandler'], $self);

	## dro: define some defaults:
	$main::EXTENSION_CONFIG{PublicUri}{public_prop} =
	  '{http://webdavcgi.org/webdav/extension}publicurl'
	  unless defined $main::EXTENSION_CONFIG{PublicUri}{public_prop};
	$main::EXTENSION_CONFIG{PublicUri}{public_prop_prefix} = 'PublicUri:'
	  unless defined $main::EXTENSION_CONFIG{PublicUri}{public_prop_prefix};
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

	$$self{cgi}     = $$config{cgi};
	$$self{db}      = $$config{db};
	$$self{backend} = $$config{backend};
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

		#the fileaction is not handled per file in this view
		#thus we use the the fileprop aproach
		if ( $main::VIEW eq "simple" ) {
			##return {};
		}

		#show icon
		my $prop = $self->getPublicUri( $$params{path} );
		my $icon = 'depuri';
		my $txt  = "depurifilesbutton";
		if ( !defined($prop) ) {
			$icon = 'extension puri';
			$txt  = 'purifilesbutton';
		}

		return {
			action   => $icon,
			disabled =>
			  !$$self{backend}->isReadable( $$params{path} ),
			label => $txt,
			path  => $$params{path}
		};
	}
	elsif ( $hook eq 'fileprop' ) {
		my $prop = $self->getPublicUri( $$params{path} );

		if ( !defined($prop) ) {
			return { 'puri' => "no" };
		}
		else {
			return { 'puri' => $prop };
		}
	}
	elsif ( $hook eq 'css' ) {
		return $self->handleCssHook('PublicUri','htdocs/style.css');
	}
	elsif ( $hook eq 'javascript' ) {
		return $self->handleJavascriptHook('PublicUri','htdocs/script.js');
	}
	elsif ( $hook eq 'filelistentrydata' ) {
		return q@data-puri="$puri"@;
	}
	elsif ( $hook eq 'locales' ) {
		return $self->handleLocalesHook('PublicUri');
	}
	elsif ( $hook eq 'templates' ) {
		return
q@<div id="purifileconfirm">$tl(purifileconfirm)</div><div id="depurifileconfirm">$tl(depurifileconfirm)</div>@;
	}
	elsif ( $hook eq 'gethandler' ) {
		## TODO: get handler for css/javascript file
		if ( $main::REQUEST_URI =~
			/__PublicUri__\/(script\.js|style\.css)/
			|| $main::REQUEST_URI =~
			/__PublicUri__\/(images\/[^\/]+)/ )
		{
			my $fn =
			  $main::INSTALL_BASE
			  . "lib/perl/WebInterface/Extension/PublicUri/htdocs/$1";
			if ( open( F, "<$fn" ) ) {
				main::printLocalFileHeader($fn);
				binmode(STDOUT);
				while (
					read( F, my $buffer,
						$main::BUFSIZE || 1048576 ) > 0
				  )
				{
					print $buffer;
				}
				close(F);
				return 1;
			}
		}
	}
	return 0;                                         #not handled
}

sub createMsgQuery {
	my ( $self, $msg, $msgparam, $errmsg, $errmsgparam, $prefix ) = @_;
	$prefix = '' unless defined $prefix;
	my $query = "";
	$query .= ";${prefix}msg=$msg"       if defined $msg;
	$query .= ";$msgparam"               if $msgparam;
	$query .= ";${prefix}errmsg=$errmsg" if defined $errmsg;
	$query .= ";$errmsgparam"            if defined $errmsg && $errmsgparam;
	return "?t=" . time() . $query;
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
	my ( $msg, $errmsg, $msgparam );
	my $redirtarget = $main::REQUEST_URI;
	$redirtarget =~ s/\?.*$//;    # remove query
	if ( $$self{cgi}->param('file') ) {
		my $file   = $self->resolveFile( $$self{cgi}->param('file') );
		my $digest = $self->genUrlHash($file);
		$digest = "$main::PUBLIC_PREFIX$digest";
		main::logger( "Creating public URI: " . $digest );
		$self->setPublicUri( $file, $digest );
		$msg      = 'enabledpuri';
		$msgparam = 'p1=' . $$self{cgi}->param('file');
		$msgparam .= ';p2=' . $main::PUBLIC_URL_BASE . $digest;
		$msgparam .= ';p3=' . $main::PUBLIC_URL_BASE . $digest;
	}
	else {
		$errmsg = 'foldernothingerr';

	}
	print $$self{cgi}->redirect( $redirtarget
		  . $self->createMsgQuery( $msg, $msgparam, $errmsg, $msgparam )
	);

	return 1;
}

sub showPuri () {
	my ($self) = @_;
	my ( $msg, $errmsg, $msgparam );
	my $redirtarget = $main::REQUEST_URI;
	$redirtarget =~ s/\?.*$//;    # remove query
	if ( $$self{cgi}->param('file') ) {
		my $file   = $self->resolveFile( $$self{cgi}->param('file') );
		my $digest = $self->getPublicUri($file);
		main::logger( "Showing public URI: " . $digest );
		$msg      = 'enabledpuri';
		$msgparam = 'p1=' . $$self{cgi}->param('file');
		$msgparam .= ';p2=' . $main::PUBLIC_URL_BASE . $digest;
		$msgparam .= ';p3=' . $main::PUBLIC_URL_BASE . $digest;
	}
	else {
		$errmsg = 'foldernothingerr';

	}
	print $$self{cgi}->redirect( $redirtarget
		  . $self->createMsgQuery( $msg, $msgparam, $errmsg, $msgparam )
	);

	return 1;
}

#Unpublish URI and show message
sub disablePuri () {
	my ($self) = @_;
	my ( $msg, $errmsg, $msgparam );
	my $redirtarget = $main::REQUEST_URI;
	$redirtarget =~ s/\?.*$//;    # remove query
	if ( $$self{cgi}->param('file') ) {
		my $file = $self->resolveFile( $$self{cgi}->param('file') );
		main::logger( "Deleting public URI for file " . $file );
		$self->unsetPublicUri($file);
		$msg      = 'disabledpuri';
		$msgparam = 'p1=' . $$self{cgi}->param('file');
	}
	else {
		$errmsg = 'foldernothingerr';
	}
	print $$self{cgi}->redirect( $redirtarget
		  . $self->createMsgQuery( $msg, $msgparam, $errmsg, $msgparam )
	);
	return 1;
}

1;
