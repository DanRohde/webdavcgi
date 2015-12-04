#!/usr/bin/perl
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2011 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package WebDAV::ACL;

use strict;

sub new {
	my $this = shift;
	my $class = ref($this) || $this;
	my $self = { };
	bless $self, $class;

	$$self{cgi}=shift;
	$$self{backend}=shift;
	return $self;
}

sub getACLCurrentUserPrivilegeSet {
        my ($self,$fn) = @_;

        my $usergrant;
        if ($$self{backend}->isReadable($fn)) {
                push @{$$usergrant{privilege}},{read  => undef };
                push @{$$usergrant{privilege}},{'read-acl'  => undef };
                push @{$$usergrant{privilege}},{'read-current-user-privilege-set'  => undef };
                push @{$$usergrant{privilege}},{'read-free-busy'  => undef };
                push @{$$usergrant{privilege}},{'schedule-query-freebusy'  => undef };
                if ($$self{backend}->isWriteable($fn)) {
                        push @{$$usergrant{privilege}},{write => undef };
                        push @{$$usergrant{privilege}},{'write-acl' => undef };
                        push @{$$usergrant{privilege}},{'write-content'  => undef };
                        push @{$$usergrant{privilege}},{'write-properties'  => undef };
                        push @{$$usergrant{privilege}},{'unlock'  => undef };
                        push @{$$usergrant{privilege}},{bind=> undef };
                        push @{$$usergrant{privilege}},{unbind=> undef };
                        push @{$$usergrant{privilege}},{all=> undef };
                }
        }

        return $usergrant;
}

sub getACLSupportedPrivilegeSet {
        return { 'supported-privilege' =>
                        {
                                privilege => { all => undef },
                                abstract => undef,
                                description=>'Any operation',
                                'supported-privilege' => [
                                        {
                                                privilege => { read =>  undef },
                                                description => 'Read any object',
                                                'supported-privilege' => [
                                                        {
                                                                privilege => { 'read-acl' => undef },
                                                                absract => undef,
                                                                description => 'Read ACL',
                                                        },
                                                        {
                                                                privilege => { 'read-current-user-privilege-set' => undef },
                                                                absract => undef,
                                                                description => 'Read current user privilege set property',
                                                        },
                                                        {       privilege => { 'read-free-busy' },
                                                                abstract => undef,
                                                                description => 'Read busy time information'
                                                        },
                                                ],
                                        },
                                        {
                                                privilege => { write => undef },
                                                description => 'Write any object',
                                                'supported-privilege' => [
                                                        {
                                                                privilege => { 'write-acl' => undef },
                                                                abstract => undef,
                                                                description => 'Write ACL',
                                                        },
                                                        {
                                                                privilege => { 'write-properties' => undef },
                                                                abstract => undef,
                                                                description => 'Write properties',
                                                        },
                                                        {
                                                                privilege => { 'write-content' => undef },
                                                                abstract => undef,
                                                                description => 'Write resource content',
                                                        },
                                                ],

                                        },
                                        {
                                                privilege => {unlock => undef},
                                                abstract => undef,
                                                description => 'Unlock resource',
                                        },
                                        {
                                                privilege => {bind => undef},
                                                abstract => undef,
                                                description => 'Add new files/folders',
                                        },
                                        {
                                                privilege => {unbind => undef},
                                                abstract => undef,
                                                description => 'Delete or move files/folders',
                                        },
                                ],
                        }
        };
}

sub getACLProp {
        my ($self, $mode) = @_;
        my @ace;

        my $ownergrant;
        my $groupgrant;
        my $othergrant;

        $mode = $mode & oct(7777);

        push @{$$ownergrant{privilege}},{read  => undef } if ($mode & oct(400)) == oct(400);
        push @{$$ownergrant{privilege}},{write => undef } if ($mode & oct(200)) == oct(200);
        push @{$$ownergrant{privilege}},{bind => undef } if ($mode & oct(200)) == oct(200);
        push @{$$ownergrant{privilege}},{unbind => undef } if ($mode & oct(200)) == oct(200);
        push @{$$groupgrant{privilege}},{read  => undef } if ($mode & oct(40)) == oct(40);
        push @{$$groupgrant{privilege}},{write => undef } if ($mode & oct(20)) == oct(20);
        push @{$$groupgrant{privilege}},{bind => undef } if ($mode & oct(20)) == oct(20);
        push @{$$groupgrant{privilege}},{unbind => undef } if ($mode & oct(20)) == oct(20);
        push @{$$othergrant{privilege}},{read  => undef } if ($mode & oct(4)) == oct(4);
        push @{$$othergrant{privilege}},{write => undef } if ($mode & oct(2)) == oct(2);
        push @{$$othergrant{privilege}},{bind => undef } if ($mode & oct(2)) == oct(2);
        push @{$$othergrant{privilege}},{unbind => undef } if ($mode & oct(2)) == oct(2);

        push @ace, { principal => { property => { owner => undef } },
                     grant => $ownergrant
                   };
        push @ace, { principal => { property => { owner => undef } },
                     deny => { privilege => { all => undef } }
                   };

        push @ace, { principal => { property => { group => undef } },
                     grant => $groupgrant
                   };
        push @ace, { principal => { property => { group => undef } },
                     deny => { privilege => { all => undef } }
                   };

        push @ace, { principal => { all => undef },
                     grant => $othergrant
                   };

        return { ace => \@ace };
}

1;
