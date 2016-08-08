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

package WebInterface::View::Simple::RenderFileListTable;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw( WebInterface::View::Simple::Renderer );

use POSIX qw(strftime);

#use DateTime;
#use DateTime::Format::Human::Duration;

use DefaultConfig
    qw( $PATH_TRANSLATED $LANG $REQUEST_URI $SHOW_LOCKS $SHOW_PARENT_FOLDER $DOCUMENT_ROOT $SHOW_CURRENT_FOLDER
    $SHOW_CURRENT_FOLDER_ROOTONLY $VIRTUAL_BASE @ALLOWED_TABLE_COLUMNS %FILEFILTERPERDIR $ENABLE_NAMEFILTER
    $SHOW_QUOTA %QUOTA_LIMITS );
use FileUtils qw( get_file_limit );
use HTTPHelper qw(get_mime_type);
use vars qw( %CACHE );

sub render_template {
    my ( $self, $fn, $ru, $content ) = @_;
    my %quota = %{ $self->_get_quota_data($fn) };

    my %stdvars = (
        quotalimit => $self->{c}{render_template}{quotalimit}
            //= ( $self->render_byte_val( $quota{quotalimit}, 2, ) )[0],
        quotalimitbytes => $quota{quotalimit},
        quotalimittitle => $self->{c}{render_template}{quotalimittitle}
            //= ( $self->render_byte_val( $quota{quotalimit}, 2, ) )[1],
        quotaused => $self->{c}{render_template}{quotaused}
            //= ( $self->render_byte_val( $quota{quotaused}, 2, 2 ) )[0],
        quotausedtitle => $self->{c}{render_template}{quotausedtitle}
            //= ( $self->render_byte_val( $quota{quotaused}, 2, 2 ) )[1],
        quotaavailable => $self->{c}{render_template}{quotaavailable}
            //= ( $self->render_byte_val( $quota{quotaavailable}, 2, 2 ) )[0],
        quotaavailabletitle =>
            $self->{c}{render_template}{quotaavailabletitle}
            //= ( $self->render_byte_val( $quota{quotaavailable}, 2, 2 ) )[1],
        quotastyle         => $quota{quotastyle},
        quotalevel         => $quota{quotalevel},
        quotausedperc      => $quota{quotausedperc},
        quotaavailableperc => $quota{quotaavailableperc},
    );
    return $self->SUPER::render_template( $fn, $ru, $content, \%stdvars );
}

sub render_file_list_table {
    my ( $self, $template ) = @_;
    my ( $fn, $ru ) = ( $PATH_TRANSLATED, $REQUEST_URI );
    my $filelisttabletemplate = $self->_render_extension_function(
        $self->read_template($template) );
    my $columns
        = $self->_render_visible_table_columns( \$filelisttabletemplate )
        . $self->_render_invisible_allowed_table_columns(
        \$filelisttabletemplate );
    my %stdvars = (
        filelistheadcolumns => $columns,
        visiblecolumncount  => scalar( $self->get_visible_table_cols() ),
        isreadable => $self->{backend}->isReadable($fn) ? 'yes' : 'no',
        iswriteable  => $self->{backend}->isWriteable($fn) ? 'yes' : 'no',
        unselectable => $self->is_unselectable($fn)        ? 'yes' : 'no',
    );
    $filelisttabletemplate =~
        s/[\$]{?(\w+)}?/exists $stdvars{$1} && defined $stdvars{$1}?$stdvars{$1}:"\$$1"/xmegs;
    my %jsondata = (
        content => $self->minify_html(
            $self->render_template( $fn, $ru, $filelisttabletemplate )
        )
    );
    if ( !$self->{backend}->isReadable($fn) ) {
        $jsondata{error} = $self->tl('foldernotreadable');
    }
    if ($FILEFILTERPERDIR{$fn}
        || (   $ENABLE_NAMEFILTER
            && $self->{cgi}->param('namefilter') )
        )
    {
        $jsondata{warn} = sprintf
            $self->tl('folderisfiltered'),
            $FILEFILTERPERDIR{$fn}
            || (
              $ENABLE_NAMEFILTER
            ? $self->{cgi}->param('namefilter')
            : undef
            );

    }

    $jsondata{quicknav} = $self->minify_html( $self->render_quicknav_path() );
    require JSON;
    return JSON->new()->encode( \%jsondata );

}

sub render_file_list {
    my ( $self, $template ) = @_;
    my $entrytemplate = $self->_render_extension_function(
        $self->read_template($template) );
    my $fl = q{};

    my @files
        = $self->{backend}->isReadable($PATH_TRANSLATED)
        ? sort { $self->cmp_files( $a, $b ) } @{
        $self->{backend}
            ->readDir( $PATH_TRANSLATED, get_file_limit($PATH_TRANSLATED),
            $self )
        }
        : ();

    if ( $SHOW_PARENT_FOLDER && $DOCUMENT_ROOT ne $PATH_TRANSLATED ) {
        unshift @files, q{..};
    }
    if ($SHOW_CURRENT_FOLDER
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

sub exec_template_function {
    my ( $self, $fn, $ru, $func, $param ) = @_;
    if ( $func eq 'filelist' ) {
        return $self->render_file_list($param);
    }
    if ( $func eq 'isviewfiltered' ) {
        return $self->is_filtered_view();
    }
    if ( $func eq 'filterInfo' ) {
        return $self->_render_filter_info();
    }
    return $self->SUPER::exec_template_function( $fn, $ru, $func, $param );
}

sub _render_visible_table_columns {
    my ( $self, $templateref ) = @_;
    my @columns = $self->get_visible_table_cols();
    my $columns = q{};
    for my $column (@columns) {
        if (${$templateref} =~ s/<!--TEMPLATE[(]$column[)]\[(.*?)\]-->//xmsg )
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
        if (${$templateref} =~ s/<!--TEMPLATE[(]$column[)]\[(.*?)\]-->//xmsg )
        {
            my $c = $1;
            $c =~ s/-hidden/hidden/xmsg;
            $columns .= $c;
        }
    }
    ${$templateref} =~ s/<!--TEMPLATE[(][^)]+[)]\[.*?\]-->//xmsg;
    return $columns;
}

sub get_file_list_entry {
    my ($self) = @_;
    my $entrytemplate = $self->_render_extension_function(
        $self->read_template( scalar $self->{cgi}->param('template') ) );
    my $columns = $self->_render_visible_table_columns( \$entrytemplate )
        . $self->_render_invisible_allowed_table_columns( \$entrytemplate );
    $entrytemplate =~ s/\$filelistentrycolumns/$columns/xmesg;
    return $self->_render_file_list_entry( scalar $self->{cgi}->param('file'),
        $entrytemplate );
}

sub _render_extension_function {
    my ( $self, $content ) = @_;
    $content =~
        s/[\$]extension[(](.*?)[)]/$self->_render_extension($PATH_TRANSLATED,$REQUEST_URI,$1)/xmegs;
    return $content;
}

sub _render_file_list_entry {
    my ( $self, $file, $entrytemplate ) = @_;

    require DateTime;
    require DateTime::Format::Human::Duration;
    my $hdr = $CACHE{_render_file_list_entry}{hdr}
        //= DateTime::Format::Human::Duration->new();
    my $lang  = $LANG eq 'default' ? 'en' : $LANG;
    my $full  = "$PATH_TRANSLATED$file";
    my $fulle = $REQUEST_URI . $self->{cgi}->escape($file);
    $fulle =~ s/\%2f/\//xmsgi;    ## fix for search
    my $ir = $self->{backend}->isReadable($full);
    my $il = $self->{backend}->isLink($full);
    my $id = $self->{backend}->isDir($full);
    $file .= $file !~ /^[.]{1,2}$/xms && $id ? q{/} : q{};
    my $e = $entrytemplate;
    my ($dev,  $ino,   $mode,  $nlink, $uid,     $gid, $rdev,
        $size, $atime, $mtime, $ctime, $blksize, $blocks
    ) = $self->{backend}->stat($full);
    $mtime //= 0;
    $ctime //= 0;
    $mode  //= 0;
    my ( $sizetxt, $sizetitle ) = $self->render_byte_val( $size, 2, 2 );
    my $mime
        = $file eq q{..} ? '< .. >'
        : $id            ? '<folder>'
        :                  get_mime_type($full);
    my $suffix
        = $file eq q{..} ? 'folderup'
        : (
        $self->{backend}->isDir($full) ? 'folder'
        : ( $file =~ /[.]([\w?]+)$/xms ? lc($1) : 'unknown' )
        );
    my $category = $self->get_category_class($suffix);
    my $is_locked
        = $SHOW_LOCKS && $self->{config}->{method}->is_locked_cached($full);
    my $displayname
        = $self->{cgi}->escapeHTML( $self->{backend}->getDisplayName($full) );
    my $now = $self->{c}{_render_file_list_entry}{now}{$lang}
        //= DateTime->now( locale => $lang );
    my $cct = $self->can_create_thumb($full);
    my $u   = $self->{c}{_render_file_list_entry}{uid}{$uid // 'unknown'} //= $uid && $uid=~/^\d+$/xms ? scalar getpwuid( $uid ) : $uid ? $uid : 'unknown';
    my $g   = $self->{c}{_render_file_list_entry}{gid}{$gid // 'unknown'} //= $gid && $gid=~/^\d+$/xms ? scalar getgrgid( $gid ) : $gid ? $gid : 'unknown';
    my $icon = $self->{c}{_render_file_list_entry}{icon}{$mime}
        //= $self->get_icon($mime);
    my $enthumb = $self->{c}{_render_file_list_entry}{cookie}{thumbnails}
        //= $self->{cgi}->cookie('settings.enable.thumbnails') // 'yes';
    my $iconurl = $id ? $icon : $cct
        && $enthumb ne 'no' ? $fulle . '?action=thumb' : $icon;
    my %stdvars = (
        'name'         => $self->{cgi}->escapeHTML($file),
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
        'mime'        => $self->{cgi}->escapeHTML($mime),
        'realsize'    => $size ? $size : 0,
        'isreadable'  => $file eq q{..} || $ir ? 'yes' : 'no',
        'iswriteable' => $self->{backend}->isWriteable($full)
            || $il ? 'yes' : 'no',
        'isviewable' => $ir && $cct ? 'yes' : 'no',
        'islocked' => $is_locked ? 'yes'     : 'no',
        'islink'   => $il        ? 'yes'     : 'no',
        'isempty'  => $id        ? 'unknown' : ( defined $size )
            && $size == 0 ? 'yes' : 'no',
        'type' => $file =~ /^[.]{1,2}$/xms
            || $id ? 'dir' : 'file',
        'fileuri'      => $fulle,
        'unselectable' => $file eq q{..}
            || $self->is_unselectable($full) ? 'yes' : 'no',
        'mode'    => sprintf( '%04o',        $mode & oct 7777 ),
        'modestr' => $self->mode2str( $full, $mode ),
        'uidNumber' => $uid // 0,
        'uid'       => $u,
        'gidNumber' => $gid // 0,
        'gid'       => $g,
        'subdir' => $id  && $file !~ /^[.]{1,2}$/xms ? 'yes' : 'no',
        'isdotfile' => $file =~ /^[.]/xms
            && $file !~ /^[.]{1,2}$/xms ? 'yes' : 'no',
        'suffix' => $file =~ /[.]([^.]+)$/xms ? $self->{cgi}->escapeHTML($1)
        : 'unknown',
        'ext_classes'     => q{},
        'ext_attributes'  => q{},
        'ext_styles'      => q{},
        'ext_iconclasses' => q{},
        'thumbtitle'      => $id ? q{} : $mime,
        'filenametitle'   => $il
        ? $self->{cgi}->escapeHTML($file)
            . ' &rarr; '
            . $self->{cgi}->escapeHTML( $self->{backend}->getLinkSrc($full) )
        : q{},
    );

    $self->_call_fileattr_hook(\%stdvars, $full);
    $self->_call_fileprop_hook(\%stdvars, $full);

    ##$e=~s/\$\{?(\w+)\}?/exists $stdvars{$1} && defined $stdvars{$1}?$stdvars{$1}:"\$$1"/egs;
    $e =~ s{[\$]{?(\w+)}?}{  $stdvars{$1}//= "\$$1" }xmegs;
    return $self->SUPER::render_template( $PATH_TRANSLATED, $REQUEST_URI, $e );
}
sub _call_fileprop_hook {
    my ($self, $stdvars, $full) = @_;
    # fileprop hook by Harald Strack <hstrack@ssystems.de>
    # overwrites all stdvars including ext_...
    my $fileprop_extensions = $self->{config}{extensions}
        ->handle( 'fileprop', { path => $full } );
    if ( defined $fileprop_extensions ) {
        foreach my $ret ( @{$fileprop_extensions} ) {
            if ( ref $ret eq 'HASH' ) {
                $stdvars->{ keys %{$ret} } = values %{$ret};
            }
        }
    }
    return $stdvars;
}
sub _call_fileattr_hook {
    my ($self, $stdvars, $full) = @_;
    # fileattr hook: collect and concatenate attribute values
    my $fileattr_extensions = $self->{config}{extensions}
        ->handle( 'fileattr', { path => $full } );
    if ($fileattr_extensions) {
        foreach my $attr_hashref ( @{$fileattr_extensions} ) {
            if ( ref($attr_hashref) ne 'HASH' ) { next; }
            foreach my $supported_file_attr (
                (   'ext_classes', 'ext_attributes',
                    'ext_styles',  'ext_iconclasses'
                )
                )
            {
                $stdvars->{$supported_file_attr} .=
                    ${$attr_hashref}{$supported_file_attr}
                    ? q{ } . ${$attr_hashref}{$supported_file_attr}
                    : q{};
            }
        }
    }
    return $stdvars;
}
sub _render_filter_info {
    my ($self) = @_;
    my @filter;
    my $filtername = $self->{cgi}->param('search.name')
        || $self->{cgi}->cookie('filter.name');
    my $filtertypes = $self->{cgi}->param('search.types')
        || $self->{cgi}->cookie('filter.types');
    my $filtersize = $self->{cgi}->param('search.size')
        || $self->{cgi}->cookie('filter.size');

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
            . $self->{cgi}->escapeHTML($fn) . q{"};
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

sub _get_quota_data {
    my ( $self, $fn ) = @_;
    return $self->{c}{$fn}{quotaData}
        if exists $self->{c}{$fn}{quotaData};
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

    ${$ret}{quotausedperc}
        = ${$ret}{quotalimit} != 0
        ? $self->round( 100 * ${$ret}{quotaused} / ${$ret}{quotalimit} )
        : 0;
    ${$ret}{quotaavailableperc}
        = ${$ret}{quotalimit} != 0
        ? $self->round( 100 * ${$ret}{quotaavailable} / ${$ret}{quotalimit} )
        : 0;

    $self->{c}{$fn}{quotaData} = $ret;

    return $ret;
}
1;
