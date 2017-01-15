#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2016 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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
# TODO: describe extension setup

package WebInterface::Extension::Localizer;

use strict;
use warnings;

our $VERSION = '2.0';
use base qw( WebInterface::Extension );

use CGI::Carp;
use JSON;
use English qw( -no_match_vars );

use DefaultConfig qw( $PATH_TRANSLATED $REQUEST_URI $INSTALL_BASE %SUPPORTED_LANGUAGES $READBUFSIZE $VHTDOCS $VIEW );
use HTTPHelper qw( print_compressed_header_and_content get_sec_header get_parent_uri );

use FileUtils qw( get_local_file_content );

use vars qw( $ACTION );
sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw( css locales javascript appsmenu apps posthandler );
    $hookreg->register( \@hooks, $self );
    $self->{json} = JSON->new();
    return;
}


sub handle_hook_appsmenu {
    my ( $self, $config, $params ) = @_;
    return {
        action => 'localizer',
        label  => $self->tl('localizer'),
    };
}
sub handle_hook_apps {
    my ( $self ) = @_;
    return $self->handle_hook_appsmenu();
}

sub handle_hook_posthandler {
    my ( $self, $config, $params ) = @_;
    my $action = $self->{cgi}->param('action') // q{};
    if ( $action eq 'getLocalizerDialog' ) {
        return print_compressed_header_and_content( '200 OK', 'text/html',
            $self->render_template($PATH_TRANSLATED, $REQUEST_URI, $self->read_template('dialog')) );
    }
    if ($action eq 'downloadLocalization') {
        return $self->_handle_download_localization();
    }
    if ($action eq 'downloadAllLocaleFiles') {
        return $self->_handle_download_all_locales();
    }
    if ($action eq 'downloadHelpFile') {
        return $self->_handle_download_help_file();
    }
    my $json;
    if ($action eq 'getLocaleEditor') {
        $json = $self->_get_locale_editor();
    }
    if ($action eq 'saveLocalization') {
        $json = $self->_save_localization();
    }
    if ($action eq 'getHelpEditor') {
        $json = $self->_get_help_editor();
    }
    if ($action eq 'saveHelpFile') {
        $json = $self->_save_help_file();
    }

    if ($json) {
        return print_compressed_header_and_content('200 OK', 'application/json', $json);
    }
    return 0;
}
sub _get_help_basepath {
    my ($self, $extension) = @_;
    
    return $extension && $extension ne q{} 
            ? "${INSTALL_BASE}lib/perl/WebInterface/Extension/$extension/help/"
            : "${INSTALL_BASE}htdocs/views/$VIEW/help/";
}
sub _save_help_file {
    my ($self) = @_;
    my %response = ();
    my $filename = $self->{cgi}->param('filename') // q{};
    my $extension = $self->{cgi}->param('extension') // q{};
    $self->_sanitize(\$filename,\$extension);
    my $full = $self->_get_help_basepath($extension).$filename;
    if ($self->_create_backup_copy($full)) {
        if ($filename ne q{} && open my $out, q{>}, $full) {
            print {$out} scalar $self->{cgi}->param('source') // q{};
            close($out) || carp("Cannot close help file ${full}.");
            $response{message} = sprintf $self->tl('localizer.helpfilesaved'), $full;
        } else {
            carp("Cannot write helpfile ${full}.");
            $response{error} = sprintf $self->tl('localizer.cannotwritehelpfile'), $full;
        }
    } else {
        $response{error} = sprintf $self->tl('localizer.cannotwritebackupcopy'), $full;
    }
    return $self->{json}->encode(\%response);
}
sub _handle_download_help_file {
    my ($self) = @_;
    my $extension = $self->{cgi}->param('extension') // q{};
    my $filename = $self->{cgi}->param('filename') // q{};
    my $source = $self->{cgi}->param('source') // q{};
    $self->_sanitize(\$filename, \$extension);
    my $basepath = $self->_get_help_basepath($extension) =~ /^${INSTALL_BASE}(.*)$/xms ? $1 : $filename;
    return $self->_handle_zipped_text_download(\$source, $basepath.$filename, $extension ne q{} ?  "${extension}.zip" : "WebDAV-UI.zip" );
}
sub _sanitize {
    my $self = shift @_;
    foreach (@_) {
        if (defined ${$_}) {
            ${$_} =~ s{[\s/]}{}xmsg;
        }
    }
    return;
}
sub _get_help_editor {
    my ($self) = @_;
    my %response = ();
    my $lang = $self->{cgi}->param('localizerlang') // 'en';
    my $extension = $self->{cgi}->param('extension') // q{};
    $self->_sanitize(\$lang,\$extension);
    my $glob = $self->_get_help_basepath($extension).q{*.html};
    my $docbase = $extension ne q{} ? "${VHTDOCS}_EXTENSION($extension)_/help/": "${VHTDOCS}views/${VIEW}/help/";

    my $template = $self->read_template('helpeditor');
    my $entrytmpl = $template =~ s/<!--TEMPLATE\(entry\)\[(.*?)\]-->//xms ? $1 : $template;


    my $editor = q{};
    my $counter =0;
    foreach my $file ( glob $glob ) {
        if ($file =~ m{ _ [[:lower:]]{2} (?:_[[:lower:]]{2})? [.] html $}xmsi) {
            next;
        }
        my $transfile = $file =~ /^(.*?)[.]html/xms ? "${1}_${lang}.html" : $file;

        my $filename = $file =~ m{/([^/]+)$}xms ? $1 : $file;
        my $transfilename = $transfile =~ m{/([^/]+)$}xms ? $1 : $transfile;

        my %vars = (
            filename      => $filename,
            transfilename => $transfilename,
            extension     => $extension,
            docbase       => $docbase.$filename,
            counter       => $counter++,
            ORIG  => $self->{cgi}->escapeHTML(get_local_file_content($file)),
            TRANS => -r $transfile ? $self->{cgi}->escapeHTML(get_local_file_content($transfile)) : q{},
            L => $lang,
            LT => $SUPPORTED_LANGUAGES{$lang} // $lang,
        );
        $editor .= $self->render_template($PATH_TRANSLATED, $REQUEST_URI, $entrytmpl, \%vars );
    }
    $response{editor} = $self->render_template($PATH_TRANSLATED, $REQUEST_URI, $template, { EDITOR => $editor });
    return $self->{json}->encode(\%response);
}
sub _handle_download_all_locales {
    my ($self) = @_;
    my $lang = $self->{cgi}->param('localizerlang') // q{};
    $self->_sanitize(\$lang);
    my $qfn = $lang ne q{} ? "WebDAVCGI_$lang" : 'WebDAVCGI_ALL_LOCALES';
    my $glob = $lang ne q{}
                ? "${INSTALL_BASE}/locale/*_${lang}.msg ${INSTALL_BASE}/lib/perl/WebInterface/Extension/*/locale/*_${lang}.msg"
                 ." ${INSTALL_BASE}/htdocs/views/${VIEW}/help/*_${lang}.html ${INSTALL_BASE}/lib/perl/WebInterface/Extension/*/help/*_${lang}.html"
                : "${INSTALL_BASE}/locale/*.msg ${INSTALL_BASE}/lib/perl/WebInterface/Extension/*/locale/*.msg"
                 ." ${INSTALL_BASE}/htdocs/views/${VIEW}/help/*.html ${INSTALL_BASE}/lib/perl/WebInterface/Extension/*/help/*.html"
                ;

    require Archive::Zip;
    my $zip = Archive::Zip->new();
    foreach my $fn ( glob $glob ) {
        $zip->addFile( $fn, $fn=~/^${INSTALL_BASE}(.*)$/xms ? $1 : $fn);
    }

    my %header = (
        -status => '200 OK',
        -type   => 'application/octet-stream',
        -Content_Disposition => q{attachment; filename="} . $qfn . q{.zip"},
    );
    print $self->{cgi}->header(get_sec_header(\%header));
    $zip->writeToFileHandle(*STDOUT, 0);
    undef $zip;
    return 1;
}
sub _handle_zipped_text_download {
    my ($self, $textref, $filename, $zipfilename) = @_;
    require Archive::Zip;
    $zipfilename =~ s/"/\\"/xmsg;
    my $zip = Archive::Zip->new();
    $zip->addString( ${$textref} , $filename);
    my %header = (
        -status => '200 OK',
        -type   => 'application/octet-stream',
        -Content_Disposition => q{attachment; filename="} . $zipfilename . q{"},
    );
    print $self->{cgi}->header(get_sec_header(\%header));
    $zip->writeToFileHandle(*STDOUT, 0);
    undef $zip;
    return 1;
    
}
sub _handle_download_localization {
    my ($self) = @_;
    my $type = $self->{cgi}->param('localizertype');
    my $typeval = $self->{cgi}->param('localizertypeval');
    my $extension = $type eq 'extension' ? $typeval : undef;
    my $lang = $self->{cgi}->param('localizerlang');
    $self->_sanitize(\$lang);
    my $data = $self->{json}->decode(scalar $self->{cgi}->param('localization'));
    my $filename = $extension ? $self->_get_extension_locale_filename($extension, $lang) : $self->_get_ui_locale_filename($lang);
    my $zfn = $extension ? "${extension}_$lang" : "WebDAVCGI-UI_$lang";
    return $self->_handle_zipped_text_download($self->_create_locale_file($data), $filename =~ m{^${INSTALL_BASE}(.*)$}xms ? $1 : $filename, $zfn);
}
sub _get_extension_locale_filename {
    my ($self, $extension, $lang, $fallback) = @_;
    $self->_sanitize(\$extension,\$lang);
    my $pathbase = $INSTALL_BASE.'lib/perl/WebInterface/Extension/'.$extension.'/locale/locale';
    my $fn = $pathbase . '_'.$lang.'.msg';
    if ($fallback && !-e $fn) {
        $fn = $pathbase . '.msg';
    }
    return $fn;
}
sub _get_ui_locale_filename {
    my ($self, $lang, $fallback) = @_;
    $self->_sanitize(\$lang);
    my $pathbase = $INSTALL_BASE.'locale/webdav-ui';
    my $fn = $pathbase . '_'.$lang.'.msg';
    if (!-e $fn && $fallback) {
        $fn = $pathbase . '_default.msg';
    }
    return $fn;
}
sub _create_backup_copy {
    my ($self,$fn) = @_;
    if (! -e $fn ) {
        return 1;
    }
    my @t = localtime;
    $t[5]+=1900;
    $t[4]++;
    my $backfn = sprintf '%s.%4d-%02d-%02d.%d', $fn, $t[5], $t[4],$t[3],time;
    if (open my $in, '<', $fn) {
        if (open my $out, '>', $backfn) {
            while (read $in, my $buffer, $READBUFSIZE) {
                print {$out} $buffer;
            }
            close($out) || carp("Cannot close $backfn.");
        } else {
            carp("Cannot write backup copy $backfn.");
            return 0;
        }
        return close $in;
    } else {
        carp("Cannot read file $fn.");
    }
    return 0;
}
sub _create_locale_file {
    my ($self, $data) = @_;
    my $content = sprintf "# Created with Localizer extension by %s (%s)\n", $ENV{REMOTE_USER}, scalar localtime;
    foreach my $k ( sort keys %{$data} ) {
        if ($data->{$k} =~ /^\s*$/xms) {
            next;
        }
        $content .= sprintf qq{%-50s\t"%s"\n}, $k, $data->{$k};
    }
    return \$content;
}
sub _save_localization {
    my ($self) = @_;
    my %response = ();
    my $fn = $self->{cgi}->param('localizertype') eq 'extension'
            ? $self->_get_extension_locale_filename(scalar $self->{cgi}->param('localizertypeval'), scalar $self->{cgi}->param('localizerlang'))
            : $self->_get_ui_locale_filename(scalar $self->{cgi}->param('localizerlang'));
    if ($self->_create_backup_copy($fn)) {
        my $data = $self->{json}->decode(scalar $self->{cgi}->param('localization'));
        if (open my $out, '>', $fn) {
            print {$out} ${$self->_create_locale_file($data)};
            close($out) || carp("Cannot close $fn.");
            $response{message} = sprintf $self->tl('localizer.localefilesaved'), $fn;    
        } else {
            carp("Cannot write $fn.");
            $response{error} = sprintf $self->tl('localizer.cannotwritelocalefile'), $fn;
        }       
    } else {
        $response{error} = sprintf $self->tl('localizer.cannotwritebackupcopy'), $fn;
    }
    return $self->{json}->encode(\%response);
}
sub _read_locale_file {
    my ($self, $fn) = @_;
    my %ret = ();
    if (open my $fh, '<', $fn) {
        while (<$fh>) {
            chomp;
            if ( /^\#/xms || /^\s*$/xms ) { next; }
            if ( /^(\S+)\s+"(.*)"\s*$/xms) { $ret{$1} = $2; }
        }
        close $fh;        
    } else {
        carp("Cannot open locale file $fn.");
    }
    return \%ret;
}
sub _read_extension_locale_file {
    my ($self, $extension, $lang) = @_;
    return $self->_read_locale_file($self->_get_extension_locale_filename($extension, $lang));
}
sub _read_ui_locale_file {
    my ($self, $lang) = @_;
    return $self->_read_locale_file($self->_get_ui_locale_filename($lang));
}
sub _get_locale_editor {
    my ($self) = @_;
    my $lang = $self->{cgi}->param('localizerlang');
    my $extension = $self->{cgi}->param('extension');
    $self->_sanitize(\$lang,\$extension);
    $lang //= 'en';
    if ($lang eq q{}) { $lang = 'en'; }
    my $template = $self->read_template('localeeditor');
    my $entrytmpl = $template =~ s/<!--TEMPLATE\(entry\)\[(.*?)\]-->//xms ? $1 : $template;
    my $editor = q{};
    my $orig = $extension ? $self->_read_extension_locale_file($extension, 'default') : $self->_read_ui_locale_file('default');
    my $trans = $extension ? $self->_read_extension_locale_file($extension, $lang) : $self->_read_ui_locale_file($lang);
    my $filename = $extension ? $self->_get_extension_locale_filename($extension, $lang) : $self->_get_ui_locale_filename($lang);
    foreach my $k ( sort keys %{$orig} ) {
        my $et = $entrytmpl;
        $et =~ s/\$KEY/$self->{cgi}->escapeHTML($k)/xmsge;
        $et =~ s/\$ORIG/$self->{cgi}->escapeHTML($orig->{$k})/xmsge;
        $et =~ s{\$TRANS}{$self->{cgi}->escapeHTML($trans->{$k} // q{}) }xmsge;
        $editor .= $et;
    }
    my %response = (
        editor=>$self->render_template($PATH_TRANSLATED, $REQUEST_URI, $template,
                        { EDITOR => $editor, filename=>$filename, basepath=>get_parent_uri($filename),
                          T=>$extension ? 'extension' : 'ui', TV=>$extension // 'ui',
                          L=>$lang, LT=>$SUPPORTED_LANGUAGES{$lang} // $lang
                        }),
    );
    if ( -e $filename && !-w $filename ) {
        $response{warn} = sprintf $self->tl('localizer.missingwriteright'), $filename, $UID, $GID;
    } elsif ( !-e $filename && !-w get_parent_uri($filename) ) {
        $response{warn} = sprintf $self->tl('localizer.missingwriteright'), get_parent_uri($filename), $UID, $GID;
    }
    return $self->{json}->encode( \%response );
}
1;