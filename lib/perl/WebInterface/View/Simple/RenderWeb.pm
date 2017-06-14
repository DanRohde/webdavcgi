#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2016 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package WebInterface::View::Simple::RenderWeb;

use strict;
use warnings;
our $VERSION = '2.0';

use base qw( WebInterface::View::Simple::Renderer );

use POSIX qw(strftime ceil);

use DefaultConfig
  qw( $PATH_TRANSLATED $REQUEST_URI $REMOTE_USER $VIEW $VIRTUAL_BASE $POST_MAX_SIZE
  $FILETYPES @EXTENSIONS $LANG $VHTDOCS %SUPPORTED_LANGUAGES
);

use vars qw(%CACHE);

sub render_template {
    my ( $self, $fn, $ru, $content ) = @_;
    my $vbase = $self->get_vbase();

    # replace standard variables:
    my %stdvars = (
        uri          => $ru,
        baseuri      => $self->{cgi}->escapeHTML($vbase),
        quicknavpath => $self->{c}{render_template}{quicknavpath} //=
          $self->render_quicknav_path(),
        maxuploadsize   => $POST_MAX_SIZE,
        maxuploadsizehr => $self->{c}{render_template}{maxuploadsizehr} //=
          ( $self->render_byte_val( $POST_MAX_SIZE, 2, 2 ) )[0],
        stat_filetypes => $CACHE{render_template}{stat_filetypes} //=
          $self->stat_matchcount( $FILETYPES, '^\S+' ),
        stat_suffixes => $CACHE{render_template}{stat_suffixes} //=
          $self->stat_matchcount( $FILETYPES, '\S+' ) -
          $self->stat_matchcount( $FILETYPES, '^\S+' ),
        stat_extensions    => $#EXTENSIONS + 1,
        stat_filetypeicons => $CACHE{render_template}{stat_filetypeicons} //=
          join(
            q{},
            map {
                $self->{cgi}->img(
                    {
                        -class => /^(\S+)/xms ? "icon category-$1" : q{},
                        -src =>
'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
                        -style =>
'margin: 0 auto 0 auto;border:0;padding: 2px 0 2px 0;height:24px;width:20px;',
                        -alt => /^(\S+)/xms ? "Category \u$1" : q{},
                        -title => /^(\S+)/xms
                        ? "\u$1: "
                          . ( scalar( () = /\S+/xmsg ) - 1 )
                          . ' suffixes'
                        : q{},
                    }
                  )
            } $FILETYPES =~ /^\S+[^\n]+/xmsg
          ),
        stat_extensionlist => $CACHE{render_template}{stat_extensionlist} //=
          join( ', ', sort @EXTENSIONS ),
        stat_loadedperlmodules =>
          $CACHE{render_template}{stat_loadedperlmodules} //= keys(%INC) + 1,
        stat_perlmodulelist => $CACHE{render_template}{stat_perlmodulelist} //=
          join( ', ', sort keys %INC ),
        stat_perlversionnumber => $],
        view                   => $VIEW,
        viewname               => $self->tl("${VIEW}view"),
        USER                   => $REMOTE_USER,
        CLOCK                  => $self->{cgi}->span(
            {
                id            => 'clock',
                'data-format' => $self->tl('vartimeformat')
            },
            strftime( $self->tl('vartimeformat'), localtime )
        ),
        NOW             => strftime( $self->tl('varnowformat'), localtime ),
        REQUEST_URI     => $REQUEST_URI,
        PATH_TRANSLATED => $PATH_TRANSLATED,
        LANG            => $LANG,
        VBASE           => $self->{cgi}->escapeHTML($vbase),
        VHTDOCS         => $vbase . $VHTDOCS,
        decimalpoint => substr($self->render_perc_val(1.1,1), 1,1),
    );
    return $self->SUPER::render_template( $fn, $ru, $content, \%stdvars );
}

sub _render_language_list {
    my ( $self, $tmplfile ) = @_;
    my $tmpl =
        $tmplfile =~ /^'(.*)'$/xms
      ? $1
      : $self->read_template($tmplfile);
    my $content = q{};
    foreach my $lang (
        sort { $SUPPORTED_LANGUAGES{$a} cmp $SUPPORTED_LANGUAGES{$b} }
        keys %SUPPORTED_LANGUAGES
      )
    {
        my $l = $tmpl;
        $l =~ s/\$langname/$SUPPORTED_LANGUAGES{$lang}/xmsg;
        $l =~ s/\$lang/$lang/xmsg;
        $content .= $l;
    }
    return $content;
}

sub exec_template_function {
    my ( $self, $fn, $ru, $func, $param ) = @_;
    if ( $func eq 'langList' ) {
        return $self->_render_language_list($param);
    }
    return $self->SUPER::exec_template_function( $fn, $ru, $func, $param );
}
sub render_extension_element {
    my ( $self, $hook, $params ) = @_;
    my $navhooks_rx = qr{(?:apps|pref)}xms;
    if ($hook =~ /^(?:new|fileaction|fileactionpopupnew|filelistaction|$navhooks_rx)$/xms) {
        if (ref($params) eq 'HASH') {
            $params->{type} = 'li';
        }
    }
    return $self->SUPER::render_extension_element($hook, $params);
}
sub render_viewfilter_dialog {
    my ( $self, $tmplfile ) = @_;
    my $content = $self->read_template($tmplfile);
    my @filtername =
      $self->{cgi}->cookie('filter.name')
      ? split( /\s/xms, $self->{cgi}->cookie('filter.name') )
      : ( q{}, q{} );
    my @filtersize = ( q{}, q{}, q{} );
    if (   $self->{cgi}->cookie('filter.size')
        && $self->{cgi}->cookie('filter.size') =~
        /^([<>=]{1,2})(\d+)([KMGTP]?[B])$/xms )
    {
        @filtersize = ( $1, $2, $3 );
    }
    my %params = (
        'filter.name.val'  => $filtername[1],
        'filter.name.op'   => $filtername[0],
        'filter.size.op'   => $filtersize[0],
        'filter.size.val'  => $filtersize[1],
        'filter.size.unit' => $filtersize[2],
        'filter.types'     => $self->{cgi}->cookie('filter.types')
        ? $self->{cgi}->cookie('filter.types')
        : q{},
    );

    $content =~
s/[\$](selected|checked)[(]([^:)]+):([^)]+)[)]/$params{$2} eq $3 || $self->is_in($params{$2},$3) ? "$1=\"$1\"" : ""/xmegs;

    $content =~
s/[\$]([\w.]+)/exists $params{$1} ? $self->{cgi}->escapeHTML($params{$1}) : "\$$1"/xmegs;
    return $self->render_template( $PATH_TRANSLATED, $REQUEST_URI, $content );
}

sub render_msg_response {
    my ($self) = @_;
    my $msg =
         $self->{cgi}->param('msg')
      || $self->{cgi}->param('aclmsg')
      || $self->{cgi}->param('afsmsg');
    my $errmsg =
         $self->{cgi}->param('errmsg')
      || $self->{cgi}->param('aclerrmsg')
      || $self->{cgi}->param('afserrmsg');
    my %jsondata = ();
    my $p        = 1;
    my @params   = ();
    while ( $self->{cgi}->param( 'p' . ( $p++ ) ) ) {
        push @params, $self->{cgi}->escapeHTML($_);
    }
    if ($msg) {
        $jsondata{message} = sprintf $self->tl( 'msg_' . $msg ), @params;
    }

    if ($errmsg) {
        $jsondata{error} = sprintf $self->tl( 'msg_' . $errmsg ), @params;
    }
    require JSON;
    return ( JSON->new()->encode( \%jsondata ), 'application/json' );
}
1;
