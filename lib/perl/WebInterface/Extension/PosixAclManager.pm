#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2014 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
# SETUP:
# getfacl - getfacl path (default: /usr/bin/getfacl)
# setfacl - setfacl path (default: /usr/bin/setfacl)

package WebInterface::Extension::PosixAclManager;

use strict;
use warnings;
our $VERSION = '2.0';

use base qw( WebInterface::Extension );

use JSON;

use DefaultConfig qw( $PATH_TRANSLATED $REQUEST_URI %EXTENSION_CONFIG );
use HTTPHelper qw( print_compressed_header_and_content );

sub init {
    my ( $self, $hookreg ) = @_;

    $self->setExtension('PosixAclManager');

    $hookreg->register(
        [
            'css',        'javascript',
            'gethandler', 'fileactionpopup',
            'apps',       'locales',
            'posthandler'
        ],
        $self
    );

    ## set some defaults:
    $self->{getfacl} =
      $EXTENSION_CONFIG{PosixAclManager}{getfacl} || '/usr/bin/getfacl';
    $self->{setfacl} =
      $EXTENSION_CONFIG{PosixAclManager}{setfacl} || '/usr/bin/setfacl';
    return $self;
}

sub handle {
    my ( $self, $hook, $config, $params ) = @_;
    if ( my $ret = $self->SUPER::handle( $hook, $config, $params ) ) {
        return $ret;
    }
    if ( $hook eq 'fileaction' ) {
        return {
            action   => 'pacl',
            disabled => 0,
            label    => 'pacl',
            path     => $params->{path}
        };
    }
    if ( $hook eq 'fileactionpopup' ) {
        return {
            action   => 'pacl',
            disabled => 0,
            label    => 'pacl',
            path     => $params->{path},
            type     => 'li',
            classes  => 'sel-noneorone'
        };
    }
    if ( $hook eq 'apps' ) {
        return $self->handleAppsHook( $self->{cgi},
            'pacl listaction sel-noneorone disabled', 'pacl' );
    }
    if ( $hook eq 'posthandler' ) {
        if (   $self->{cgi}->param('ajax')
            && $self->{cgi}->param('ajax') eq 'getPosixAclManager' )
        {
            return $self->_render_posix_acl_manager();
        }
        if (   $self->{cgi}->param('action')
            && $self->{cgi}->param('action') eq 'pacl_update' )
        {
            return $self->_handle_acl_update();
        }
        if (   $self->{cgi}->param('ajax')
            && $self->{cgi}->param('ajax') eq 'searchUserOrGroupEntry' )
        {
            return $self->_handle_user_or_group_entry_search();
        }
    }
    return 0;
}

sub _quote_param {
    my ( $self, $v ) = @_;
    $v =~ s{([\$"\\])}{\\$1}xmsg;
    return $v;
}

sub _handle_acl_update {
    my ($self) = @_;
    my $c = $self->{cgi};
    my $qfn =
      $self->_quote_param( $self->{backend}->resolveVirt($PATH_TRANSLATED) );
    my $recursive = $c->param('recursive') eq 'yes' ? '-R' : q{};
    my $output = q{};
    foreach my $param ( $c->param() ) {
        my $val = join q{}, $c->param($param);
        my $cmd = undef;
        if (   $val =~ /^[rwxM\-]+$/xms
            && $param =~ /^acl:([[:lower:]]+:[^"\s]*)$/xmsi )
        {
            my $e = $self->_quote_param($1);
            if ( $val eq 'M' ) {
                if ( $e =~ /^\S+:$/xms ) {
                    $cmd = sprintf '%s %s -m "%s:"- -- "%s"',
                      $self->{setfacl}, $recursive, $e, $qfn;
                }
                else {
                    $cmd = sprintf '%s %s -x "%s" -- "%s"',
                      $self->{setfacl}, $recursive, $e, $qfn;
                }
            }
            else {
                $val =~ s/M//xmsg;
                if ( $val =~ /---/xms ) {
                    $cmd = sprintf '%s %s -m "%s:-" -- "%s"',
                      $self->{setfacl}, $recursive, $e, $qfn;
                }
                else {
                    $cmd = sprintf '%s %s -m "%s:%s" -- "%s"',
                      $self->{setfacl}, $recursive, $e, $val, $qfn;
                }
            }
        }
        elsif ( $param eq 'newacl' && $val =~ /^[[:lower:]]+:[^"\s]*$/xmsi ) {
            my $e =
              $self->_quote_param( join q{}, $c->param('newaclpermissions') );
            if ( $e && $e =~ /^[rwx\-]+$/xms ) {
                if ( $e =~ /---/xms ) {
                    $cmd = sprintf '%s %s -m "%s:-" -- "%s"',
                      $self->{setfacl}, $recursive, $val, $qfn;
                }
                else {
                    $cmd = sprintf '%s %s -m "%s:%s" -- "%s"',
                      $self->{setfacl}, $recursive, $val, $e, $qfn;
                }
            }
        }
        if ( defined $cmd ) {
            $self->{config}->{debug}->("_handle_acl_update: cmd=$cmd");
            $output .= qx@$cmd 2>&1@;

#$output.= $?==-1 ? 'command failed' : ( $? & 127 ? 'child died with '.($? & 127) : 'command failed with exit code '.($? >>8)) if $?;
        }
    }
    my %jsondata;
    if ( $output ne q{} ) {
        $jsondata{error} = $c->escapeHTML($output);
    }
    else {
        $jsondata{msg} = sprintf
          $self->tl('pacl_msg_success'),
          $c->escapeHTML( $c->param('filename') );
    }
    print_compressed_header_and_content(
        '200 OK', 'application/json',
        JSON::encode_json( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}

sub _render_posix_acl_manager {
    my ($self)  = @_;
    my $content = q{};
    my $c       = $self->{cgi};

    my @defaultpermissions = qw( r w x --- );

    my $f = $c->param('files') // q{.};
    if ( $f eq q{} ) { $f = q{.}; }
    my $fn = $self->_normalize_filename($f);

    $content .= $c->start_form(
        -method => 'POST',
        -action => "$REQUEST_URI$f",
        -class  => 'pacl form'
    );
    $content .= $c->hidden( -name => 'filename', -value => $f )
      . $c->hidden( -name => 'action', -value => 'pacl_update' );
    $content .= $c->start_table( { -class => 'pacl table' } );

    $content .= $c->Tr(
        $c->th(
            {
                -class   => 'posixaclmngr title',
                -title   => $self->_get_stat_info($fn),
                -colspan => 2
            },
            $c->escapeHTML($f)
        )
    );

#$content.= $c->Tr($c->th($self->tl('pacl_entry')).$c->th($self->tl('pacl_rights')));
    foreach my $e ( @{ $self->_get_acl_entries($fn) } ) {
        my $row = q{};
        $e->{uid} //= q{};
        $row .= $c->td( $e->{type} . q{:} . $e->{uid} );
        my $permentry = q{};
        my @perms = $e->{permission} eq '---' ? ('---') : split //xms,
          $e->{permission};
        $permentry .= $c->checkbox_group(
            -name     => 'acl:' . $e->{type} . q{:} . $e->{uid},
            -values   => \@defaultpermissions,
            -class    => 'permissions',
            -defaults => \@perms
        );
        $permentry .= $c->hidden(
            -name  => 'acl:' . $e->{type} . q{:} . $e->{uid},
            -value => 'M'
        );
        $row .= $c->td($permentry);
        $content .= $c->Tr( { -title => "$e->{type}:$e->{uid}" }, $row );
    }
    $content .= $c->Tr(
        $c->td( $c->textfield( -name => 'newacl', -class => 'pacl newacl' ) ),
        $c->td(
            { -class => 'pacl newaclpermissions' },
            $c->checkbox_group(
                -name   => 'newaclpermissions',
                -class  => 'permissions',
                -values => \@defaultpermissions
            )
        )
    );
    $content .= $c->Tr(
        $c->td(
            $c->checkbox(
                -name  => 'recursive',
                -value => 'yes',
                -label => $self->tl('pacl_recursive')
            )
          )
          . $c->td(
            $c->submit(
                -name  => 'pacl_update',
                -value => $self->tl('pacl_update')
            )
          )
    );
    $content .= $c->end_table() . $c->end_form();
    $content .=
      $c->div( { -class => 'pacl legend' }, $self->tl('pacl_legend') );
    $content .=
      $c->div( { -class => 'template', -id => 'pacl_msg_err_usergroup' },
        $self->tl('pacl_msg_err_usergroup') );
    $content .= $c->div( { -class => 'template', -id => 'pacl_msg_err_perm' },
        $self->tl('pacl_msg_err_perm') );

    print_compressed_header_and_content(
        '200 OK',
        'text/html',
        $c->div(
            { -class => 'pacl manager', -title => $self->tl('pacl') }, $content
        ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}

sub _get_stat_info {
    my ( $self, $fn ) = @_;
    my @stat = $self->{backend}->stat($fn);
    return
        'uid='
      . scalar( getpwuid $stat[4] )
      . " ($stat[4]), gid="
      . scalar( getgrgid $stat[5] )
      . " ($stat[5]), mode="
      . sprintf( "%04o\n", $stat[2] & oct 7777 ) . ' ('
      . $self->mode2str( $fn, $stat[2] ) . ')';
}

sub _handle_user_or_group_entry_search {
    my ($self) = @_;
    my $term   = $self->{cgi}->param('term');
    my $result = [];
    if ($term) {
        if ( $term =~ /^group:(.*)/xmsi ) {
            $result = $self->_search_group_entry(
                $1,
                $EXTENSION_CONFIG{PosixAclManager}{listlimit},
                $EXTENSION_CONFIG{PosixAclManager}{searchlimit}
            );
        }
        else {
            $result = $self->_search_user_entry(
                $term =~ /^user:(.*)/xms ? $1 : $term,
                $EXTENSION_CONFIG{PosixAclManager}{listlimit},
                $EXTENSION_CONFIG{PosixAclManager}{searchlimit}
            );
            if ( $term !~ /^user:(?:.*)/xms ) {
                push @{$result},
                  @{
                    $self->_search_group_entry(
                        $term,
                        $EXTENSION_CONFIG{PosixAclManager}{listlimit},
                        $EXTENSION_CONFIG{PosixAclManager}{searchlimit}
                    )
                  };
            }
        }
    }
    else {
        push @{$result},
          @{
            $self->_search_user_entry(
                $term,
                $EXTENSION_CONFIG{PosixAclManager}{listlimit},
                $EXTENSION_CONFIG{PosixAclManager}{searchlimit}
            )
          },
          @{
            $self->_search_group_entry(
                $term,
                $EXTENSION_CONFIG{PosixAclManager}{listlimit},
                $EXTENSION_CONFIG{PosixAclManager}{searchlimit}
            )
          };
    }
    print_compressed_header_and_content(
        '200 OK', 'application/json',
        JSON::encode_json( { result => $result } ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}

sub _search_user_entry {
    my ( $self, $term, $listlimit, $searchlimit ) = @_;
    my @ret     = ();
    my $counter = 0;
    setpwent;
    while ( my @ent = getpwent ) {
        if ( !$term
            || ( $ent[0] =~ /^\Q$term\E/xmsi || $ent[6] =~ /\Q$term\E/xmsi ) )
        {
            push @ret, "user:$ent[0]";
        }
        if ( $searchlimit && scalar(@ret) >= $searchlimit ) {
            last;
        }
        $counter++;
        if ( $listlimit && $counter >= $listlimit ) {
            last;
        }
    }
    endpwent;
    return \@ret;
}

sub _search_group_entry {
    my ( $self, $term, $listlimit, $searchlimit ) = @_;
    my @ret     = ();
    my $counter = 0;
    setgrent;
    while ( my @ent = getgrent ) {
        if ( !$term || $ent[0] =~ /^\Q$term\E/xmsi ) {
            push @ret, "group:$ent[0]";
        }
        if ( $searchlimit && scalar(@ret) >= $searchlimit ) { last; }
        $counter++;
        if ( $listlimit && $counter >= $listlimit ) { last; }
    }
    endgrent;
    return \@ret;
}

sub _normalize_filename {
    my ( $self, $f ) = @_;
    my $fn = $f;
    $fn =~ s{/$}{}xms;
    $fn =~ s{/[^/]+/[.]{2}$}{}xms;
    return $self->{backend}->resolveVirt( $PATH_TRANSLATED . $fn );
}

sub _get_acl_entries {
    my ( $self, $fn ) = @_;
    if ( open my $g, q{-|}, $self->{getfacl}, q{-c}, q{--}, $fn ) {
        my @rights = ();
        while (<$g>) {
            chomp;
            if (/^\#/xms) { next; }
            if (/^(default:)?([^:]+):([^:]+)?:([rwx\-]+)$/xms) {
                my ( $default, $type, $uid, $permission ) = ( $1, $2, $3, $4 );
                push @rights,
                  {
                    type => ( $default ? $default : q{} ) . $type,
                    uid => $uid,
                    permission => $permission
                  };
            }

        }
        close($g) || carp('Cannot close getfacl command.');
        return \@rights;
    }
    return [];
}
1;
