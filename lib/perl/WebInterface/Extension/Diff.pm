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
# diff - sets the path to GNU diff (default: /usr/bin/diff)
# disable_fileactionpopup - disables fileaction entry in popup menu
# enable_apps - enables sidebar menu entry
# files_only - disables folder comparision (neccassary for none-local filesystem backends like SMB, DB)
#

package WebInterface::Extension::Diff;

use strict;
use warnings;
our $VERSION = '2.0';

use base qw( WebInterface::Extension  );

use CGI::Carp;

#use JSON;

use DefaultConfig qw( $PATH_TRANSLATED $REQUEST_URI %EXTENSION_CONFIG );
use HTTPHelper qw( print_compressed_header_and_content );

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw(css locales javascript posthandler);
    if ( !$EXTENSION_CONFIG{Diff}{disable_fileactionpopup} ) {
        push @hooks, 'fileactionpopup';
    }
    if ( $EXTENSION_CONFIG{Diff}{enable_apps} ) { push @hooks, 'apps'; }
    $hookreg->register( \@hooks, $self );
    return $self;
}

sub handle_hook_fileactionpopup {
    my ( $self, $config, $params ) = @_;
    return {
        action  => 'diff',
        label   => 'diff',
        path    => $params->{path},
        type    => 'li',
        classes => $self->config( 'files_only', 0 )
        ? 'sel-multi sel-file'
        : 'sel-multi'
    };
}

sub handle_hook_apps {
    my ( $self, $config, $params ) = @_;
    return $self->handle_apps_hook( $self->{cgi},
        'action diff sel-oneormore disabled',
        'diff_short', 'diff' );
}

sub handle_hook_posthandler {
    my ( $self, $config, $params ) = @_;
    if (   $self->{cgi}->param('action')
        && $self->{cgi}->param('action') eq 'diff' )
    {
        my %jsondata = ();
        my ( $content, $raw );
        my @files = $self->get_cgi_multi_param('files');
        if ( scalar(@files) == 2 && $self->_check_files_only(@files) ) {
            $content = $self->_render_diff_output(@files);
        }
        if ( !$content ) {
            if ( scalar(@files) != 2 ) {
                $jsondata{error} = $self->tl('diff_msg_selecttwo');
            }
            else {
                $jsondata{error} = sprintf
                  $self->tl('diff_msg_differror'),
                  $self->get_cgi_multi_param('files');
            }

        }
        else {
            $jsondata{content} = $content;
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

sub _check_files_only {
    my ( $self, @args ) = @_;
    if ( !$self->config( 'files_only', 0 ) ) { return 1; }
    while ( my $f = shift @args ) {
        if ( !$self->{backend}->isFile( $PATH_TRANSLATED . $f ) ) {
            return 0;
        }
    }
    return 1;
}

sub _subst_basepath {
    my ( $self, $f ) = @_;
    $f =~ s/\\"/"/xmsg;
    $f = $self->{backend}->resolveVirt($f);
    $f =~ s/^\Q$PATH_TRANSLATED\E//xms;
    return $f;
}

sub _render_diff_output {
    my ( $self, @files ) = @_;
    my $ret = 0;
    my $cgi = $self->{cgi};
    my ( $f1, $f2 ) = @files;
    my $raw                  = q{};
    my $difftmpl             = $self->read_template('diff');
    my $difflinetmpl         = $self->read_template('diffline');
    my $diffsinglelinetmpl   = $self->read_template('diffsingleline');
    my $difffilenamelinetmpl = $self->read_template('difffilenameline');
    my $filename_rx          = q{"?(.*?)"?};
    my $datetime_rx =
      q{\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}[.]\d+\s(?:[+\-]\d+)};
    my @fnstack;

    if (
        open my $DIFF,
        q{-|},
        $self->config( 'diff', '/usr/bin/diff' ),
        '-ru',
        $self->{backend}->getLocalFilename( $PATH_TRANSLATED . $f1 ),
        $self->{backend}->getLocalFilename( $PATH_TRANSLATED . $f2 )
      )
    {
        my $t = q{};
        my ( $lr, $ll ) = ( 0, 0 );
        my $diffcounter = 0;
        while (<$DIFF>) {
            $raw .= $_;
            chomp;
            my ( $tmpl, $text1, $text2, $text, $type, $linenumber1,
                $linenumber2 );
            if (/^-{3}\s+$filename_rx\s+$datetime_rx$/xms) {
                my $f = $self->_subst_basepath($1);
                if ( $f !~ /^\s*\Q$f1\E\s*$/xms && $f !~ m{^/tmp/}xms ) {
                    push @fnstack, $f;
                }
                next;
            }
            if (/^[+]{3}\s+$filename_rx\s+$datetime_rx$/xms) {
                $text2 = $self->_subst_basepath($1);
                $text1 = pop @fnstack;
                $t .=
                  $text2 !~ /^\s*\Q$f2\E\s*$/xms && $text2 !~ m{^/tmp/}xms
                  ? $self->render_template(
                    $PATH_TRANSLATED,
                    $REQUEST_URI,
                    $difffilenamelinetmpl,
                    {
                        file1 => $cgi->escapeHTML($text1),
                        file2 => $cgi->escapeHTML($text2)
                    }
                  )
                  : q{};
                next;
            }
            if (/^diff\s/xms) {
                next;
            }
            if (/^@@\s-(\d+)(?:,(?:\d+))?\s[+](\d+)(?:,(?:\d+))?\s@@/xms) {
                ( $ll, $lr ) = ( $1, $2 );
                next;
            }

            my $o = $_;
            $o =~ s/^.//xms;
            if (/^[+]/xms) {
                (
                    $type, $tmpl, $linenumber1, $text1, $linenumber2, $text2,
                    $text
                ) = ( 'added', $difflinetmpl, q{}, q{}, $lr, $o );
                $lr++;
                $diffcounter++;
            }
            if (/^-/xms) {
                (
                    $type, $tmpl, $linenumber1, $text1, $linenumber2, $text2,
                    $text
                ) = ( 'removed', $difflinetmpl, $ll, $o, q{}, q{} );
                $ll++;
                $diffcounter++;
            }
            elsif (/^[ ]/xms) {
                (
                    $type, $tmpl, $linenumber1, $text1, $linenumber2, $text2,
                    $text
                ) = ( 'unchanged', $difflinetmpl, $ll, $o, $lr, $o );
                $ll++;
                $lr++;
            }
            elsif (/^Binary.files.(.*?).and.(.*?).differ/xms) {
                my ( $ff1, $ff2 ) =
                  $self->config( 'files_only', 0 ) ? ( $f1, $f2 ) : ( $1, $2 );
                (
                    $type, $tmpl, $linenumber1, $text1, $linenumber2, $text2,
                    $text
                  )
                  = (
                    'binary',
                    $diffsinglelinetmpl,
                    q{}, q{}, q{}, q{},
                    sprintf(
                        $self->tl('diff_binary'),
                        $self->_subst_basepath($ff1),
                        $self->_subst_basepath($ff2)
                    ),
                  );
                $diffcounter++;
            }
            elsif (/^Only.in.(.*?):.(.*)$/xms) {
                (
                    $type, $tmpl, $linenumber1, $text1, $linenumber2, $text2,
                    $text
                  )
                  = (
                    'onlyin',
                    $diffsinglelinetmpl,
                    q{}, q{}, q{}, q{},
                    sprintf(
                        $self->tl('diff_onlyin'),
                        $self->_subst_basepath($1),
                        $self->_subst_basepath($2)
                    ),
                  );
                $diffcounter++;
            }
            elsif (/^\\\s*No.newline.at.end.of.file/xmsi) {
                (
                    $type, $tmpl, $linenumber1, $text1, $linenumber2, $text2,
                    $text
                  )
                  = (
                    'comment', $diffsinglelinetmpl, q{}, q{}, q{}, q{},
                    $self->tl('diff_nonewline'),
                  );
            }
            elsif ( /^\\\s(.*)/xms || /^(\w+.*)/xms ) {
                (
                    $type, $tmpl, $linenumber1, $text1, $linenumber2, $text2,
                    $text
                  )
                  = ( 'comment', $diffsinglelinetmpl, q{}, q{}, q{}, q{}, $1 );
            }
            $t .= $self->render_template(
                $PATH_TRANSLATED,
                $REQUEST_URI,
                $tmpl,
                {
                    type        => $type,
                    text1       => $cgi->escapeHTML($text1),
                    text2       => $cgi->escapeHTML($text2),
                    linenumber1 => $linenumber1,
                    linenumber2 => $linenumber2,
                    text        => $cgi->escapeHTML($text)
                }
            );
        }
        close($DIFF) || carp('Cannot close diff command.');
        $ret = $self->render_template(
            $PATH_TRANSLATED,
            $REQUEST_URI,
            $difftmpl,
            {
                difflines    => $t,
                rawdifflines => $cgi->escapeHTML($raw),
                file1        => $cgi->escapeHTML($f1),
                file2        => $cgi->escapeHTML($f2),
                diffcounter =>
                  sprintf( $self->tl('diff_nomorediffs'), $diffcounter ),
            }
        );

    }
    return $ret;
}
1;
