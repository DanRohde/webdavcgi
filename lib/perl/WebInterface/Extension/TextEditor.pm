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
# editablefiles - list of regular expressions to identify text files
# editablecategories - regular expression of categories (default: (text|soruce|shell|config|markup))
# disableckeditor - disables CKEditor for HTML editing
# sizelimit - size limit for text files in bytes (default: 2097152 (=2MB))
# template - template file (default: editform)

package WebInterface::Extension::TextEditor;

use strict;
use warnings;

our $VERSION = '1.0';

use base qw( WebInterface::Extension  );

use JSON;

use DefaultConfig qw( $FILETYPES $PATH_TRANSLATED $REQUEST_URI );
use HTTPHelper qw( get_mime_type print_compressed_header_and_content );
use FileUtils qw( rcopy );

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw(
      css         locales         javascript gethandler
      posthandler fileactionpopup fileaction settings
      fileattr
    );
    $hookreg->register( \@hooks, $self );

    $self->{editablefiles} = $self->config(
        'editablefiles',
        [
'\.(txt|php|s?html?|tex|inc|cc?|java|hh?|ini|pl|pm|py|css|js|inc|csh|sh|tcl|tk|tex|ltx|sty|cls|vcs|vcf|ics|csv|mml|asc|text|pot|brf|asp|p|pas|diff|patch|log|conf|cfg|sgml|xml|xslt|bat|cmd|wsf|cgi|sql)$',
'^(\.ht|readme|changelog|todo|license|gpl|install|manifest\.mf|author|makefile|configure|notice)'
        ]
    );
    $self->{editablefilesregex} =
      '(' . join( q{|}, @{ $self->{editablefiles} } ) . ')';
    $self->{editablecategories} = $self->config( 'editablecategories',
        '(text|source|shell|config|markup)' );
    $self->{template}  = $self->config( 'template',  'editform' );
    $self->{sizelimit} = $self->config( 'sizelimit', 2_097_152 );
    $self->{json}      = JSON->new();
    return $self;
}

sub handle {
    my ( $self, $hook, $config, $params ) = @_;
    if ( $hook eq 'fileattr' ) {
        my $is_editable = $self->_is_editable( $params->{path} );
        return {
            ext_classes => 'iseditable-' . ( $is_editable ? 'yes' : 'no' ),
            ext_iconclasses => $is_editable ? 'category-text' : q{}
        };
    }
    my $ret = $self->SUPER::handle( $hook, $config, $params );
    return $ret if $ret;

    if ( $hook eq 'settings' ) {
        return $self->handleSettingsHook('confirm.save')
          . $self->handleSettingsHook('texteditor.backup');
    }
    if ( $hook eq 'fileaction' ) {
        return {
            action  => 'edit',
            classes => 'access-readable',
            label   => 'editbutton'
        };
    }
    if ( $hook eq 'fileactionpopup' ) {
        return {
            action  => 'edit',
            classes => 'access-readable',
            label   => 'editbutton',
            type    => 'li'
        };
    }
    if (   $hook eq 'gethandler'
        && $self->{cgi}->param('action')
        && $self->{cgi}->param('action') eq 'edit' )
    {
        return $self->_get_edit_form();
    }
    if (   $hook eq 'posthandler'
        && $self->{cgi}->param('action')
        && $self->{cgi}->param('action') eq 'savetextdata' )
    {
        return $self->_save_text_data();
    }
    return 0;
}

sub _get_edit_form {
    my ($self)   = @_;
    my $filename = $self->{cgi}->param('filename');
    my $full     = "$PATH_TRANSLATED$filename";
    my ( $contenttype, $content ) = ( 'text/plain', q{} );
    if ( ( $self->{backend}->stat($full) )[7] > $self->{sizelimit} ) {
        $content = $self->{json} - encode(
            {
                error => sprintf(
                    $self->tl('msg_sizelimitexceeded'),
                    $self->{cgi}->escapeHTML($filename),
                    ( $self->render_byte_val( $self->{sizelimit} ) )[0]
                )
            }
        );
        $contenttype = 'application/json';
    }
    else {
        $content = $self->render_template(
            $PATH_TRANSLATED,
            $REQUEST_URI,
            $self->read_template( $self->{template} ),
            {
                filename => $self->{cgi}->escapeHTML($filename),
                textdata => $self->{cgi}
                  ->escapeHTML( $self->{backend}->getFileContent($full) ),
                mime => get_mime_type($full)
            }
        );
    }
    print_compressed_header_and_content( '200 OK', $contenttype, $content,
        'Cache-Control: no-cache, no-store' );
    return 1;
}

sub _make_backup_copy {
    my ( $self, $full ) = @_;
    return
         $self->{cgi}->cookie('settings.texteditor.backup') eq 'no'
      || ( $self->{backend}->stat($full) )[7] == 0
      || rcopy( $self->{config}, $full, "$full.backup" );
}

sub _save_text_data {
    my ($self)    = @_;
    my $filename  = $self->{cgi}->param('filename');
    my $full      = $PATH_TRANSLATED . $filename;
    my $efilename = $self->{cgi}->escapeHTML($filename);
    my %jsondata  = ();
    if ( $self->{config}->{method}->is_locked($full) ) {
        $jsondata{error} = sprintf( $self->tl('msg_locked'), $efilename );
    }
    elsif ($self->{backend}->isFile($full)
        && $self->{backend}->isWriteable($full)
        && $self->_make_backup_copy($full)
        && $self->{backend}->saveData( $full, $self->{cgi}->param('textdata') )
      )
    {
        $jsondata{message} = sprintf $self->tl('msg_textsaved'), $efilename;
    }
    else {
        $jsondata{error} = sprintf $self->tl('msg_savetexterr'), $efilename;
    }
    print_compressed_header_and_content(
        '200 OK', 'application/json',
        $self->{json}->encode( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}

sub _is_editable {
    my ( $self, $fn ) = @_;
    my $suffix = $fn =~ /[.](\w+)$/xms ? lc($1) : '___unknown___';
    return (
        $self->{backend}->basename($fn) =~ /$self->{editablefilesregex}/xmsi
          || $FILETYPES =~
          /^$self->{editablecategories}\s+.*\b\Q$suffix\E\b/xmsi )
      && $self->{backend}->isFile($fn)
      && $self->{backend}->isReadable($fn)
      && $self->{backend}->isWriteable($fn);
}

1;
