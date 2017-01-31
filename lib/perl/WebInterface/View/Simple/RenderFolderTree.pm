#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package WebInterface::View::Simple::RenderFolderTree;

use strict;
use warnings;

our $VERSION = '1.0';

use base qw( WebInterface::View::Simple::Renderer );

use JSON;

use DefaultConfig qw( $REQUEST_URI $PATH_TRANSLATED  );
use FileUtils qw( get_file_limit );


sub _b2yn {
    my ($self, $bool, $format) = @_;
    return sprintf $format // q{%s}, $bool ? 'yes' : 'no';
}
sub handle_folder_tree {
    my ($self) = @_;
    my %response = ();
    my @files = $self->{backend}->isReadable($PATH_TRANSLATED)
        ? sort { $self->cmp_files( $a, $b ) } @{
        $self->{backend}
            ->readDir( $PATH_TRANSLATED, get_file_limit($PATH_TRANSLATED),
            $self )
        }
        : ();
    my @children = ();
    foreach my $file ( @files ) {
        my $full = $PATH_TRANSLATED.$file;
        my $isreadable = $self->{backend}->isReadable($full);
        my $iswriteable = $self->{backend}->isWriteable($full);
        my $fileuri = $REQUEST_URI.$self->{cgi}->escape($file).q{/};
        if ($self->{backend}->isDir($full)) {
            push @children, {
                name => $self->{backend}->getDisplayName($full),
                uri  => $fileuri,
                title => $self->{cgi}->escapeHTML($self->{cgi}->unescape($REQUEST_URI.$file).q{/}),
                help => $self->tl('foldertree.help'),
                read => !$isreadable,
                isreadable => $isreadable,
                classes => $self->_b2yn($isreadable, 'isreadable-%s').$self->_b2yn($iswriteable,' iswriteable-%s').$self->_b2yn($file=~/^[.]/xms, ' isdotfile-%s'),
            };
        }
    }
    $response{children} = \@children;
    $self->{json} //= JSON->new();
    return ( $self->{json}->encode(\%response), 'application/json');
}

1;