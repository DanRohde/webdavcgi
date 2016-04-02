#!/usr/bin/perl
##!/usr/bin/speedy  -- -r50 -M7 -t3600
##!/usr/bin/perl -d:NYTProf
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2016 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
# REQUIREMENTS:
#    - see http://webdavcgi.sf.net/doc.html#requirements
# INSTALLATION:
#    - see http://webdavcgi.sf.net/doc.html#installation
# CHANGES:
#    - see CHANGELOG
# KNOWN PROBLEMS:
#    - see http://webdavcgi.sf.net/
# CONFIG OPTIONS (OLD SETUP SECTION):
#    - see etc/webdav.conf.complete
#########################################################################
package main;
use strict;
use warnings;
our $VERSION = '2.0';    # only module version! release number is in $RELEASE

use WebDAVCGI;

use vars qw( $W );

$W //= WebDAVCGI->new();
$W->run();

1;
