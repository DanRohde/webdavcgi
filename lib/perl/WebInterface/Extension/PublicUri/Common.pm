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

package WebInterface::Extension::PublicUri::Common;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( WebInterface::Extension );

use Digest::MD5 qw(md5_hex);

sub init_defaults {
    my ($self) = @_;

    ${$self}{namespace} = $self->config( 'namespace',
        '{http://webdavcgi.sf.net/extension/PublicUri/}' );
    ${$self}{propname} = $self->config( 'propname', 'public_prop' );
    ${$self}{seed}     = $self->config( 'seed',     'seed' );
    ${$self}{orig}     = $self->config( 'orig',     'orig' );
    ${$self}{prefix}   = $self->config( 'prefix',   q{} );

    ${$self}{uribase} = $self->config( 'uribase',
        'https://' . $ENV{HTTP_HOST} . '/public/' );

    ${$self}{virtualbase} = $self->config( 'basepath', '/public/' );
    ${$self}{allowedpostactions} = $self->config( 'allowedpostactions',
        '^(zipdwnload|diskusage|search|diff)$' );

    ${$self}{db} = main::getDBDriver();
    return;
}

sub config {
    my ( $self, $attr, $default ) = @_;
    return
        exists $main::EXTENSION_CONFIG{PublicUri}{$attr}
        ? $main::EXTENSION_CONFIG{PublicUri}
        : $default;
}

sub get_property_name {
    my ($self) = @_;
    return ${$self}{namespace} . ${$self}{propname};
}

sub get_seed_name {
    my ($self) = @_;
    return ${$self}{namespace} . ${$self}{seed};
}

sub get_orig_name {
    my ($self) = @_;
    return ${$self}{namespace} . ${$self}{orig};
}

sub get_file_from_code {
    my ( $self, $digest ) = @_;
    my $fna = ${$self}{db}
        ->db_getPropertyFnByValue( $self->get_property_name(), $digest );
    return $fna ? ${$fna}[0] : undef;
}

sub get_seed {
    my ( $self, $fn ) = @_;
    return ${$self}{db}->db_getProperty( ${$self}{backend}->resolveVirt($fn),
        $self->get_seed_name() );
}

sub get_orig {
    my ( $self, $fn ) = @_;
    return ${$self}{db}->db_getProperty( ${$self}{backend}->resolveVirt($fn),
        $self->get_orig_name() );
}

sub get_digest {
    my ( $self, $fn, $seed ) = @_;
    return ${$self}{prefix} . substr md5_hex( $fn . $seed ), 0, 16;
}

sub gen_url_hash {
    my ( $self, $fn ) = @_;
    my $seed
        = time . int( rand time ) . md5_hex($main::REMOTE_USER) . $fn;
    my $digest = $self->get_digest( $fn, $seed );
    return $digest, $seed;
}

sub is_public_uri {
    my ( $self, $fn, $code, $seed ) = @_;
    return $code eq $self->get_digest( $self->get_orig($fn), $seed );
}

1;
