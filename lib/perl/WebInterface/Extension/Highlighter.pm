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
# Simple CSS highlighting for file list entries
# SETUP:
# namespace - XML namespace for attributes (default: {https://DanRohde.github.io/webdavcgi/extension/Highlighter/$REMOTE_USER})
# attributes - CSS attributes to change for a file list entry

package WebInterface::Extension::Highlighter;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( WebInterface::Extension );

use JSON;

use DefaultConfig qw( $PATH_TRANSLATED $REMOTE_USER );
use HTTPHelper qw( print_compressed_header_and_content );

use vars qw(%_CACHE);

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks =
      qw(css locales javascript posthandler fileattr fileactionpopup);

    $hookreg->register( \@hooks, $self );

    $self->{namespace} = $self->config( 'namespace',
            '{https://DanRohde.github.io/webdavcgi/extension/Highlighter/'
          . $REMOTE_USER
          . '}' );
    $self->{attributes} = $self->config(
        'attributes',
        {
            'color' => {
                values      => '#FF0000,#00FF00,#0000FF,#FFA500,#A020E0',
                style       => 'color',
                labelcss    => 'color: white; font-weight: bold;',
                labelstyle  => 'background-color',
                colorpicker => 1,
                order       => 2,
            },
            'background-color' => {
                values      => '#F07E50,#ADFF2F,#ADD8E6,#FFFF00,#EE82EE',
                style  => 'background-color',
                colorpicker => 1,
                order       => 1,
            },
            'border' => {
                subpopupmenu => {
                   'border-color'   => {
                        values      => '#FF0000,#00FF00,#0000FF,#FFA500,#A020E0',
                        style       => 'border-color',
                        labelstyle  => 'background-color',
                        labelcss    => 'border-style: solid; border-width: 1px;color: white; font-weight: bold;',
                        colorpicker => 1,
                        order       => 1,
                    },
                    'border-width' => {
                        values     => 'thin,medium,thick',
                        style      => 'border-width',
                        labelcss   => 'border-style: solid; border-color: black;',
                        order      => 2,
                    },
                    'border-style' => {
                        values     => 'dotted,dashed,solid,double,groove,ridge,inset,outset',
                        style      => 'border-style',
                        labelcss   => 'border-color: gray; border-width: 3px;',
                        order      => 3,
                    }
                },
                order => 3,
            },
            'font' => {
                subpopupmenu => {
                   'font-size' => {
                        values => 'xx-large,x-large,larger,large,medium,small,smaller,x-small,xx-small',
                        style  => 'font-size',
                        order  => 1,
                    },
                    'font-style' => {
                        values   => 'lighter,bold,bolder,italic,oblique',
                        styles   => { italic  => 'font-style', oblique => 'font-style', _default => 'font-weight' },
                        order      => 2,
                    },
                    'font-family' => {
                        values    => 'serif,sans-serif,cursive,fantasy,monospace',
                        style     => 'font-family',
                        order     => 2,
                    },
                    'text-transform' => {
                        values       => 'lowercase,uppercase,capitalize,small-caps',
                        styles       => { _default => 'text-transform', 'small-caps' => 'font-variant' },
                        order        => 6,
                    },
                },
                order => 10,
            },
            'text' => {
                subpopupmenu => {
                    'text-decoration' => {
                        values        => 'underline,overline,line-through,underline overline,overline underline line-through,underline line-through,overline line-through',
                        style         => 'text-decoration',
                        order         => 3,
                    },
                    'text-decoration-color' => {
                        values              => '#FF0000,#00FF00,#0000FF,#FFA500,#A020E0',
                        style               => 'text-decoration-color',
                        labelstyle          => 'background-color',
                        labelcss            => 'color: white; font-weight: bold;',
                        colorpicker         => 1,
                        order               => 4,
                    },
                    'text-decoration-style' => {
                        values              => 'solid,double,dotted,dashed,wavy',
                        style               => 'text-decoration-style',
                        labelcss            => 'text-decoration-line: underline;',
                        order               => 5,
                    },
                },
                order => 15,
             },
        }
    );
    $self->{json} = JSON->new();
    return $self;
}

sub handle_hook_javascript {
    my ( $self, $config, $params ) = @_;
    if ( my $ret = $self->SUPER::handle_hook_javascript( $config, $params ) ) {
        $ret .= $self->SUPER::handle_hook_javascript( $config,
            { file => 'htdocs/contrib/iris.min.js' } );
        return $ret;
    }
    return 0;
}

sub handle_hook_posthandler {
    my ( $self, $config, $params ) = @_;
    my $action = $self->{cgi}->param('action') // q{};
    if ( $action eq 'mark' ) {
        return $self->_save_property();
    }
    elsif ( $action eq 'removemarks') {
        return $self->_remove_all_properties();
    }
    elsif ( $action eq 'transfermarks') {
        return $self->_replace_properties();
    }
    return 0;
}
sub _quote {
    my ($self,$s) =@_;
    $s=~s/\s+/_/xmsg;
    return $s;
}
sub _get_style {
    my ($self, $attribute, $val) = @_;
    return $attribute->{styles}
                ? $attribute->{styles}{$val} // $attribute->{styles}{_default}
                : $attribute->{style};
}
sub _create_subpopup {
    my ($self,$attrname, $attribute) = @_;
    my @subpopup = ();
    if ($attribute->{subpopupmenu}) {
        return $self->_create_popups($attribute->{subpopupmenu});
    } else {
        @subpopup = map {
            {
                action => 'mark',
                attr   => { style =>   ( $attribute->{labelcss} // q{} )
                                     . ( $attribute->{labelstyle} // $self->_get_style($attribute, $_) ) . ": $_;"
                                    ,
                },
                data  => { value => $_, style => $self->_get_style($attribute, $_) },
                label => $self->tl( $attribute->{label} // "highlighter.$attrname.".$self->_quote($_), $_ ),
                title => $self->tl( "highlighter.$attrname.title.".$self->_quote($_), $_ ),
                type  => 'li',
                classes => $attrname,
            }
        } split(/,/xms, $attribute->{values} );
        if ( $attribute->{colorpicker} ) {
            push @subpopup,
              {
                action  => 'markcolorpicker',
                data    => { value => $_, style => $attrname },
                label   => $self->tl('highlighter.colorpicker'),
                classes => 'sep',
                type    => 'li'
              };
        }
        push @subpopup,
          {
            action  => 'removemarks',
            data    => { styles => $attribute->{styles} ? join(q{,}, values %{$attribute->{styles}}) : $attribute->{style} // $attrname },
            label   => $self->tl("highlighter.remove.$attrname"),
            type    => 'li',
            classes => 'sep'
          };
    }
    return \@subpopup;
}
sub _create_popups {
    my ( $self, $attributes, $top ) = @_;
    my @popups = ();
    foreach my $attribute (
        sort {
            $attributes->{$a}{order} <=> $attributes->{$b}{order}
        } keys %{ $attributes }
      )
    {
        push @popups,
          {
            title        => $self->tl("highlighter.$attribute"),
            subpopupmenu => $self->_create_subpopup($attribute, $attributes->{$attribute}),
            classes      => "highlighter $attribute"
          };
    }
    if ($top) {
        push @popups,
             {
                action => 'transfermarks',
                data   => { styles => join q{,},@{$self->_get_all_propnames($attributes)} },
                label  => $self->tl('highlighter.transfermarks'),
                type   => 'li', classes=> 'sep',
            };
    }
    push @popups,
         {
            action  => 'removemarks',
            data    => { styles => join q{,},@{$self->_get_all_propnames($attributes)} },
            label   => $self->tl('highlighter.removeallmarks'),
            type    => 'li', classes => 'sep',
        };
    return \@popups;
}
sub handle_hook_fileactionpopup {
    my ( $self, $config, $params ) = @_;
    return {
        title        => $self->tl('highlighter'),
        subpopupmenu => $self->_create_popups($self->{attributes}, 1),
        classes      => 'highlighter-popup'
    };
}
sub _get_all_propnames {
    my ( $self, $attributes ) = @_;
    my @propnames = ();
    my %propexists = ();
    foreach my $attr ( keys %{ $attributes } )  {
        if ($attributes->{$attr}{subpopupmenu}) {
            push @propnames, @{ $self->_get_all_propnames($attributes->{$attr}{subpopupmenu}) };
        } else {
            my @allnames = $attributes->{$attr}{styles} ? values %{$attributes->{$attr}->{styles}} : $attributes->{$attr}{style};
            foreach my $propname (@allnames) {
                if ( ! $propexists{$propname}) {
                    push @propnames, $propname;
                    $propexists{$propname} = 1;
                }
            }
        }
    }
    return \@propnames;
}
sub handle_hook_fileattr {
    my ( $self, $config, $params ) = @_;

    my $path   = $self->{backend}->resolveVirt( ${$params}{path} );
    my $parent = $self->{backend}->getParent($path);
    if ( !exists $_CACHE{$self}{$parent} ) {
        $self->{db}->db_getProperties($parent);    ## fills the cache
    }
    $_CACHE{$self}{$parent} = 1;
    my %jsondata = ();
    foreach my $prop ( @{$self->_get_all_propnames($self->{attributes})} ) {
        if ( my $val =
            $self->{db}
            ->db_getPropertyFromCache( $path, $self->{namespace} . $prop ) )
        {
            $jsondata{$prop} = $val;
        }
    }

    return scalar( keys %jsondata ) > 0
      ? {
        'ext_classes'    => 'highlighter-highlighted',
        'ext_attributes' => 'data-highlighter="'
          . $self->{cgi}->escapeHTML( $self->{json}->encode( \%jsondata ) )
          . q{"}
      }
      : {};
}

sub _remove_all_properties {
    my ($self) = @_;
    my %jsondata = ();
    my @styles = map { $self->{namespace}.$_ } split /,/xms, $self->{cgi}->param('styles');
    foreach my $file ( $self->get_cgi_multi_param('files') ) {
        $self->{db}->db_removeProperties(
            $self->{backend}
              ->resolveVirt( $PATH_TRANSLATED . $self->_strip_slash($file) ),
            @styles
        );
    }
    print_compressed_header_and_content(
        '200 OK', 'application/json',
        $self->{json}->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}
sub _save_property {
    my ($self)   = @_;
    my %jsondata = ();
    my $db       = $self->{db};
    my $cgi      = $self->{cgi};
    my $style = $cgi->param('style') // 'color';
    my $value = $cgi->param('value') // 'black';
    my $propname = $self->{namespace} . $style;

    foreach my $file ( $self->get_cgi_multi_param('files') ) {
        my $full = $self->{backend}
          ->resolveVirt( $PATH_TRANSLATED . $self->_strip_slash($file) );
        my $result =
            $db->db_getProperty( $full, $propname )
          ? $db->db_updateProperty( $full, $propname, $value )
          : $db->db_insertProperty( $full, $propname, $value );
        if ( !$result ) {
            $jsondata{error}
              = sprintf $self->tl('highlighter.highlightingfailed'),
              $file;
            last;
        }
    }

    print_compressed_header_and_content(
        '200 OK', 'application/json',
        $self->{json}->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}
sub _replace_properties {
    my ($self) = @_;
    my $db = $self->{db};
    my %jsondata = ();
    my $data = $self->{json}->decode(scalar $self->{cgi}->param('data'));
    my @allpropnames = @{ $self->_get_all_propnames($self->{attributes}) };
    my @props = ();
    foreach my $file ( $self->get_cgi_multi_param('files') ) {
        my $full = $self->{backend}->resolveVirt($PATH_TRANSLATED . $self->_strip_slash($file));
        $db->db_removeProperties($full,  map { $self->{namespace} . $_ }  @allpropnames);
        foreach my $date (@allpropnames) {
            if (my $value = $data->{$date}) {
                my $propname = $self->{namespace} . $date;
                push @props, $full, $propname, $value;
            }
        }
    }
    if ($#props >= 0 ) {
        my $result = $db->db_insertProperties(@props);
        if (!$result) {
            $jsondata{error} = sprintf $self->tl('highlighter.highlightingfailed'), q{};
        }
    }
    print_compressed_header_and_content(
        '200 OK', 'application/json',
        $self->{json}->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}
sub _strip_slash {
    my ( $self, $file ) = @_;
    $file =~ s/\/$//xms;
    return $file;
}
1;
