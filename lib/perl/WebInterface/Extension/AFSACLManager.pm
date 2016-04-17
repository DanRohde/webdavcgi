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
# allow_afsaclchanges - (dis)allows AFS ACL changes
# template - default template
# disable_fileactionpopup - disables popup menu entry
# disable_apps - disables apps entry
# ptscmd - path to the pts command (default: /usr/bin/pts)

package WebInterface::Extension::AFSACLManager;

use strict;
use warnings;
our $VERSION = '2.0';

use base qw( WebInterface::Extension );

use CGI::Carp;

#use JSON;

use DefaultConfig
  qw( $PATH_TRANSLATED $REMOTE_USER $REQUEST_URI $BACKEND %BACKEND_CONFIG %EXTENSION_CONFIG );
use HTTPHelper qw( print_compressed_header_and_content );

use WebInterface::Extension::AFSHelper
  qw( exec_cmd exec_ptscmd read_afs_group_list
  is_valid_afs_group_name is_valid_afs_username );

use vars qw( %_CACHE );

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw( css locales javascript gethandler posthandler );
    if ( !$self->config( 'disable_fileactionpopup', 0 ) ) {
        push @hooks, 'fileactionpopup';
    }
    if ( !$self->config( 'disable_apps', 0 ) ) { push @hooks, 'apps'; }

    $self->{ptscmd} = $self->config( 'ptscmd', '/usr/bin/pts' );
    $EXTENSION_CONFIG{AFSACLManager}{allow_afsaclchanges} =
      $EXTENSION_CONFIG{AFSACLManager}{allow_afsaclchanges}
      // 1;    # default is 1 (allowed)
    $hookreg->register( \@hooks, $self );
    return $self;
}

sub handle_hook_fileactionpopup {
    my ( $self, $config, $params ) = @_;
    return {
        action   => 'afsaclmanager',
        label    => 'afs',
        title    => 'afs',
        path     => $params->{path},
        type     => 'li',
        classes  => 'sel-noneorone sel-dir sep',
        template => $self->config( 'template', 'afsaclmanager' )
    };
}

sub handle_hook_apps {
    my ( $self, $config, $params ) = @_;
    return $self->handle_apps_hook( $self->{cgi},
        'afsaclmanager sel-noneorone sel-dir',
        'afs', 'afs' );
}

sub handle_hook_gethandler {
    my ( $self, $config, $params ) = @_;
    my $ajax = $self->{cgi}->param('ajax') // q{};
    my $content;
    my $contenttype = 'text/html';
    if ( $ajax eq 'getAFSACLManager' ) {
        $content = $self->_render_afs_acl_manager(
            $PATH_TRANSLATED,
            $REQUEST_URI,
            $self->{cgi}->param('template')
              || $self->config( 'template', 'afsaclmanager' )
        );
    }
    elsif ( $ajax eq '_search_afs_user_or_group_entry' ) {
        $content =
          $self->_search_afs_user_or_group_entry( $self->{cgi}->param('term') );
        $contenttype = 'application/json';

    }
    if ($content) {
        delete $_CACHE{$self}{$PATH_TRANSLATED};
        print_compressed_header_and_content( '200 OK', $contenttype,
            $content, 'Cache-Control: no-cache, no-store',
            $self->get_cookies() );
        return 1;
    }

    return 0;
}

sub handle_hook_posthandler {
    my ( $self, $config, $params ) = @_;
    if (   $self->config( 'allow_afsaclchanges', 1 )
        && $self->{cgi}->param('saveafsacl') )
    {
        return $self->_do_afs_save_acl();
    }
    return 0;
}

sub exec_template_function {
    my ( $self, $fn, $ru, $func, $param ) = @_;
    my $content;
    if ( $func eq 'afsnormalacllist' ) {
        $content = $self->_render_afs_acl_list( $fn, $ru, 1, $param );
    }
    elsif ( $func eq 'afsnegativeacllist' ) {
        $content = $self->_render_afs_acl_list( $fn, $ru, 0, $param );
    }
    elsif ( $func eq 'checkAFSCallerAccess' ) {
        $content = $self->{backend}->_check_caller_access( $fn, $param );
    }
    return $content
      // $self->SUPER::exec_template_function( $fn, $ru, $func, $param );
}

sub _search_afs_user_or_group_entry {
    my ( $self, $term ) = @_;
    my $result = [];

    #push @{$result}, @{$self->searchAFSUser($term,undef,20)} unless $term=~/:/;
    my @groups =
      grep { /\Q$term\E/xmsi }
      @{ read_afs_group_list( $self->{ptscmd}, $PATH_TRANSLATED, $REMOTE_USER )
      };
    if ( $#{$result} + $#groups >= 10 ) { splice @groups, 9 - $#{$result}; }
    push @{$result}, sort @groups;
    require JSON;
    return JSON->new()->encode( { result => $result } );
}

#sub searchAFSUser {
#       my ($self, $term,$listlimit, $searchlimit) = @_;
#       my @ret = ();
#       my $counter = 0;
#       setpwent();
#       while (my @ent = getpwent()) {
#               push @ret, $ent[0] if !$term || ($ent[0] =~ /^\Q$term\E/i || $ent[6] =~ /\Q$term\E/i);
#               last if $searchlimit && $#ret+1 >= $searchlimit;
#               $counter++;
#               last if $listlimit && $counter >= $listlimit;
#       }
#       endpwent();
#       return \@ret;
#}
sub _render_afs_acl_manager {
    my ( $self, $fn, $ru, $tmplfile ) = @_;
    my $content = q{};
    if ( $self->{backend}->_get_caller_access($fn) eq q{} ) {
        $content = $self->{cgi}
          ->div( { -title => $self->tl('afs') }, $self->tl('afsnorights') );
    }
    else {
        $content =
          $self->render_template( $fn, $ru, $self->read_template($tmplfile) );
        my $stdvars = {
            afsaclscurrentfolder => sprintf(
                $self->tl('afsaclscurrentfolder'),
                $self->quote_ws(
                    $self->{cgi}->escapeHTML(
                        uridecode( $self->{backend}->basename($ru) )
                    )
                ),
                $self->quote_ws( $self->{cgi}->escapeHTML( uridecode($ru) ) )
            ),
        };
        $content =~ s{\$(\w+)}{$stdvars->{$1} // q{}}exmsg;
    }
    return $content;
}

sub _read_afs_acls {
    my ( $self, $fn, $ru ) = @_;
    return $_CACHE{$self}{$fn}{afsacls} if exists $_CACHE{$self}{$fn}{afsacls};

    $fn = $self->{backend}->resolveVirt($fn);
    $fn =~ s/(["\$\\])/\\$1/xmsg;

    my @lines = @{
        exec_ptscmd(
            sprintf q{%s listacl "%s"}, $BACKEND_CONFIG{$BACKEND}{fscmd},
            $fn
        )
    };
    shift @lines;
    my @entries;
    my $ispositive = 1;

    foreach my $line (@lines) {
        next if $line =~ /^\s*$/xms;    # skip empty lines
        if ( $line =~ /^(Normal|Negative) rights:/xms ) {
            $ispositive = $line !~ /^Negative/xms;
        }
        else {
            my ( $user, $aright ) = split /\s+/xms, $line;
            push @entries,
              { user => $user, right => $aright, ispositive => $ispositive };
        }
    }

    $_CACHE{$self}{$fn}{afsacls} = \@entries;
    return \@entries;
}

sub _render_afs_acl_entries {
    my ( $self, $entries, $positive, $tmpl, $disabled ) = @_;
    my $content    = q{};
    my $prohiregex = '^('
      . join( q{|},
        map { $_ // '__undef__' }
          @{ $self->config( 'prohibit_afs_acl_changes_for', [q{^$}] ) } )
      . ')$';
    foreach my $entry (
        sort { $a->{user} cmp $b->{user} || -( $a->{right} cmp $b->{right} ) }
        @{$entries} )
    {
        next if $entry->{ispositive} != $positive;
        my $t = $tmpl;
        $t =~ s/\$entry/$entry->{user}/xmsg;
        $t =~
s/\$checked[(](\w)[)]/$entry->{right}=~m{$1}xms?'checked="checked"':q{}/exmsg;
        $t =~
s/\$readonly/$entry->{user}=~m{$prohiregex}xms ? 'readonly="readonly"' : q{}/exmsg;
        $t =~
s/\$disabled/$self->config('allow_afsaclchanges',1) && !$disabled ? q{} : 'disabled="disabled"'/exmsg;
        $content .= $t;
    }
    return $content;
}

sub _render_afs_acl_list {
    my ( $self, $fn, $ru, $positive, $tmplfile ) = @_;
    return $self->render_template(
        $fn, $ru,
        $self->_render_afs_acl_entries(
            $self->_read_afs_acls( $fn, $ru ),
            $positive,
            $self->read_template($tmplfile),
            !$self->{backend}->_check_caller_access( $fn, 'a' )
        )
    );
}

sub _is_valid_afs_acl {
    my ( $self, $acl ) = @_;
    return $acl =~ /^[rlidwka]+$/xms;
}

sub _build_afs_setacl_param {
    my ($self) = @_;
    my ( $pacls, $nacls ) = ( q{}, q{} );
    my $adp = $BACKEND_CONFIG{$BACKEND}{allowdottedprincipals};
    foreach my $param ( $self->{cgi}->param() ) {
        my $value = join q{}, $self->get_cgi_multi_param($param);
        if ( $param =~ /^up(?:\[([^\]]+)\])?$/xms ) {
            my $u = $1 // $self->{cgi}->param('up_add');
            if (
                (
                       is_valid_afs_username( $u, $adp )
                    || is_valid_afs_group_name( $u, $adp )
                )
                && $self->_is_valid_afs_acl($value)
              )
            {
                $pacls .= sprintf q{"%s" "%s" }, $u, $value;
            }
        }
        elsif ( $param =~ /^un(?:\[([^\]]+)\])/xms ) {
            my $u = $1 // $self->{cgi}->param('un_add');
            if (
                (
                       is_valid_afs_username( $u, $adp )
                    || is_valid_afs_group_name( $u, $adp )
                )
                && $self->_is_valid_afs_acl($value)
              )
            {
                $nacls .= sprintf q{"%s" "%s" }, $u, $value;
            }
        }
    }
    return ( $pacls, $nacls );
}

sub _do_afs_fs_setacl_cmd {
    my ( $self, $fn, $pacls, $nacls ) = @_;
    my ( $msg, $errmsg, $msgparam );
    my $output = q{};
    if ( $pacls ne q{} ) {
        my $cmd;
        $fn =~ s/(["\$\\])/\\$1/xmsg;
        $cmd = sprintf
          '%s setacl -dir "%s" -acl %s -clear 2>&1',
          $BACKEND_CONFIG{$BACKEND}{fscmd},
          $self->{backend}->resolveVirt($fn), $pacls;
        $output = exec_cmd($cmd);
        if ( $nacls ne q{} ) {
            $cmd = sprintf
              '%s setacl -dir "%s" -acl %s -negative 2>&1',
              $BACKEND_CONFIG{$BACKEND}{fscmd},
              $self->{backend}->resolveVirt($fn), $nacls;
            $output .= exec_cmd($cmd);
        }
    }
    else { $output = $self->tl('empty normal rights'); }
    if ( $output eq q{} ) {
        $msg      = 'afsaclchanged';
        $msgparam = [ $self->{cgi}->escapeHTML($pacls),
            $self->{cgi}->escapeHTML($nacls) ];
    }
    else {
        $errmsg = 'afsaclnotchanged';
        $msgparam =
          [ $self->_formatting_html( $self->{cgi}->escapeHTML($output) ) ];
    }
    return ( $msg, $errmsg, $msgparam );
}

sub _formatting_html {
    my ( $self, $text ) = @_;
    $text =~ s{\r?\n}{<br/>}xmsg;
    return $text;
}

sub _do_afs_fs_setacl_cmd_recursive {
    my ( $self, $fn, $pacls, $nacls ) = @_;
    $fn .= $fn !~ m{/$}xms && $self->{backend}->isDir($fn) ? q{/} : q{};
    my ( $msg, $errmsg, $msgparam );
    foreach my $f ( @{ $self->{backend}->readDir($fn) } ) {
        my $nf = "$fn$f";
        if (   $self->{backend}->isDir($nf)
            && !$self->{backend}->isLink($nf)
            && $self->{backend}->_check_caller_access( $nf, 'a', 'a' ) )
        {
            $nf .= q{/};
            ( $msg, $errmsg, $msgparam ) =
              $self->_do_afs_fs_setacl_cmd( $nf, $pacls, $nacls );
            ( $msg, $errmsg, $msgparam ) =
              $self->_do_afs_fs_setacl_cmd_recursive( $nf, $pacls, $nacls );
        }
    }
    return ( $msg, $errmsg, $msgparam );
}

sub _do_afs_save_acl {
    my ( $self, $redirtarget ) = @_;
    my ( $pacls, $nacls ) = ( q{}, q{} );
    my ( $msg, $errmsg, $msgparam );

    ( $pacls, $nacls ) = $self->_build_afs_setacl_param();
    ( $msg, $errmsg, $msgparam ) =
      $self->_do_afs_fs_setacl_cmd( $PATH_TRANSLATED, $pacls, $nacls );

    if ( $self->{cgi}->param('setafsaclrecursive') ) {
        $self->_do_afs_fs_setacl_cmd_recursive( $PATH_TRANSLATED, $pacls,
            $nacls );
    }

    my %jsondata = ();
    if ($errmsg) {
        $jsondata{error} = sprintf $self->tl( 'msg_' . $errmsg ),
          $msgparam ? @{$msgparam} : q{};
    }
    if ($msg) {
        $jsondata{message} = sprintf $self->tl( 'msg_' . $msg ),
          $msgparam ? @{$msgparam} : q{};
    }
    require JSON;
    return print_compressed_header_and_content(
        '200 OK', 'application/json',
        JSON->new()->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store',
        $self->get_cookies()
    );
}

sub uridecode {
    my ($txt) = @_;
    $txt =~ s/\%([[:alnum:]]{2})/chr(hex($1))/exmsig;
    return $txt;
}
1;
