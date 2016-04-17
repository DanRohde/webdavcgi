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
# disable_fileactionpopup - disables popup menu entry
# disable_apps - disables apps entry
package WebInterface::Extension::Permissions;

use strict;
use warnings;
our $VERSION = '2.0';

use base qw( WebInterface::Extension  );

use DefaultConfig qw( $PATH_TRANSLATED $REQUEST_URI );
use HTTPHelper qw( print_compressed_header_and_content );

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw( css locales javascript gethandler posthandler );
    if ( !$self->config( 'disable_fileactionpopup', 0 ) ) {
        push @hooks, 'fileactionpopup';
    }
    if ( !$self->config( 'disable_apps', 0 ) ) { push @hooks, 'apps'; }

    $hookreg->register( \@hooks, $self );
    return $self;
}

sub handle_hook_fileactionpopup {
    my ( $self, $config, $params ) = @_;
    return {
        action    => 'permissions',
        label     => 'mode',
        title     => 'mode',
        accesskey => 'p',
        path      => $params->{path},
        type      => 'li',
        classes   => 'sep',
        template  => $self->config( 'template', 'permissions' )
    };
}

sub handle_hook_apps {
    my ( $self, $config, $params ) = @_;
    return $self->handle_apps_hook( $self->{cgi}, 'permissions sel-multi',
        'mode', 'mode' );
}

sub handle_hook_gethandler {
    my ( $self, $config, $params ) = @_;
    if ( $self->{cgi}->param('ajax') ) {
        if ( $self->{cgi}->param('ajax') eq 'getPermissionsDialog' ) {
            my $content = $self->_render_permissions_dialog(
                $PATH_TRANSLATED,
                $REQUEST_URI,
                $self->{cgi}->param('template')
                  || $self->config( 'template', 'permissions' )
            );
            print_compressed_header_and_content( '200 OK', 'text/html',
                $content, 'Cache-Control: no-cache, no-store' );
            return 1;
        }
    }
    return 0;
}

sub _check_perm_allowed {
    my ( $self, $p, $r ) = @_;
    my $perms;
    if ( $p eq 'u' ) {
        $perms = join q{}, @{ $self->config( 'user', [qw(r w x s)] ) };
    }
    if ( $p eq 'g' ) {
        $perms = join q{}, @{ $self->config( 'group', [qw(r w x s)] ) };
    }

    if ( $p eq 'o' ) {
        $perms = join q{}, @{ $self->config( 'others', [qw(r w x t)] ) };
    }
    return $perms =~ m/\Q$r\E/xms;
}

sub _render_permissions_dialog {
    my ( $self, $fn, $ru, $tmplfile ) = @_;
    my $content = $self->read_template($tmplfile);
    $content =~
s/\$disabled[(](\w)(\w)[)]/$self->_check_perm_allowed($1,$2) ? q{} : 'disabled="disabled"'/exmsg;
    return $self->render_template( $fn, $ru, $content );
}

sub handle_hook_posthandler {
    my ($self) = @_;

    if ( $self->{cgi}->param('changeperm') ) {
        my ( $msg, $msgparam, $errmsg );
        if ( $self->{cgi}->param('files[]') || $self->{cgi}->param('files') ) {
            my $p_u = join q{}, @{ $self->config( 'user',   [qw(r w x s)] ) };
            my $p_g = join q{}, @{ $self->config( 'group',  [qw(r w x s)] ) };
            my $p_o = join q{}, @{ $self->config( 'others', [qw(r w x t)] ) };
            my $m   = 0;
            foreach my $up ( $self->get_cgi_multi_param('fp_user') ) {
                if ( $up eq 'r' && $p_u =~ /r/xms ) { $m |= oct 400; }
                if ( $up eq 'w' && $p_u =~ /w/xms ) { $m |= oct 200; }
                if ( $up eq 'x' && $p_u =~ /x/xms ) { $m |= oct 100; }
                if ( $up eq 's' && $p_u =~ /s/xms ) { $m |= oct 4000; }
            }
            foreach my $gp ( $self->get_cgi_multi_param('fp_group') ) {
                if ( $gp eq 'r' && $p_g =~ /r/xms ) { $m |= oct 40; }
                if ( $gp eq 'w' && $p_g =~ /w/xms ) { $m |= oct 20; }
                if ( $gp eq 'x' && $p_g =~ /x/xms ) { $m |= oct 10; }
                if ( $gp eq 's' && $p_g =~ /s/xms ) { $m |= oct 2000; }
            }
            foreach my $op ( $self->get_cgi_multi_param('fp_others') ) {
                if ( $op eq 'r' && $p_o =~ /r/xms ) { $m |= 4; }
                if ( $op eq 'w' && $p_o =~ /w/xms ) { $m |= 2; }
                if ( $op eq 'x' && $p_o =~ /x/xms ) { $m |= 1; }
                if ( $op eq 't' && $p_o =~ /t/xms ) { $m |= oct 1000; }
            }

            $msg = 'changeperm';
            $msgparam = sprintf 'p1=%04o', $m;
            my @files =
                $self->{cgi}->param('files[]')
              ? $self->get_cgi_multi_param('files[]')
              : $self->get_cgi_multi_param('files');
            foreach my $file (@files) {
                if ( $file eq q{.} ) { $file = q{}; }
                $self->{backend}->changeFilePermissions(
                    $PATH_TRANSLATED . $file,
                    $m,
                    scalar $self->{cgi}->param('fp_type'),
                    $self->config( 'allow_changepermrecursive', 1 )
                      && scalar $self->{cgi}->param('fp_recursive')
                );
            }
        }
        else {
            $errmsg = 'chpermnothingerr';
        }
        my %jsondata = ();
        if ($errmsg) {
            $jsondata{error} = sprintf $self->tl("msg_$errmsg"), $msgparam;
        }
        if ($msg) {
            $jsondata{message} = sprintf $self->tl("msg_$msg"), $msgparam;
        }
        require JSON;
        print_compressed_header_and_content(
            '200 OK',
            'application/json',
            JSON->new()->encode( \%jsondata ),
            'Cache-Control: no-cache, no-store'
        );
        return 1;
    }
    return 0;
}
1;
