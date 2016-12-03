#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2013 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package WebInterface::View::Simple::Renderer;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( WebInterface::Common );

use URI::Escape;

use HTTPHelper qw( print_compressed_header_and_content );
use DefaultConfig qw(
    $PATH_TRANSLATED $REQUEST_URI
    $INSTALL_BASE $VHTDOCS $VIRTUAL_BASE
    @ALLOWED_TABLE_COLUMNS @VISIBLE_TABLE_COLUMNS @EXTENSIONS
    $DOCUMENT_ROOT $MAXNAVPATHSIZE $MAXFILENAMESIZE);
use HTTPHelper qw( get_parent_uri get_base_uri_frag );

sub render {
    my ($self) = @_;

    my $content;
    my $contenttype;
    $self->set_locale();
    my $atcregex = '^(' . join( q{|}, @ALLOWED_TABLE_COLUMNS ) . ')$';
    if ( 'selector' !~ /$atcregex/xms ) {
        unshift @ALLOWED_TABLE_COLUMNS, 'selector';
        unshift @VISIBLE_TABLE_COLUMNS, 'selector';
    }

    if ( $self->{cgi}->param('ajax') ) {
        ( $content, $contenttype ) = $self->_render_ajax_response();
    }
    elsif ($self->{cgi}->param('msg')
        || $self->{cgi}->param('errmsg')
        || $self->{cgi}->param('aclmsg')
        || $self->{cgi}->param('aclerrmsg')
        || $self->{cgi}->param('afsmsg')
        || $self->{cgi}->param('afserrmsg') )
    {
        ( $content, $contenttype )
            = $self->_get_web_renderer()->render_msg_response();
    }
    else {
        $content = $self->minify_html(
            $self->_get_web_renderer()->render_template(
                $PATH_TRANSLATED, $REQUEST_URI,
                $self->read_template('page')
            )
        );
    }
    $content     //= q{};
    $contenttype //= 'text/html';
    return print_compressed_header_and_content( '200 OK', $contenttype,
        $content, 'Cache-Control: no-cache, no-store',
        $self->get_cookies() );
}
sub free {
    my ($self) = @_;
    delete $self->{config}->{wr};
    delete $self->{config}->{flr};
    $self->SUPER::free();
    return $self;
}
sub get_cookies {
    my ($self) = @_;
    my @cookies = @{ $self->SUPER::get_cookies() };
    $self->{config}->{extensions}
        ->handle( 'cookies', { cookies => \@cookies } );
    return \@cookies;
}

sub _get_web_renderer {
    my ($self) = @_;
    require WebInterface::View::Simple::RenderWeb;
    return $self->{config}->{wr} = WebInterface::View::Simple::RenderWeb->new();
}

sub _get_file_list_renderer {
    my ($self) = @_;
    require WebInterface::View::Simple::RenderFileListTable;
    return $self->{config}->{flr} = WebInterface::View::Simple::RenderFileListTable->new();
}

sub _render_ajax_response {
    my ($self) = @_;
    my $ajax = $self->{cgi}->param('ajax');
    if ( $ajax eq 'getFileListTable' ) {
        return (
            $self->_get_file_list_renderer()->render_file_list_table(
                scalar $self->{cgi}->param('template')
            ),
            'application/json'
        );
    }
    if ( $ajax eq 'getViewFilterDialog' ) {
        return $self->_get_web_renderer()
            ->render_viewfilter_dialog(
            scalar $self->{cgi}->param('template') );
    }
    if ( $ajax eq 'getTableConfigDialog' ) {
        return $self->_get_web_renderer()
            ->render_template( $PATH_TRANSLATED, $REQUEST_URI,
            $self->read_template( scalar $self->{cgi}->param('template') ) );
    }
    if ( $ajax eq 'getFileListEntry' ) {
        return $self->_get_file_list_renderer()->get_file_list_entry();
    }
    return;
}

sub exec_template_function {
    my ( $self, $fn, $ru, $func, $param ) = @_;
    if ( $func eq 'extension' ) {
        return $self->_render_extension($param);
    }
    return $self->SUPER::exec_template_function( $fn, $ru, $func, $param );
}

sub render_extension_element {
    my ( $self, $hook, $a ) = @_;
    my $content = q{};
    if ( ref($a) eq 'HASH' ) {
        if ( ${$a}{subpopupmenu} ) {
            return $self->{cgi}->li(
                {   -class => 'subpopupmenu extension '
                        . ( ${$a}{classes} || q{} )
                },
                ( ${$a}{title} || q{} )
                    . $self->{cgi}->ul(
                    { -class => 'subpopupmenu extension' },
                    $self->render_extension_element( $hook, ${$a}{subpopupmenu} )
                    )
            );
        }
        my %params = ( -class => q{} );
        $params{-class} .= ${$a}{action} ? ' action ' . ${$a}{action} : q{};
        $params{-class}
            .= ${$a}{listaction} ? ' listaction ' . ${$a}{listaction} : q{};
        $params{-class} .= ${$a}{classes}  ? q{ } . ${$a}{classes} : q{};
        $params{-class} .= ${$a}{disabled} ? ' hidden'             : q{};
        if ( ${$a}{accesskey} ) { $params{-accesskey} = ${$a}{accesskey}; }
        if ( ${$a}{title} || ${$a}{label} ) {
            $params{-title} = $self->tl( ${$a}{title} || ${$a}{label} );
        }
        if ( ${$a}{template} ) { $params{-data_template} = ${$a}{template}; }
        $content .= ${$a}{prehtml} ? ${$a}{prehtml} : q{};

        if ( ${$a}{data} ) {
            foreach my $data ( keys %{ ${$a}{data} } ) {
                $params{"-data-$data"} = ${$a}{data}{$data};
            }
        }
        if ( ${$a}{attr} ) {
            foreach my $attr ( keys %{ ${$a}{attr} } ) {
                $params{"-$attr"} = ${$a}{attr}{$attr};
            }
        }
        if ( ${$a}{type} && ${$a}{type} eq 'li' ) {
            $content .= $self->{cgi}->li(
                \%params,
                $self->{cgi}->span(
                    { -class => 'label' }, $self->tl( ${$a}{label} )
                )
            );
        }
        else {
            $params{-href} = q{#};
            $params{-data_action} = ${$a}{action} || ${$a}{listaction};
            $content .= $self->{cgi}->a(
                \%params,
                $self->{cgi}->span(
                    { -class => 'label' }, $self->tl( ${$a}{label} )
                )
            );
            if ( ${$a}{type} && ${$a}{type} eq 'li-a' ) {
                $content = $self->{cgi}
                    ->li( { -class => ${$a}{liclasses} || q{} }, $content );
            }
        }
        $content .= ${$a}{posthtml} ? ${$a}{posthtml} : q{};
    }
    elsif ( ref($a) eq 'ARRAY' ) {
        $content = join q{},
            map { $self->render_extension_element($hook, $_) } @{$a};
    }
    else {
        $content .= $a;
    }
    return $content;
}

sub _render_extension {
    my ( $self, $hook ) = @_;

    if ( $hook eq 'javascript' ) {
        if ( $self->{config}->{webinterface}->optimizer_is_optimized() ) {
            my $vbase = $self->get_vbase();
            return
                q@<script>$(document).ready(function() { $(document.createElement("script")).attr("src","@
                . "${vbase}${VHTDOCS}_OPTIMIZED(js)_"
                . q@").appendTo($("body")); });</script>@;
        }
        else {
            return q@<script>$(document).ready(function() {var l=new Array(@
                . join(
                q{,},
                map { q{'} . $self->{cgi}->escape($_) . q{'} } @{
                    $self->{config}{extensions}
                        ->handle( $hook, { path => $PATH_TRANSLATED } )
                }
                )
                . q@);$("<div/>").html($.map(l,function(v,i){return decodeURIComponent(v);}).join("")).appendTo($("body"));});</script>@;
        }
    }
    elsif ( $hook eq 'css' ) {
        if ( $self->{config}->{webinterface}->optimizer_is_optimized() ) {
            my $vbase = $self->get_vbase();
            return
                qq@<link rel="stylesheet" href="${vbase}${VHTDOCS}_OPTIMIZED(css)_"/>@;
        }
    }

    return join q{},
        map { $self->render_extension_element($hook, $_) }
        @{ $self->{config}{extensions}
            ->handle( $hook, { path => $PATH_TRANSLATED } ) // [] };
}

sub read_template {
    my ( $self, $filename ) = @_;
    return $self->SUPER::read_template( $filename,
        "$INSTALL_BASE/templates/simple/" );
}

sub render_quicknav_path {
    my ( $self, $query ) = @_;
    my $ru      = uri_unescape($REQUEST_URI);
    my $content = q{};
    my $path    = q{};
    my $navpath = $ru;
    my $base    = q{};
    if ( $navpath =~ s/^($VIRTUAL_BASE)//xms ) {
        $base = $1;
    }

    if ( $base ne q{/} ) {
        $navpath = get_base_uri_frag($base) . "/$navpath";
        $base    = get_parent_uri($base);
        $base .= $base ne q{/} ? q{/} : q{};
        $content .= $base;
    }
    else {
        $base    = q{};
        $navpath = "/$navpath";
    }
    my @fna = split /\//xms, substr $PATH_TRANSLATED, length $DOCUMENT_ROOT;
    my $fnc = $DOCUMENT_ROOT;
    my @pea             = split /\//xms, $navpath;    ## path element array
    my $navpathlength   = length $navpath;
    my $ignorepe        = 0;
    my $lastignorepe    = 0;
    my $ignoredpes      = q{};
    my $lastignoredpath = q{};

    for my $i ( 0 .. $#pea ) {
        my $pe = $pea[$i];
        $path .= uri_escape($pe) . q{/};
        if ( $path eq q{//} ) { $path = q{/}; }
        my $dn = "$pe/";
        $dn
            = $fnc eq $DOCUMENT_ROOT
            ? "$pe/"
            : $self->{backend}->getDisplayName($fnc);
        $lastignorepe = $ignorepe;
        $ignorepe     = 0;
        if (   defined $MAXNAVPATHSIZE
            && $MAXNAVPATHSIZE > 0
            && $navpathlength > $MAXNAVPATHSIZE )
        {

            if ( $i == 0 ) {
                if ( length($dn) > $MAXFILENAMESIZE ) {
                    $dn = substr( $dn, 0, $MAXFILENAMESIZE - 6 ) . '[...]/';
                    $navpathlength -= $MAXFILENAMESIZE - 8;
                }
            }
            elsif ( $i == $#pea ) {
                $dn = substr( $dn, 0, $MAXNAVPATHSIZE - 7 ) . '[...]/';
                $navpathlength -= length($dn) - 8;
            }
            else {
                $navpathlength -= length $dn;
                $ignorepe        = 1;
                $lastignoredpath = "$base$path";
            }
        }
        $ignoredpes .= $ignorepe ? "$pe/" : q{};
        if ( !$ignorepe && $lastignorepe ) {
            $content
                .= $self->{cgi}
                ->a( { -href => $lastignoredpath, -title => $ignoredpes },
                ' [...]/ ' );
            $ignoredpes = q{};
        }
        $content .=
            !$ignorepe
            ? $self->{cgi}->a(
            {   -href => "$base$path" . ( defined $query ? "?$query" : q{} ),
                -title =>
                    $self->{cgi}->escapeHTML( uri_unescape("$base$path") )
            },
            $self->{cgi}->escapeHTML(" $dn ")
            )
            : q{};
        if ( scalar @fna > 0 ) { $fnc .= shift(@fna) . q{/}; }
    }
    $content .=
          $content eq q{}
        ? $self->{cgi}->a( { -href => q{/}, -title => q{/} }, q{/} )
        : q{};

    return $content;
}
1;
