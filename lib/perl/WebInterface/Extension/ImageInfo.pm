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
#
# SETUP:
#   hidegroups - sets a list of groups to hide (default: ['ExifTool'])

package WebInterface::Extension::ImageInfo;

use strict;
use warnings;
our $VERSION = '2.0';

use base qw( WebInterface::Extension );

#use MIME::Base64;

use DefaultConfig qw( $LANG $PATH_TRANSLATED $REQUEST_URI );
use HTTPHelper qw( get_mime_type print_compressed_header_and_content );

use vars qw( @FILETYPES );

@FILETYPES = qw( image audio video application text );

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw(css locales javascript posthandler fileactionpopup fileattr appsmenu);
    $hookreg->register( \@hooks, $self );

    my %ig = map { $_ => 1 } @{ $self->config( 'hidegroups', ['ExifTool'] ) };
    $self->{hidegroups} = \%ig;
    return $self;
}

sub handle_hook_fileattr {
    my ( $self, $config, $params ) = @_;
    my $mime        = get_mime_type( $params->{path} );
    my $is_readable = $self->{backend}->isReadable( $params->{path} );
    my $classes     = q{};
    foreach my $type (@FILETYPES) {
        $classes .=
          " imageinfo-$type-"
          . ( $is_readable && $mime =~ /^\Q$type\E\//xmsi ? 'show' : 'hide' );
    }
    return { ext_classes => $classes };
}

sub _get_popup {
    my ( $self, $classes ) = @_;
    my $ret         = [];
    foreach my $type (@FILETYPES) {
        push @{$ret},
          {
            action   => 'imageinfo ' . $type,
            label    => 'imageinfo.' . $type,
            classes  => $classes,
            data     => { mime => $type.q{/} },
            type     => 'li'
          };
    }
    return $ret;
}

sub handle_hook_fileactionpopup {
    my ( $self, $config, $params ) = @_;
    return $self->_get_popup('access-readable');
}
sub handle_hook_appsmenu {
    my ( $self, $config, $params ) = @_;
    return $self->_get_popup('access-readable sel-one-mime hideit');
}
sub handle_hook_posthandler {
    my ( $self, $config, $params ) = @_;
    if (   $self->{cgi}->param('action')
        && $self->{cgi}->param('action') eq 'imageinfo' )
    {
        my $file = $self->{cgi}->param('file');
        print_compressed_header_and_content(
            '200 OK',
            'text/html',
            $self->_render_image_info(
                $file,
                $self->_get_image_info(
                    $self->{backend}
                      ->getLocalFilename( $PATH_TRANSLATED . $file )
                )
            )
        );
        return 1;
    }

    return 0;
}

sub _render_image_info {
    my ( $self, $file, $ii ) = @_;
    my $c = $self->{cgi};

    my $pt = $PATH_TRANSLATED;
    my $ru = $REQUEST_URI;

    my $tmppath = $ii->{_tmppath_};
    my $tmpfile = $self->{backend}->basename($tmppath);
    my $tmpdir  = $self->{backend}->dirname($tmppath);

    my $dialogtmpl       = $self->read_template('imageinfo');
    my $groupcontenttmpl = $self->read_template('groupcontent');
    my $grouptmpl        = $self->read_template('group');
    my $proptmpl         = $self->read_template('prop');

    my $groups       = q{};
    my $groupcontent = q{};

    my $mime = get_mime_type($file);
    my $type = $mime =~ m{^([^/]+)}xms ? $1 : 'image';

    foreach my $gr ( @{ $ii->{_groups_} } ) {
        next if $self->{hidegroups}{$gr};
        $groups .=
          $self->render_template( $pt, $ru, $grouptmpl, { group => $gr } );
        my $props = q{};
        foreach my $pr ( sort keys %{ $ii->{$gr} } ) {
            my $val = $ii->{$gr}{$pr};
            $val =~ s/\Q$tmpfile\E/$file/xmsg;
            $val =~ s/\Q$tmpdir\E/$REQUEST_URI/xmsg;
            my $img =
              $ii->{_binarydata_}{$gr}{$pr}
              ? '<br>'
              . $c->img(
                {
                    -alt   => $pr,
                    -title => $pr,
                    -src   => 'data:'
                      . $mime
                      . ';base64,'
                      . $ii->{_binarydata_}{$gr}{$pr}
                }
              )
              : q{};
            $props .= $self->render_template(
                $pt, $ru,
                $proptmpl,
                {
                    propname  => $c->escapeHTML($pr),
                    propvalue => $c->escapeHTML($val),
                    img       => $img
                }
            );
        }
        $groupcontent .= $self->render_template( $pt, $ru, $groupcontenttmpl,
            { group => $gr, props => $props } );
    }
    my $img =
      $ii->{_thumbnail_} ? $c->img(
        {
            -src   => 'data:' . $mime . ';base64,' . $ii->{_thumbnail_},
            -alt   => q{},
            -class => 'iithumbnail'
        }
      )
      : $self->has_thumb_support($mime) ? $c->img(
        {
            -src   => $REQUEST_URI . $file . '?action=thumb',
            -class => 'iithumbnail',
            -alt   => q{}
        }
      )
      : q{};
    return $self->render_template(
        $pt, $ru,
        $dialogtmpl,
        {
            dialogtitle => sprintf(
                $self->tl("imageinfo.$type.dialogtitle"),
                $c->escapeHTML($file)
            ),
            groups       => $groups,
            groupcontent => $groupcontent,
            img          => $img,
            imglink      => $REQUEST_URI . $file,
            type         => $type
        }
    );
}

sub _get_image_info {
    my ( $self, $file ) = @_;
    my %ret = ( _tmppath_ => $file );
    require MIME::Base64;
    require Image::ExifTool;
    my $et = Image::ExifTool->new();
    $et->Options(
        Unknown    => 1,
        Charset    => 'UTF8',
        Lang       => $LANG,
        DateFormat => $self->tl('lastmodifiedformat')
    );
    my $info = $et->ImageInfo($file);
    $ret{_thumbnail_} =
      $info->{ThumbnailImage} || $info->{PhotoshopThumbnail}
      ? MIME::Base64::encode_base64(
        ${ $info->{ThumbnailImage} || $info->{PhotoshopThumbnail} } )
      : undef;

    my $group = q{};
    foreach my $tag ( $et->GetFoundTags('Group0') ) {
        if ( $et->GetGroup($tag) ne $group ) {
            $group = $et->GetGroup($tag);
            push @{ $ret{_groups_} }, $group;
        }
        my $val   = $info->{$tag};
        my $descr = $et->GetDescription($tag);
        if ( ref $val eq 'SCALAR' ) {
            if ( ${$val} =~ /^Binary\sdata/xms ) {
                $val = "(${$val})";
            }
            else {
                my $b64 = MIME::Base64::encode_base64( ${$val} );
                $b64 =~ s/\s//xmsg;
                $ret{_binarydata_}{$group}{$descr} = $b64;
                my $len = length ${$val};
                $val = sprintf $self->tl( 'imageinfo.binarydata',
                    '(Binary data: %d bytes)' ), $len;
            }
        }
        $ret{$group}{$descr} = $val;
    }
    return \%ret;
}
1;
