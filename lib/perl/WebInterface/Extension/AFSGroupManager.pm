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
# disallow_afsgroupchanges - disallows afs group changes
# ptscmd - sets the AFS pts command (default: /usr/bin/pts)
# disable_fileactionpopup - disables fileaction entry in popup menu
# disable_apps - disables sidebar menu entry
# template - sets the template (default: afsgroupmanager)

package WebInterface::Extension::AFSGroupManager;

use strict;
use warnings;
our $VERSION = '2.0';

use base qw( WebInterface::Extension  );

use CGI::Carp;
#use JSON;

use DefaultConfig
  qw( $PATH_TRANSLATED $REMOTE_USER $REQUEST_URI $BACKEND %BACKEND_CONFIG );
use HTTPHelper qw( print_compressed_header_and_content );

use WebInterface::Extension::AFSHelper
  qw( read_afs_group_list exec_ptscmd exec_cmd 
      is_valid_afs_group_name is_valid_afs_username );

use vars qw( %_CACHE );

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw(css locales javascript gethandler posthandler);
    if ( !$self->config( 'disable_fileactionpopup', 0 ) ) {
        push @hooks, 'fileactionpopup';
    }
    if ( !$self->config( 'disable_apps', 0 ) ) { push @hooks, 'apps'; }
    $self->{ptscmd} = $self->config( 'ptscmd', '/usr/bin/pts' );
    $hookreg->register( \@hooks, $self );
    return $self;
}

sub handle {
    my ( $self, $hook, $config, $params ) = @_;
    if ( my $ret = $self->SUPER::handle( $hook, $config, $params ) ) {
        return $ret;
    }

    if ( $hook eq 'fileactionpopup' ) {
        return {
            action   => 'afsgroupmngr',
            classes  => 'listaction',
            label    => 'afsgroup',
            title    => 'afsgroup',
            path     => $params->{path},
            type     => 'li',
            template => $self->config( 'template', 'afsgroupmanager' )
        };
    }
    if ( $hook eq 'apps' ) {
        return $self->handleAppsHook( $self->{cgi}, 'afsgroupmngr', 'afsgroup',
            'afsgroup' );
    }
    if ( $hook eq 'gethandler' ) {
        my $ajax = $self->{cgi}->param('ajax') // q{};
        if ( $ajax eq 'getAFSGroupManager' ) {
            my $content = $self->_render_afs_group_manager(
                $PATH_TRANSLATED,
                $REQUEST_URI,
                $self->{cgi}->param('template')
                  || $self->config( 'template', 'afsgroupmanager' )
            );
            print_compressed_header_and_content( '200 OK', 'text/html',
                $content, 'Cache-Control: no-cache, no-store' );
            delete $_CACHE{$self}{$PATH_TRANSLATED};
            return 1;
        }
    }
    if (
        $hook eq 'posthandler'
        && $self->_check_cgi_param_list(
            qw(afschgrp afscreatenewgrp afsdeletegrp afsrenamegrp afsaddusr afsremoveusr)
        )
      )
    {
        return $self->_do_afs_group_actions();
    }
    return 0;
}

sub _check_cgi_param_list {
    my ( $self, @params ) = @_;
    foreach my $param (@params) {
        return 1 if $self->{cgi}->param($param);
    }
    return 0;
}

sub _render_afs_group_list {
    my ( $self, $fn, $ru, $tmplfile ) = @_;
    my $content = q{};
    my $tmpl =
      $self->render_template( $fn, $ru, $self->read_template($tmplfile) );
    foreach my $group (
        sort @{ read_afs_group_list( $self->{ptscmd}, $fn, $REMOTE_USER ) } )
    {
        my $t = $tmpl;
        $t =~ s/\$afsgroupname/$group/xmsg;
        $content .= $t;
    }
    return $content;
}

sub _read_afs_members {
    my ( $self, $grp ) = @_;
    if ( !defined $grp ) { return []; }
    return exec_ptscmd(qq{$self->{ptscmd} members '$grp'});
}

sub _render_afs_member_list {
    my ( $self, $fn, $ru, $tmplfile ) = @_;
    my $content = q{};
    my $tmpl    = $self->read_template($tmplfile);
    my $afsgrp  = $self->{cgi}->param('afsgrp');
    foreach my $user ( sort @{ $self->_read_afs_members($afsgrp) } ) {
        my $t = $tmpl;
        $t =~ s/\$afsmember/$user/xmsg;
        $t =~ s/\$afsgroupname/$afsgrp/xmsg;
        $content .= $t;
    }
    return $self->render_template( $fn, $ru, $content );
}

sub exec_template_function {
    my ( $self, $fn, $ru, $func, $param ) = @_;
    my $content;
    if ( $func eq 'afsgrouplist' ) {
        $content = $self->_render_afs_group_list( $fn, $ru, $param );
    }
    elsif ( $func eq 'afsmemberlist' ) {
        $content = $self->_render_afs_member_list( $fn, $ru, $param );
    }
    return $content
      // $self->SUPER::exec_template_function( $fn, $ru, $func, $param );
}

sub _render_afs_group_manager {
    my ( $self, $fn, $ru, $tmplfile ) = @_;
    my $content =
      $self->render_template( $fn, $ru, $self->read_template($tmplfile) );
    my $stdvars = {
        afsgroupeditorhead => sprintf(
            $self->tl('afsgroups'),
            $self->{cgi}->escapeHTML($REMOTE_USER)
        ),
        afsmembereditorhead => scalar $self->{cgi}->param('afsgrp')
        ? sprintf(
            $self->tl('afsgrpusers'),
            $self->{cgi}->escapeHTML( scalar $self->{cgi}->param('afsgrp') )
          )
        : q{},
        user => $REMOTE_USER,
    };
    $content =~ s{\$(\w+)}{$stdvars->{$1} // "\$${1}"}exmsg;
    return $content;
}

sub _print_json {
    my ( $self, $msg, $msgparam, $errmsg ) = @_;
    my %jsondata = ();
    my @params =
      $msgparam ? map { $self->{cgi}->escapeHTML($_) } @{$msgparam} : ();
    if ($errmsg) {
        $jsondata{error} = sprintf $self->tl("msg_$errmsg"), @params;
    }
    if ($msg) { $jsondata{message} = sprintf $self->tl("msg_$msg"), @params; }
    require JSON;
    print_compressed_header_and_content(
        '200 OK', 'application/json',
        JSON->new()->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}

sub _do_afs_deletegrp {
    my ( $self, $grp ) = @_;
    if ( !is_valid_afs_group_name($grp,$BACKEND_CONFIG{$BACKEND}{allowdottedprincipals}) ) {
        return $self->_print_json( undef, undef, 'afsgrpnothingsel' );
    }
    my $output = exec_cmd(qq{$self->{ptscmd} delete "$grp" 2>&1});
    if ( $output ne q{} ) {
        return $self->_print_json( undef, [ $grp, $output ],
            'afsgrpdeletefailed' );
    }
    return $self->_print_json( 'afsgrpdeleted', [$grp] );
}

sub _do_afs_createnewgrp {
    my ($self) = @_;
    my $grp = $self->{cgi}->param('afsnewgrp');
    $grp =~ s/(?:^\s+|\s+$)//xmsg;
    if ( !is_valid_afs_group_name($grp,$BACKEND_CONFIG{$BACKEND}{allowdottedprincipals}) ) {
        return $self->_print_json( undef, undef, 'afsgrpnogroupnamegiven' );
    }
    my $output = exec_cmd(qq{$self->{ptscmd} creategroup "$grp" 2>&1});
    if ( $output ne q{} && $output !~ /^group.\Q$grp\E.has.id/xmsi ) {
        return $self->_print_json( undef, [ $grp, $output ],
            'afsgrpcreatefailed' );
    }
    return $self->_print_json( 'afsgrpcreated', [$grp] );
}

sub _do_afs_renamegrp {
    my ( $self, $grp ) = @_;
    my $ngrp = $self->{cgi}->param('afsnewgrpname') || q{};
    if ( !is_valid_afs_group_name($grp,$BACKEND_CONFIG{$BACKEND}{allowdottedprincipals}) ) {
        return $self->_print_json( undef, [$ngrp], 'afsgrpnothingsel' );
    }
    if ( !is_valid_afs_group_name($ngrp,$BACKEND_CONFIG{$BACKEND}{allowdottedprincipals}) ) {
        return $self->_print_json( undef, [$grp], 'afsnonewgroupnamegiven' );
    }
    my $output = exec_cmd(
        qq@$self->{ptscmd} rename -oldname "$grp" -newname "$ngrp" 2>&1@);
    if ( $output ne q{} ) {
        return $self->_print_json( undef, [ $grp, $ngrp, $output ],
            'afsgrprenamefailed' );
    }
    return $self->_print_json( 'afsgrprenamed', [ $grp, $ngrp ] );
}

sub _do_afs_removeusr {
    my ($self) = @_;
    my $grp = $self->{cgi}->param('afsselgrp') || q{};
    if ( !is_valid_afs_group_name($grp,$BACKEND_CONFIG{$BACKEND}{allowdottedprincipals}) ) {
        return $self->_print_json( undef, undef, 'afsgrpnothingsel' );
    }
    my @users = ();
    my @afsusr =
        $self->{cgi}->param('afsusr[]')
      ? $self->{cgi}->param('afsusr[]')
      : $self->{cgi}->param('afsusr');
    my $adp = $BACKEND_CONFIG{$BACKEND}{allowdottedprincipals};
    foreach (@afsusr) {
        if (   is_valid_afs_username($_, $adp) || is_valid_afs_group_name($_, $adp) ) {
            push @users, $_;
        }
    }
    if ( scalar(@users) == 0 ) {
        return $self->_print_json( undef, [$grp], 'afsusrnothingsel' );
    }
    my $userstxt = q{"} . join( q{" "}, @users ) . q{"};
    my $output = exec_cmd(
        qq{$self->{ptscmd} removeuser -user $userstxt -group "$grp" 2>&1});
    if ( $output ne q{} ) {
        return $self->_print_json( undef,
            [ join( ', ', @users ), $grp, $output ],
            'afsusrremovefailed' );
    }
    return $self->_print_json( 'afsuserremoved',
        [ join( ', ', @users ), $grp ] );
}

sub _do_afs_addusr {
    my ($self) = @_;
    my $grp = $self->{cgi}->param('afsselgrp') || q{};
    if ( !is_valid_afs_group_name($grp,$BACKEND_CONFIG{$BACKEND}{allowdottedprincipals}) ) {
        return $self->_print_json( undef, undef, 'afsgrpnothingsel' );
    }
    my $adp = $BACKEND_CONFIG{$BACKEND}{allowdottedprincipals};
    my @users = ();
    foreach ( split /\s+/xms, $self->get_cgi_multi_param('afsaddusers') ) {
        if (   is_valid_afs_username($_, $adp) || is_valid_afs_group_name($_, $adp ) ) {
            push @users, $_;
        }
    }
    if ( scalar(@users) == 0 ) {
        return $self->_print_json( undef, [$grp], 'afsnousersgiven' );
    }
    my $userstxt = q{"} . join( q{" "}, @users ) . q{"};
    my $output =
      exec_cmd(qq{$self->{ptscmd} adduser -user $userstxt -group "$grp" 2>&1});
    if ( $output ne q{} ) {
        return $self->_print_json( undef,
            [ $self->{cgi}->param('afsaddusers'), $grp, $output ],
            'afsadduserfailed' );
    }
    return $self->_print_json( 'afsuseradded', [ join( ', ', @users ), $grp ] );
}

sub _do_afs_chgrp {
    my ($self) = @_;
    if ( !$self->{cgi}->param('afsgrp') ) {
        return $self->_print_json( undef, undef, 'afsgrpnothingsel' );
    }
    return $self->_print_json( q{},
        is_valid_afs_group_name( $self->{cgi}->param('afsgrp'), $BACKEND_CONFIG{$BACKEND}{allowdottedprincipals} )
        ? [ $self->{cgi}->param('afsgrp') ]
        : undef );
}

sub _do_afs_group_actions {
    my ($self) = @_;
    my ( $msg, $errmsg, $msgparam );
    my $grp = $self->{cgi}->param('afsgrp') // q{};
    if ( $self->{cgi}->param('afschgrp') ) {
        return $self->_do_afs_chgrp();
    }
    if ( $self->config('disallow_afsgroupchanges') ) {
        return $self->_print_json();
    }
    if ( $self->{cgi}->param('afsdeletegrp') ) {
        return $self->_do_afs_deletegrp($grp);
    }
    if ( $self->{cgi}->param('afscreatenewgrp') ) {
        return $self->_do_afs_createnewgrp();
    }
    if ( $self->{cgi}->param('afsrenamegrp') ) {
        return $self->_do_afs_renamegrp($grp);
    }
    if ( $self->{cgi}->param('afsremoveusr') ) {
        return $self->_do_afs_removeusr();
    }
    if ( $self->{cgi}->param('afsaddusr') ) {
        return $self->_do_afs_addusr();
    }
    return $self->_print_json();
}
1;
