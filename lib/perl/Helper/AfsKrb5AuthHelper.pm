#!/usr/bin/perl
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
package Helper::AfsKrb5AuthHelper;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( Helper::Krb5AuthHelper );

use AFS::PAG qw( setpag unlog );
use CGI::Carp;

sub init {
    my ($self) = @_;
    my $ret = 1;

    if ( $ret = $self->SUPER::init() ) {
        setpag();
        confess("aklog failed for $ENV{REMOTE_USER}") if system('aklog') > 0;
    }
    return $ret;
}

sub receive {
    my $self = shift;
    $self->SUPER::receive(@_);
    unlog();
    return 1;
}
1;
