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

package WebInterface::Extension::PublicUriShow;
use Data::Dumper;
use strict;

use WebInterface::Renderer;
our @ISA = qw( WebInterface::Renderer );

use Digest::MD5 qw(md5 md5_hex md5_base64);

#CONSTRUCTOR
sub new {
	my $this  = shift;
	my $class = ref($this) || $this;
	my $self  = {};
	bless $self, $class;
	$$self{config}  = shift;
	$$self{db}      = shift;
	$$self{cgi}     = $$self{config}->getProperty('cgi');
	$$self{backend} = $$self{config}->getProperty('backend');
	$self->init();
	return $self;
}

#URI CRUD
sub getFileFromUri {
	my ( $self, $code ) = @_;
	my $fn = $$self{db}->db_getPropertyFnByValue( $main::EXTENSION_CONFIG{PublicUri}{public_prop}, $code );
	$fn =~ s/^$main::EXTENSION_CONFIG{Public_Uri}{public_prop_prefix}//;
	return $fn;
}

sub init {
	my ($self) = @_;

	if (   $main::REQUEST_URI !~ /$main::VHTDOCS/
		&& $main::REQUEST_URI !~ /^${main::VIRTUAL_BASE}.*js$/
		&& $main::REQUEST_URI !~ /^${main::VIRTUAL_BASE}.*css$/ )
	{
		if ( $main::PATH_TRANSLATED =~
			/$main::DOCUMENT_ROOT$main::PUBLIC_PREFIX/ )
		{
			my $code = $main::PATH_TRANSLATED;			
			$code =~ s/$main::DOCUMENT_ROOT(.*?)(\/.*?)?$/$1/;
			my $fn = $self->getFileFromUri($code);
			if ( !defined($fn) ) {
				main::printHeaderAndContent('404 Not found');
				main::logger ("Illegal public URL (wrong code): " . $main::REQUEST_URI . ". Exit 404.");
				exit();
			}
			main::logger ("Public URI mapped: " . $main::REQUEST_URI . " -> " . $main::PATH_TRANSLATED );
			$main::PATH_TRANSLATED = $fn . $2;	
			#the first link in the WebInterface path is the alias itself
			#this way way the alias is no link, otherwise we'd had a dead link
			$main::VIRTUAL_BASE =~ s/\/(.*?)\//\/$1\/$code\//;
			main::logger ("Set VIRTUAL_BASE to: " . $main::VIRTUAL_BASE);
		}
		else {
			#No code
			main::logger ("Illegal public URL (no code): " . $main::REQUEST_URI . ". Exit 404.");
			main::printHeaderAndContent('404 Not found');
			exit();
		}
	} else {
		main::logger ("Unfiltered REQUEST_URI: $main::REQUEST_URI -> $main::PATH_TRANSLATED");
	}

}

#Show icons and handle actions
sub handle {
	my ( $self, $hook, $config, $params ) = @_;

	$$self{cgi}     = $$config{cgi};
	$$self{db}      = $$config{db};
	$$self{backend} = $$config{backend};
	if ( $hook eq 'posthandler' ) {

		#handle actions
		if ( $$self{cgi}->param('puri') ) {
			enablePuri($self);
		}
		elsif ( $$self{cgi}->param('depuri') ) {
			disablePuri($self);
		}
		else {
			return 0;    #not handled
		}
		return 1;
	}
	elsif ( $hook eq 'fileaction' ) {

		#show icon
		my $prop = $self->getPublicUri( $$params{path} );
		my $icon = 'depuri';
		my $txt  = "Unset Pulic Uri";
		if ( !defined($prop) ) {
			$icon = 'puri';
			$txt  = 'Public URI';
		}

		return {
			action   => $icon,
			disabled => !$$self{backend}->isReadable( $$params{path} ),
			label    => $txt,
			path     => $$params{path}
		};
	}
	return 0;    #not handled
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

#Publish URI and show message
sub enablePuri () {
	my ($self) = @_;

	return 1;
}

#Unpublish URI and show message
sub disablePuri () {
	my ($self) = @_;

	return 1;
}

1;