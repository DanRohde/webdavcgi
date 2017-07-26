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
# ooffice - path to ooffice (default: /usr/bin/soffice)

package WebInterface::Extension::ODFConverter;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( WebInterface::Extension  );

use English qw( -no_match_vars );
use File::Temp qw( tempdir );

#use JSON;
use CGI::Carp;

use DefaultConfig qw( $PATH_TRANSLATED $REMOTE_USER );
use HTTPHelper qw( print_compressed_header_and_content );
use FileUtils qw( rcopy );

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw(
      css      locales javascript fileactionpopup
      fileattr posthandler appsmenu
    );

    $self->{ooffice} = $self->config( 'ooffice', '/usr/bin/soffice' );

    if ( -x $self->{ooffice} ) { $hookreg->register( \@hooks, $self ); }

    $self->{oofficeparams} = $self->config(
        'oofficeparams',
        [
            '--headless', '--invisible', '--convert-to', '%targetformat',
            '--outdir',   '%targetdir',  '%sourcefile'
        ]
    );

    $self->{types} =
      [qw(odt odp ods doc docx ppt pptx xls xlsx csv html pdf swf)];
    $self->{typesregex} =
      q{(?:} . join( q{|}, @{ $self->{types} } ) . q{)};
    $self->{groups} = {
        t => [qw(odt doc docx pdf html)],
        p => [qw(odp ppt pptx pdf swf)],
        s => [qw(ods xls xlsx csv pdf html)],
    };
    $self->{unconvertible} = q{(?:swf|unknown)};

    $self->{popupcss} = '<style>';
    foreach my $group ( keys %{ $self->{groups} } ) {
        my $groupsregex =join q{|}, @{ $self->{groups}{$group} };
        foreach ( @{ $self->{groups}{$group} } ) {
            $self->{memberof}{$_} .= " c-$group";
            $self->{targets}{$_} //= q{};
            $self->{targets}{$_} .= ( $self->{targets}{$_} eq q{} ? q{} : q{|} ) . $groupsregex;
        }
        $self->{popupcss} .= ".c-${group} .c-${group}\{display:list-item\} ";
    }
    foreach my $suffix ( @{ $self->{types} } ) {
        $self->{popupcss} .= ".cs-${suffix} .cs-${suffix}\{display:none\} ";
    }
    $self->{popupcss} .= '</style>';
    return $self;
}

sub handle_hook_fileattr {
    my ( $self, $config, $params ) = @_;
    my $suffix = $params->{path} =~ /[.](\w+)$/xms ? $1 : 'unknown';
    return $suffix !~ /$self->{unconvertible}/xms
      && $self->{memberof}{$suffix}
      ? { ext_classes => ( $suffix =~ /$self->{typesregex}/xms ? 'c' : q{} )
          . " $self->{memberof}{$suffix} cs-$suffix" }
      : 0;

}

sub handle_hook_fileactionpopup {
    my ( $self, $config, $params ) = @_;
    my @popup = map {
        {
            action  => 'odfconvert',
            label   => $_,
            type    => 'li',
            classes => 'access-writeable '
              . ( $self->{memberof}{$_} // q{} )
              . " cs-$_",
            data => { ct => $_ }
        }
    } sort @{ $self->{types} };
    return {
        title   => $self->tl('odfconverter'),
        classes => 'odfconverter',
        type    => 'li',
        popup   => \@popup
    };
}
sub handle_hook_appsmenu {
    my ( $self, $config, $params ) = @_;
    my @popup = ();
    foreach my $suffix (sort @{ $self->{types} } ) {
        my $targets = $self->{targets}{$suffix};
        $targets =~ s/ (?: ^ \b \Q$suffix\E \b [|] | [|] \b \Q$suffix\E \b ) //xmsg; # remove suffix
        $targets =~ s/ \b ( \w+ ) \b (.*?) [|] \b\1\b /$1$2/xmsg; # remove dublets
        push @popup, {
                action => 'odfconvert',
                label  => $suffix,
                classes => 'access-writeable sel-one-suffix hideit',
                type => 'li',
                data => { ct=>$suffix, suffix => q{^(?:}.$targets.q{)$} },
        };
    }
    my $attr = { 'data-suffix' => q{(?:}.join(q{|}, @{$self->{types}}).q{)}  };
    return {
        title => $self->tl('odfconverter'),
        label => $self->tl('odfconverter'),
        classes => 'odfconverter sel-one-suffix hideit',
        attr => $attr,
        labelattr => $attr,
        type => 'li',
        popup => \@popup,
    };
}
sub handle_hook_css {
    my ( $self, $config, $params ) = @_;
    if ( my $ret = $self->SUPER::handle_hook_css( $config, $params ) ) {
        $ret .= $self->{popupcss};
        return $ret;
    }
    return 0;
}

sub handle_hook_posthandler {
    my ( $self, $config, $params ) = @_;
    if (   $self->{cgi}->param('action')
        && $self->{cgi}->param('action') eq 'odfconvert' )
    {
        return $self->_convert_file();
    }
    return 0;
}

sub _convert_file {
    my ($self)       = @_;
    my $cgi          = $self->{cgi};
    my $targetformat = $cgi->param('ct');
    my $file         = $cgi->param('file');
    if ( $targetformat !~ /$self->{typesregex}/xms
        || !$self->{backend}->exists( $PATH_TRANSLATED . $file ) )
    {
        return 0;
    }

    my $full = $self->{backend}->getLocalFilename( $PATH_TRANSLATED . $file );
    my $tmpdirn = tempdir( CLEANUP => 1 );
    my $tmpdir  = $tmpdirn . q{/};
    mkdir $tmpdir;

    my $tmphomedir = "/tmp/_webdavcgi_odfconverter_$REMOTE_USER";
    if ( !-d $tmphomedir ) { mkdir $tmphomedir; }
    $ENV{HOME} = $tmphomedir;

    my @params = @{ $self->{oofficeparams} };
    for my $i ( 0 .. $#params ) {
        $params[$i] =~ s/\%targetformat/$targetformat/xmsg;
        $params[$i] =~ s/\%sourcefile/$full/xmsg;
        $params[$i] =~ s/\%targetdir/$tmpdirn/xmsg;
    }

    my %jsondata;
    if ( open my $fh, q{-|}, $self->{ooffice}, @params ) {
        local $RS = undef;
        my $output = <$fh>;
        close($fh) || carp('Cannot close office command.');
        my $targetfile =
          ( $file =~ /(^.*)[.]\w+$/xms ? $1 : $file ) . ".$targetformat";
        if ( $self->_save_all_local( $tmpdir, $full, $targetfile ) ) {
            $jsondata{message} = sprintf
              $self->tl('odfconverter.success'),
              $cgi->escapeHTML($file),
              $cgi->escapeHTML($targetfile);
        }
        else {
            $jsondata{error} = sprintf $self->tl('odfconverter.savefailed'),
              $targetfile;
        }
    }
    else {
        carp( "$self->{ooffice} " . join( q{ }, @params ) . ' failed.' );
        $jsondata{error} = sprintf $self->tl('odfconverter.failed'),
          $cgi->escapeHTML($file);
    }
    unlink $tmpdir;
    require JSON;
    print_compressed_header_and_content( '200 OK', 'application/json',
        JSON->new()->encode( \%jsondata ) );
    return 1;
}

sub _save_all_local {
    my ( $self, $tmpdir, $localfile, $targetfilename ) = @_;
    my $ret                 = 1;
    my $count               = 0;
    my $localtargetfilename = $self->{backend}->basename($localfile);
    $localtargetfilename =~ s/[.]\w+$//xms;
    $localtargetfilename .= q{.} . $self->{cgi}->param('ct');
    if ( opendir my $dir, $tmpdir ) {
        while ( my $file = readdir $dir ) {
            my $targetlocal = $tmpdir . $file;
            if ( $file =~ /^[.]{1,2}$/xms || -d $targetlocal ) { next; }
            my $targetfull = $PATH_TRANSLATED
              . ( $file eq $localtargetfilename ? $targetfilename : $file );
            if ( $self->{backend}->exists($targetfull) ) {
                $ret = rcopy( $self->{config}, $targetfull,
                    $targetfull . '.backup' );
            }
            if ( $ret && open my $fh, '<', $targetlocal ) {
                $ret = $self->{backend}->saveStream( $targetfull, $fh );
                if ($ret) { $count++; }
                close($fh) || carp("Cannot close $targetlocal.");
            }
            else {
                $ret = 0;
            }
            unlink $targetlocal;
            if ( !$ret ) { last; }
        }
        closedir $dir;
    }
    return $count > 0;
}
1;
