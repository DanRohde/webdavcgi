#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written by Daniel Rohde <d.rohde@cms.hu-berlin.de>
#########################################################################
# This is a very pure WebDAV server implementation that
# uses the CGI interface of a Apache webserver.
# Use this script in conjunction with a UID/GID wrapper to
# get and preserve file permissions.
# IT WORKs ONLY WITH UNIX/Linux.
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
# This is a callback handler adapter of AdsSmbConfigurator 
# for the SessionAtuthenticationHandler 
# and is called after a successful login and for every request.
package Helper::AdsSmbConfiguratorSessionAdapter;

use strict;
use warnings;

our $VERSION = '1.0';

use DefaultConfig qw( %BACKEND_CONFIG );
use Helper::AdsSmbConfigurator;

sub init {
    my ( $self, $param ) = @_;
    my $c = Helper::AdsSmbConfigurator->new(%{$param});
    $BACKEND_CONFIG{SMB} = $c->getSmbConfig();
    return $self;
}

1;