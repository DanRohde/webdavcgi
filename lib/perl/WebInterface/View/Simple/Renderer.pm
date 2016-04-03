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
use POSIX qw(strftime ceil);
use URI::Escape;
#use DateTime;
#use DateTime::Format::Human::Duration;

use FileUtils qw( get_file_limit );
use HTTPHelper
  qw( get_parent_uri get_base_uri_frag get_mime_type print_compressed_header_and_content );
use DefaultConfig qw( $DOCUMENT_ROOT $ENABLE_NAMEFILTER $FILETYPES $INSTALL_BASE
  $LANG $MAXFILENAMESIZE $MAXNAVPATHSIZE $PATH_TRANSLATED $POST_MAX_SIZE
  $REMOTE_USER $REQUEST_URI $SHOW_CURRENT_FOLDER $SHOW_CURRENT_FOLDER_ROOTONLY
  $SHOW_LOCKS $SHOW_PARENT_FOLDER $SHOW_QUOTA $VHTDOCS $VIEW $VIRTUAL_BASE
  %FILEFILTERPERDIR %QUOTA_LIMITS %SUPPORTED_LANGUAGES @ALLOWED_TABLE_COLUMNS
  @EXTENSIONS @VISIBLE_TABLE_COLUMNS );

use vars qw(%CACHE @ERRORS);

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

    if ( ${$self}{cgi}->param('ajax') ) {
        ( $content, $contenttype ) = $self->_render_ajax_response();
    }
    elsif (${$self}{cgi}->param('msg')
        || ${$self}{cgi}->param('errmsg')
        || ${$self}{cgi}->param('aclmsg')
        || ${$self}{cgi}->param('aclerrmsg')
        || ${$self}{cgi}->param('afsmsg')
        || ${$self}{cgi}->param('afserrmsg') )
    {
        ( $content, $contenttype ) = $self->_render_msg_response();
    }
    else {
        $content = $self->minify_html(
            $self->render_template(
                $PATH_TRANSLATED, $REQUEST_URI,
                $self->read_template('page')
            )
        );
    }
    delete $CACHE{$self}{$REQUEST_URI};
    $content     //= q{};
    $contenttype //= 'text/html';
    return print_compressed_header_and_content( '200 OK', $contenttype,
        $content, 'Cache-Control: no-cache, no-store',
        $self->get_cookies() );
}

sub _render_ajax_response {
    my ($self) = @_;
    my $ajax = ${$self}{cgi}->param('ajax');
    if ( $ajax eq 'getFileListTable' ) {
        return (
            $self->_render_file_list_table(
                scalar ${$self}{cgi}->param('template')
            ),
            'application/json'
        );
    }
    if ( $ajax eq 'getViewFilterDialog' ) {
        return $self->_render_viewfilter_dialog(
            scalar ${$self}{cgi}->param('template') );
    }
    if ( $ajax eq 'getSearchDialog' ) {
        return $self->render_template( $PATH_TRANSLATED, $REQUEST_URI,
            $self->read_template( scalar ${$self}{cgi}->param('template') ) );
    }
    if ( $ajax eq 'getTableConfigDialog' ) {
        return $self->render_template( $PATH_TRANSLATED, $REQUEST_URI,
            $self->read_template( scalar ${$self}{cgi}->param('template') ) );
    }
    if ( $ajax eq 'getFileListEntry' ) {
        my $entrytemplate =
          $self->_render_extension_function(
            $self->read_template( scalar ${$self}{cgi}->param('template') ) );
        my $columns = $self->_render_visible_table_columns( \$entrytemplate )
          . $self->_render_invisible_allowed_table_columns( \$entrytemplate );
        $entrytemplate =~ s/\$filelistentrycolumns/$columns/xmesg;
        return $self->_render_file_list_entry(
            scalar ${$self}{cgi}->param('file'),
            $entrytemplate );
    }
    return;
}

sub _render_msg_response {
    my ($self) = @_;
    my $msg =
         ${$self}{cgi}->param('msg')
      || ${$self}{cgi}->param('aclmsg')
      || ${$self}{cgi}->param('afsmsg');
    my $errmsg =
         ${$self}{cgi}->param('errmsg')
      || ${$self}{cgi}->param('aclerrmsg')
      || ${$self}{cgi}->param('afserrmsg');
    my %jsondata = ();
    my $p        = 1;
    my @params   = ();
    while ( ${$self}{cgi}->param( 'p' . ( $p++ ) ) ) {
        push @params, ${$self}{cgi}->escapeHTML($_);
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

sub _get_quota_data {
    my ( $self, $fn ) = @_;
    return $CACHE{$self}{$fn}{quotaData}
      if exists $CACHE{$self}{$fn}{quotaData};
    my @quota      = $SHOW_QUOTA ? $self->{backend}->getQuota($fn) : ( 0, 0 );
    my $quotastyle = q{};
    my $level      = 'info';
    if ( $SHOW_QUOTA && $quota[0] > 0 ) {
        my $qusage      = ( $quota[0] - $quota[1] ) / $quota[0];
        my $lowestlimit = 1;
        foreach my $l ( keys %QUOTA_LIMITS ) {
            if (   $QUOTA_LIMITS{$l}{limit}
                && $QUOTA_LIMITS{$l}{limit} <= $lowestlimit
                && $qusage <= $QUOTA_LIMITS{$l}{limit} )
            {
                $level       = $l;
                $lowestlimit = $QUOTA_LIMITS{$l}{limit};
            }
        }
        if ( $QUOTA_LIMITS{$level} ) {
            $quotastyle .=
              $QUOTA_LIMITS{$level}{color}
              ? ';color:' . $QUOTA_LIMITS{$level}{color}
              : q{};
            $quotastyle .=
              $QUOTA_LIMITS{$level}{background}
              ? ';background-color:' . $QUOTA_LIMITS{$level}{background}
              : q{};
        }
    }

    my $ret = {
        quotalimit     => $quota[0],
        quotaused      => $quota[1],
        quotaavailable => $quota[0] - $quota[1],
        quotalevel     => $level,
        quotastyle     => $quotastyle
    };

    ${$ret}{quotausedperc} =
      ${$ret}{quotalimit} != 0
      ? $self->round( 100 * ${$ret}{quotaused} / ${$ret}{quotalimit} )
      : 0;
    ${$ret}{quotaavailableperc} =
      ${$ret}{quotalimit} != 0
      ? $self->round( 100 * ${$ret}{quotaavailable} / ${$ret}{quotalimit} )
      : 0;

    $CACHE{$self}{$fn}{quotaData} = $ret;

    return $ret;
}

sub render_template {
    my ( $self, $fn, $ru, $content ) = @_;
    my $vbase = $ru =~ /^($VIRTUAL_BASE)/xms ? $1 : $ru;
    my %quota = %{ $self->_get_quota_data($fn) };

    # replace standard variables:
    my %stdvars = (
        uri          => $ru,
        baseuri      => ${$self}{cgi}->escapeHTML($vbase),
        quicknavpath => $CACHE{$self}{render_template}{quicknavpath} //=
          $self->_render_quicknav_path(),
        maxuploadsize   => $POST_MAX_SIZE,
        maxuploadsizehr => $CACHE{$self}{render_template}{maxuploadsizehr} //=
          ( $self->render_byte_val( $POST_MAX_SIZE, 2, 2 ) )[0],
        quotalimit => $CACHE{$self}{render_template}{quotalimit} //=
          ( $self->render_byte_val( $quota{quotalimit}, 2, ) )[0],
        quotalimitbytes => $quota{quotalimit},
        quotalimittitle => $CACHE{$self}{render_template}{quotalimittitle} //=
          ( $self->render_byte_val( $quota{quotalimit}, 2, ) )[1],
        quotaused => $CACHE{$self}{render_template}{quotaused} //=
          ( $self->render_byte_val( $quota{quotaused}, 2, 2 ) )[0],
        quotausedtitle => $CACHE{$self}{render_template}{quotausedtitle} //=
          ( $self->render_byte_val( $quota{quotaused}, 2, 2 ) )[1],
        quotaavailable => $CACHE{$self}{render_template}{quotaavailable} //=
          ( $self->render_byte_val( $quota{quotaavailable}, 2, 2 ) )[0],
        quotaavailabletitle =>
          $CACHE{$self}{render_template}{quotaavailabletitle} //=
          ( $self->render_byte_val( $quota{quotaavailable}, 2, 2 ) )[1],
        quotastyle         => $quota{quotastyle},
        quotalevel         => $quota{quotalevel},
        quotausedperc      => $quota{quotausedperc},
        quotaavailableperc => $quota{quotaavailableperc},
        stat_filetypes     => $CACHE{render_template}{stat_filetypes} //=
          $self->stat_matchcount( $FILETYPES, '^\S+' ),
        stat_suffixes => $CACHE{render_template}{stat_suffixes} //=
          $self->stat_matchcount( $FILETYPES, '\S+' ) -
          $self->stat_matchcount( $FILETYPES, '^\S+' ),
        stat_extensions    => $#EXTENSIONS + 1,
        stat_filetypeicons => $CACHE{render_template}{stat_filetypeicons} //=
          join(
            q{},
            map {
                ${$self}{cgi}->img(
                    {
                        -class => "icon category-$_",
                        -src =>
'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
                        -style =>
'margin: 0 auto 0 auto;border:0;padding: 2px 0 2px 0;height:24px;width:20px;',
                        -alt   => "Category \u$_",
                        -title => "\u$_"
                    }
                  )
            } $FILETYPES =~ /^\S+/xmsg
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
        CLOCK                  => ${$self}{cgi}->span(
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
        VBASE           => ${$self}{cgi}->escapeHTML($vbase),
        VHTDOCS         => $vbase . $VHTDOCS,
    );
    return $self->SUPER::render_template( $fn, $ru, $content, \%stdvars );
}

sub exec_template_function {
    my ( $self, $fn, $ru, $func, $param ) = @_;
    if ( $func eq 'filelist' ) {
        return $self->_render_file_list($param);
    }
    if ( $func eq 'isviewfiltered' ) {
        return $self->is_filtered_view();
    }
    if ( $func eq 'filterInfo' ) {
        return $self->_render_filter_info();
    }
    if ( $func eq 'langList' ) {
        return $self->_render_language_list($param);
    }
    if ( $func eq 'extension' ) {
        return $self->_render_extension($param);
    }
    return $self->SUPER::exec_template_function( $fn, $ru, $func, $param );
}

sub _render_extension_element {
    my ( $self, $a ) = @_;
    my $content = q{};
    if ( ref($a) eq 'HASH' ) {
        if ( ${$a}{subpopupmenu} ) {
            return ${$self}{cgi}->li(
                {
                    -class => 'subpopupmenu extension '
                      . ( ${$a}{classes} || q{} )
                },
                ( ${$a}{title} || q{} )
                  . ${$self}{cgi}->ul(
                    { -class => 'subpopupmenu extension' },
                    $self->_render_extension_element( ${$a}{subpopupmenu} )
                  )
            );
        }
        my %params = ( -class => q{} );
        $params{-class} .= ${$a}{action} ? ' action ' . ${$a}{action} : q{};
        $params{-class} .=
          ${$a}{listaction} ? ' listaction ' . ${$a}{listaction} : q{};
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
            $content .= ${$self}{cgi}->li( \%params,
                ${$self}{cgi}
                  ->span( { -class => 'label' }, $self->tl( ${$a}{label} ) ) );
        }
        else {
            $params{-href} = q{#};
            $params{-data_action} = ${$a}{action} || ${$a}{listaction};
            $content .= ${$self}{cgi}->a( \%params,
                ${$self}{cgi}
                  ->span( { -class => 'label' }, $self->tl( ${$a}{label} ) ) );
            if ( ${$a}{type} && ${$a}{type} eq 'li-a' ) {
                $content = ${$self}{cgi}
                  ->li( { -class => ${$a}{liclasses} || q{} }, $content );
            }
        }
        $content .= ${$a}{posthtml} ? ${$a}{posthtml} : q{};
    }
    elsif ( ref($a) eq 'ARRAY' ) {
        $content = join q{}, map { $self->_render_extension_element($_) } @{$a};
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
                map { q{'} . ${$self}{cgi}->escape($_) . q{'} } @{
                    ${$self}{config}{extensions}
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
      map { $self->_render_extension_element($_) }
      @{ ${$self}{config}{extensions}
          ->handle( $hook, { path => $PATH_TRANSLATED } ) // [] };
}

sub _render_extension_function {
    my ( $self, $content ) = @_;
    $content =~
s/[\$]extension[(](.*?)[)]/$self->_render_extension($PATH_TRANSLATED,$REQUEST_URI,$1)/xmegs;
    return $content;
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

sub _render_file_list_table {
    my ( $self, $template ) = @_;
    my ( $fn, $ru ) = ( $PATH_TRANSLATED, $REQUEST_URI );
    my $filelisttabletemplate =
      $self->_render_extension_function( $self->read_template($template) );
    my $columns =
      $self->_render_visible_table_columns( \$filelisttabletemplate )
      . $self->_render_invisible_allowed_table_columns(
        \$filelisttabletemplate );
    my %stdvars = (
        filelistheadcolumns => $columns,
        visiblecolumncount  => scalar( $self->get_visible_table_cols() ),
        isreadable => ${$self}{backend}->isReadable($fn) ? 'yes' : 'no',
        iswriteable  => ${$self}{backend}->isWriteable($fn) ? 'yes' : 'no',
        unselectable => $self->is_unselectable($fn)         ? 'yes' : 'no',
    );
    $filelisttabletemplate =~
s/[\$]{?(\w+)}?/exists $stdvars{$1} && defined $stdvars{$1}?$stdvars{$1}:"\$$1"/xmegs;
    my %jsondata = (
        content => $self->minify_html(
            $self->render_template( $fn, $ru, $filelisttabletemplate )
        )
    );
    if ( !${$self}{backend}->isReadable($fn) ) {
        $jsondata{error} = $self->tl('foldernotreadable');
    }
    if (
        $FILEFILTERPERDIR{$fn}
        || ( $ENABLE_NAMEFILTER
            && ${$self}{cgi}->param('namefilter') )
      )
    {
        $jsondata{warn} = sprintf
          $self->tl('folderisfiltered'),
          $FILEFILTERPERDIR{$fn}
          || (
            $ENABLE_NAMEFILTER
            ? ${$self}{cgi}->param('namefilter')
            : undef
          );

    }

    $jsondata{quicknav} =
      $self->minify_html( $self->_render_quicknav_path() );
    require JSON;
    return JSON->new()->encode( \%jsondata );

}

sub _render_file_list_entry {
    my ( $self, $file, $entrytemplate ) = @_;

    require DateTime;
    require DateTime::Format::Human::Duration;
    my $hdr = $CACHE{_render_file_list_entry}{hdr} //=
      DateTime::Format::Human::Duration->new();
    my $lang  = $LANG eq 'default' ? 'en' : $LANG;
    my $full  = "$PATH_TRANSLATED$file";
    my $fulle = $REQUEST_URI . ${$self}{cgi}->escape($file);
    $fulle =~ s/\%2f/\//xmsgi;    ## fix for search
    my $ir = ${$self}{backend}->isReadable($full) || 0;
    my $il = ${$self}{backend}->isLink($full)     || 0;
    my $id = ${$self}{backend}->isDir($full)      || 0;
    $file .= $file !~ /^[.]{1,2}$/xms && $id ? q{/} : q{};
    my $e = $entrytemplate;
    my (
        $dev,  $ino,   $mode,  $nlink, $uid,     $gid, $rdev,
        $size, $atime, $mtime, $ctime, $blksize, $blocks
    ) = ${$self}{backend}->stat($full);
    $mtime //= 0;
    $ctime //= 0;
    $mode  //= 0;
    my ( $sizetxt, $sizetitle ) = $self->render_byte_val( $size, 2, 2 );
    my $mime =
        $file eq q{..} ? '< .. >'
      : $id            ? '<folder>'
      :                  get_mime_type($full);
    my $suffix =
      $file eq q{..} ? 'folderup'
      : (
        ${$self}{backend}->isDir($full) ? 'folder'
        : ( $file =~ /[.]([\w?]+)$/xms ? lc($1) : 'unknown' )
      );
    my $category = $CACHE{category}{$suffix} ||=
         $suffix ne 'unknown'
      && $FILETYPES =~ /^(\w+)[^\n]*(?<=\s)\Q$suffix\E(?=\s)/xms
      ? 'category-' . $1
      : q{};
    my $is_locked =
      $SHOW_LOCKS && $self->{config}->{method}->is_locked_cached($full);
    my $displayname =
      ${$self}{cgi}->escapeHTML( ${$self}{backend}->getDisplayName($full) );
    my $now = $CACHE{$self}{_render_file_list_entry}{now}{$lang} //=
      DateTime->now( locale => $lang );
    my $cct = $self->can_create_thumb($full) || 0;
    my $u = $uid
      ? $CACHE{$self}{_render_file_list_entry}{uid}{$uid} //=
      scalar getpwuid( $uid || 0 ) || $uid
      : 'unknown';
    my $g = $gid
      ? $CACHE{$self}{_render_file_list_entry}{gid}{$gid} //=
      scalar getgrgid( $gid || 0 ) || $gid
      : 'unknown';
    my $icon = $CACHE{$self}{_render_file_list_entry}{icon}{$mime} //=
      $self->get_icon($mime);
    my $enthumb = $CACHE{$self}{_render_file_list_entry}{cookie}{thumbnails} //=
      ${$self}{cgi}->cookie('settings.enable.thumbnails') // 'yes';
    my $iconurl = $id ? $icon : $cct
      && $enthumb ne 'no' ? $fulle . '?action=thumb' : $icon;
    my %stdvars = (
        'name'         => ${$self}{cgi}->escapeHTML($file),
        'displayname'  => $displayname,
        'qdisplayname' => $self->quote_ws($displayname),
        'size'         => $ir ? $sizetxt : q{-},
        'sizetitle'    => $sizetitle,
        'lastmodified' => $ir
        ? strftime( $self->tl('lastmodifiedformat'), localtime $mtime )
        : q{-},
        'lastmodifiedtime' => $mtime,
        'lastmodifiedhr'   => $ir && $mtime ? $hdr->format_duration_between(
            DateTime->from_epoch( epoch => $mtime, locale => $lang ),
            $now,
            precision         => 'seconds',
            significant_units => 2
          ) : q{-},
        'created' => $ir
        ? strftime( $self->tl('lastmodifiedformat'), localtime $ctime )
        : q{-},
        'createdhr' => $ir && $ctime ? $hdr->format_duration_between(
            DateTime->from_epoch( epoch => $ctime, locale => $lang ),
            $now,
            precision         => 'seconds',
            significant_units => 2
          ) : q{-},
        'createdtime'  => $ctime,
        'iconurl'      => $iconurl,
        'thumbiconurl' => $cct ? $fulle . '?action=thumb' : q{},
        'mimeiconurl'  => $iconurl eq $icon ? q{} : $icon,
        'iconclass'    => "icon $category suffix-$suffix"
          . ( $cct && $enthumb ne 'no' ? ' thumbnail' : q{} ),
        'mime'        => ${$self}{cgi}->escapeHTML($mime),
        'realsize'    => $size ? $size : 0,
        'isreadable'  => $file eq q{..} || $ir ? 'yes' : 'no',
        'iswriteable' => ${$self}{backend}->isWriteable($full)
          || $il ? 'yes' : 'no',
        'isviewable' => $ir && $cct ? 'yes' : 'no',
        'islocked' => $is_locked ? 'yes'     : 'no',
        'islink'   => $il        ? 'yes'     : 'no',
        'isempty'  => $id        ? 'unknown' : ( defined $size )
          && $size == 0 ? 'yes' : 'no',
        'type' => $file =~ /^[.]{1,2}$/xms
          || $id ? 'dir' : ( $il ? 'link' : 'file' ),
        'fileuri'      => $fulle,
        'unselectable' => $file eq q{..}
          || $self->is_unselectable($full) ? 'yes' : 'no',
        'mode'    => sprintf( '%04o',        $mode & oct 7777 ),
        'modestr' => $self->mode2str( $full, $mode ),
        'uidNumber' => $uid || 0,
        'uid'       => $u,
        'gidNumber' => $gid || 0,
        'gid'       => $g,
        'isdotfile' => $file =~ /^[.]/xms
          && $file !~ /^[.]{1,2}$/xms ? 'yes' : 'no',
        'suffix' => $file =~ /[.]([^.]+)$/xms ? ${$self}{cgi}->escapeHTML($1)
        : 'unknown',
        'ext_classes'     => q{},
        'ext_attributes'  => q{},
        'ext_styles'      => q{},
        'ext_iconclasses' => q{},
        'thumbtitle'      => $id ? q{} : $mime,
        'filenametitle'   => $il
        ? ${$self}{cgi}->escapeHTML($file)
          . ' &rarr; '
          . ${$self}{cgi}->escapeHTML( ${$self}{backend}->getLinkSrc($full) )
        : q{},
    );

    # fileattr hook: collect and concatenate attribute values
    my $fileattr_extensions =
      ${$self}{config}{extensions}->handle( 'fileattr', { path => $full } );
    if ($fileattr_extensions) {
        foreach my $attr_hashref ( @{$fileattr_extensions} ) {
            if ( ref($attr_hashref) ne 'HASH' ) { next; }
            foreach my $supported_file_attr (
                (
                    'ext_classes', 'ext_attributes',
                    'ext_styles',  'ext_iconclasses'
                )
              )
            {
                $stdvars{$supported_file_attr} .=
                  ${$attr_hashref}{$supported_file_attr}
                  ? q{ } . ${$attr_hashref}{$supported_file_attr}
                  : q{};
            }
        }
    }

    # fileprop hook by Harald Strack <hstrack@ssystems.de>
    # overwrites all stdvars including ext_...
    my $fileprop_extensions =
      ${$self}{config}{extensions}->handle( 'fileprop', { path => $full } );
    if ( defined $fileprop_extensions ) {
        foreach my $ret ( @{$fileprop_extensions} ) {
            if ( ref $ret eq 'HASH' ) {
                @stdvars{ keys %{$ret} } = values %{$ret};
            }
        }
    }
    ##$e=~s/\$\{?(\w+)\}?/exists $stdvars{$1} && defined $stdvars{$1}?$stdvars{$1}:"\$$1"/egs;
    $e =~ s{[\$]{?(\w+)}?}{  $stdvars{$1}//= "\$$1" }xmegs;
    return $self->render_template( $PATH_TRANSLATED, $REQUEST_URI, $e );
}

sub _render_visible_table_columns {
    my ( $self, $templateref ) = @_;
    my @columns = $self->get_visible_table_cols();
    my $columns = q{};
    for my $column (@columns) {
        if ( ${$templateref} =~ s/<!--TEMPLATE[(]$column[)]\[(.*?)\]-->//xmsg )
        {
            my $c = $1;
            $c =~ s/-hidden//xmsg;
            $columns .= $c;
        }
    }
    return $columns;
}

sub _render_invisible_allowed_table_columns {
    my ( $self, $templateref ) = @_;
    my $columns = q{};
    for my $column (@ALLOWED_TABLE_COLUMNS) {
        if ( ${$templateref} =~ s/<!--TEMPLATE[(]$column[)]\[(.*?)\]-->//xmsg )
        {
            my $c = $1;
            $c =~ s/-hidden/hidden/xmsg;
            $columns .= $c;
        }
    }
    ${$templateref} =~ s/<!--TEMPLATE[(][^)]+[)]\[.*?\]-->//xmsg;
    return $columns;
}

sub _render_file_list {
    my ( $self, $template ) = @_;
    my $entrytemplate =
      $self->_render_extension_function( $self->read_template($template) );
    my $fl = q{};

    my @files =
      ${$self}{backend}->isReadable($PATH_TRANSLATED)
      ? sort { $self->cmp_files( $a, $b ) } @{
        ${$self}{backend}->readDir(
            $PATH_TRANSLATED, get_file_limit($PATH_TRANSLATED), $self
        )
      }
      : ();

    if ( $SHOW_PARENT_FOLDER && $DOCUMENT_ROOT ne $PATH_TRANSLATED ) {
        unshift @files, q{..};
    }
    if (
        $SHOW_CURRENT_FOLDER
        || (   $SHOW_CURRENT_FOLDER_ROOTONLY
            && $REQUEST_URI =~ /^$VIRTUAL_BASE$/xms )
      )
    {
        unshift @files, q{.};
    }
    my $columns = $self->_render_visible_table_columns( \$entrytemplate )
      . $self->_render_invisible_allowed_table_columns( \$entrytemplate );
    $entrytemplate =~ s/\$filelistentrycolumns/$columns/xmesg;

    foreach my $file (@files) {
        $fl .= $self->_render_file_list_entry( $file, $entrytemplate );
    }

    return $fl;
}

sub _render_filter_info {
    my ($self) = @_;
    my @filter;
    my $filtername = ${$self}{cgi}->param('search.name')
      || ${$self}{cgi}->cookie('filter.name');
    my $filtertypes = ${$self}{cgi}->param('search.types')
      || ${$self}{cgi}->cookie('filter.types');
    my $filtersize = ${$self}{cgi}->param('search.size')
      || ${$self}{cgi}->cookie('filter.size');

    if ($filtername) {
        my %filterops = (
            q{=~} => $self->tl('filter.name.regexmatch'),
            q{^}  => $self->tl('filter.name.startswith'),
            q{$}  => $self->tl('filter.name.endswith'),
            'eq'  => $self->tl('filter.name.equal'),
            'ne'  => $self->tl('filter.name.notequal'),
            'lt'  => $self->tl('filter.name.lessthan'),
            'gt'  => $self->tl('filter.name.greaterthan'),
            'ge'  => $self->tl('filter.name.greaterorequal'),
            'le'  => $self->tl('filter.name.lessorequal'),
        );
        my ( $fo, $fn ) = split /\s/xms, $filtername;
        push @filter,
            $self->tl('filter.name.showonly') . q{ }
          . $filterops{$fo} . ' "'
          . ${$self}{cgi}->escapeHTML($fn) . q{"};
    }
    if ($filtertypes) {

        my @ft;
        foreach my $ftype ( split //xms, $filtertypes ) {
            if ( $ftype eq 'f' ) {
                push @ft, $self->tl('filter.types.files');
            }
            if ( $ftype eq 'd' ) {
                push @ft, $self->tl('filter.types.folder');
            }
            if ( $ftype eq 'l' ) {
                push @ft, $self->tl('filter.types.links');
            }
        }
        push @filter, $self->tl('filter.types.showonly') . join ', ', @ft;
    }
    if ($filtersize) {
        push @filter, $self->tl('filter.size.showonly') . $filtersize;

    }

    return scalar(@filter) > 0 ? join( ', ', @filter ) : q{};

}

sub read_template {
    my ( $self, $filename ) = @_;
    return $self->SUPER::read_template( $filename,
        "$INSTALL_BASE/templates/simple/" );
}

sub _render_quicknav_path {
    my ( $self, $query ) = @_;
    my $ru = uri_unescape($REQUEST_URI);
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
        $dn =
          $fnc eq $DOCUMENT_ROOT
          ? "$pe/"
          : ${$self}{backend}->getDisplayName($fnc);
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
            $content .=
              ${$self}{cgi}
              ->a( { -href => $lastignoredpath, -title => $ignoredpes },
                ' [...]/ ' );
            $ignoredpes = q{};
        }
        $content .=
          !$ignorepe
          ? ${$self}{cgi}->a(
            {
                -href => "$base$path" . ( defined $query ? "?$query" : q{} ),
                -title =>
                  ${$self}{cgi}->escapeHTML( uri_unescape("$base$path") )
            },
            ${$self}{cgi}->escapeHTML(" $dn ")
          )
          : q{};
        if ( scalar @fna > 0 ) { $fnc .= shift(@fna) . q{/}; }
    }
    $content .=
      $content eq q{}
      ? ${$self}{cgi}->a( { -href => q{/}, -title => q{/} }, q{/} )
      : q{};

    return $content;
}

sub _render_viewfilter_dialog {
    my ( $self, $tmplfile ) = @_;
    my $content = $self->read_template($tmplfile);
    my @filtername =
      ${$self}{cgi}->cookie('filter.name')
      ? split( /\s/xms, ${$self}{cgi}->cookie('filter.name') )
      : ( q{}, q{} );
    my @filtersize = ( q{}, q{}, q{} );
    if (   ${$self}{cgi}->cookie('filter.size')
        && ${$self}{cgi}->cookie('filter.size') =~
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
        'filter.types'     => ${$self}{cgi}->cookie('filter.types')
        ? ${$self}{cgi}->cookie('filter.types')
        : q{},
    );

    $content =~
s/[\$](selected|checked)[(]([^:)]+):([^)]+)[)]/$params{$2} eq $3 || $self->is_in($params{$2},$3) ? "$1=\"$1\"" : ""/xmegs;

    $content =~
s/[\$]([\w.]+)/exists $params{$1} ? ${$self}{cgi}->escapeHTML($params{$1}) : "\$$1"/xmegs;
    return $self->render_template( $PATH_TRANSLATED, $REQUEST_URI, $content );
}

1;
