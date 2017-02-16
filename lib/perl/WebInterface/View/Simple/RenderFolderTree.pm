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

use DefaultConfig qw( $REQUEST_URI $PATH_TRANSLATED $LIMIT_FOLDER_DEPTH );
use FileUtils qw( get_file_limit );


sub _b2yn {
    my ($self, $bool, $format) = @_;
    return sprintf $format // q{%s}, $bool ? 'yes' : 'no';
}
sub build_folder_tree {
    my ($self, $path, $uri, $filesref, $level) = @_;
    my @children = ();
    foreach my $file ( @{$filesref} ) {
        my $full = $path.$file;
        if ( $file =~ /^[.]{1,2}$/xms || !$self->{backend}->isDir($full)) { next; }
        $full.=q{/};
        my $isreadable = $self->{backend}->isReadable($full);
        my $iswriteable = $self->{backend}->isWriteable($full);
        my $fileuri = $uri.$self->{cgi}->escape($file).q{/};
        my $child = {
            name  => $self->{backend}->getDisplayName($full),
            uri   => $fileuri,
            title => $full,
            help  => $self->tl('foldertree.help'),
            isreadable => $isreadable,
            labelclasses => "icon ".$self->get_category_class(lc($file),'folder','category-folder'),
            classes => $self->_b2yn($isreadable, 'isreadable-%s')
                      .$self->_b2yn($iswriteable,' iswriteable-%s')
                      .$self->_b2yn(($file=~/^[.]/xms ? 1 : 0), ' isdotfile-%s'),
        };
        if (!$isreadable) {
            $child->{read} = 'yes';
            $child->{children} = [];
        } elsif ($level && $level > 0 && $level <= $LIMIT_FOLDER_DEPTH && !$self->{backend}->isLink($full)) {
            $child->{read} = 'yes';
            $child->{children} = $self->handle_folder_tree($full, $fileuri, $level+1);
        }
        push @children, $child;
    }
    return \@children;
}
sub handle_folder_tree {
    my ($self, $path, $uri, $level) = @_;
    $path    //= $PATH_TRANSLATED;
    $uri     //= $REQUEST_URI;
    $level   //= $self->{cgi}->param('recurse') ? 1 : 0;
    my $files = $self->{backend}->isReadable($path)
        ? $self->{backend}->readDir( $path, get_file_limit($path), $self )
        : [];
    my $children = $self->build_folder_tree($path, $uri, $files, $level);
    $self->{json} //= JSON->new();
    return $level > 1 ? $children : ( $self->{json}->encode({ children => $children}), 'application/json' );
}

1;