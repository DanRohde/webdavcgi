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
# disable_fileactionpopup - disables fileaction entry in popup menu
# disable_apps - disables sidebar menu entry
# allow_contentsearch - allowes search file content
# resultlimit - sets result limit (default: 1000)
# searchtimeout - sets a timeout in seconds (default: 30 seconds)
# sizelimit - sets size limit for content search (default: 2097152 (=2MB))
# disable_dupseaerch - disables duplicate file search
# maxdepth - maximum search level (default: 100)
# duplicate_sample_size - sample size for doublet search (default: 1024 (=1KB))

package WebInterface::Extension::Search;

use strict;
use warnings;

our $VERSION = '1.0';

use base qw( WebInterface::Extension  );

use JSON;
use Time::HiRes qw(time);
use Digest::MD5 qw(md5_hex);
use POSIX qw(strftime);
use I18N::Langinfo
  qw (langinfo MON_1 MON_2 MON_3 MON_4 MON_5 MON_6 MON_7 MON_8 MON_9 MON_10 MON_11 MON_12 ABMON_1  ABMON_2 ABMON_3 ABMON_4 ABMON_5 ABMON_6 ABMON_7 ABMON_8 ABMON_9 ABMON_10 ABMON_11 ABMON_12
  DAY_1 DAY_2 DAY_3 DAY_4 DAY_5 DAY_6 DAY_7 ABDAY_1 ABDAY_2 ABDAY_3 ABDAY_4 ABDAY_5 ABDAY_6 ABDAY_7 D_FMT);
use Time::Piece;
use CGI::Carp;
use English qw( -no_match_vars );

use DefaultConfig
  qw( $FILETYPES $HTTP_HOST $LANG $PATH_TRANSLATED $REMOTE_USER $REQUEST_URI %EXTENSION_CONFIG );
use HTTPHelper
  qw( get_mime_type print_compressed_header_and_content print_header_and_content );
use FileUtils qw( get_file_limit );

use vars qw( %CACHE %TIMEUNITS);

%TIMEUNITS = (
    'seconds' => 1,
    'minutes' => 60,
    'hours'   => 3_600,
    'days'    => 86_400,
    'weeks'   => 604_800,
    'months'  => 18_144_000,
    'years'   => 31_557_600,
);

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw( link css locales javascript gethandler posthandler );
    if ( !$EXTENSION_CONFIG{Search}{disable_fileactionpopup} ) {
        push @hooks, 'fileactionpopup';
    }
    if ( !$EXTENSION_CONFIG{Search}{disable_apps} ) { push @hooks, 'apps'; }
    $hookreg->register( \@hooks, $self );

    $self->{resultlimit}   = $self->config( 'resultlimit',   1000 );
    $self->{searchtimeout} = $self->config( 'searchtimeout', 30 );
    $self->{sizelimit}     = $self->config( 'sizelimit',     2_097_152 );
    $self->{maxdepth}      = $self->config( 'maxdepth',      100 );
    $self->{duplicate_sample_size} =
      $self->config( 'duplicate_sample_size', 1024 );
    return $self;
}

sub handle {
    my ( $self, $hook, $config, $params ) = @_;

    if ( my $ret = $self->SUPER::handle( $hook, $config, $params ) ) {
        return $ret;
    }

    if ( $hook eq 'fileactionpopup' ) {
        return {
            action  => 'search',
            label   => 'search',
            path    => $params->{path},
            type    => 'li',
            classes => 'access-readable sel-dir'
        };
    }
    if ( $hook eq 'apps' ) {
        return $self->handleAppsHook( $self->{cgi}, 'search access-readable ',
            'search', 'search' );
    }
    if ( $hook eq 'gethandler' ) {
        my $action = $self->{cgi}->param('action') // q{};
        if ( $action eq 'getSearchForm' ) {
            return $self->_get_search_form();
        }
        elsif ( $action eq 'getSearchResult' ) {
            return $self->_get_search_result();
        }
        elsif ( $action eq 'opensearch' ) {
            return $self->_print_open_search();
        }
    }
    if ( $hook eq 'posthandler' ) {
        my $action = $self->{cgi}->param('action') // q{};
        if ( $action eq 'search' ) {
            return $self->_handle_search();
        }
    }
    if ( $hook eq 'link' ) {
        my $ret =
'<link rel="search" href="?action=opensearch&amp;searchin=filename" type="application/opensearchdescription+xml" title="WebDAV CGI '
          . $self->tl('search.opensearch.filename') . q{ }
          . $REQUEST_URI . '"/>';
        if ( $self->config( 'allow_contentsearch', 0 ) ) {
            $ret .=
'<link rel="search" href="?action=opensearch&amp;searchin=content" type="application/opensearchdescription+xml" title="WebDAV CGI '
              . $self->tl('search.opensearch.content') . q{ }
              . $REQUEST_URI . '"/>';
        }
        return $ret;
    }

    return 0;
}

sub _cut_long_string {
    my ( $self, $string, $limit ) = @_;
    $limit //= 100;
    return $string if ( length($string) <= $limit );
    return substr( $string, 0, $limit - 3 ) . '...';
}

sub _get_search_form {
    my ($self) = @_;
    my $searchinfolders =
      $self->{cgi}->param('files')
      ? join( ', ',
        map { $self->{backend}->getDisplayName( $PATH_TRANSLATED . $_ ) }
          $self->{cgi}->param('files') )
      : $self->tl('search.currentfolder');
    my $dfmt = langinfo(D_FMT);
    $dfmt =~ s/\%(.)/\L$1$1\E/xmsg;
    my $vars = {
        searchinfolders => $self->quote_ws(
            $self->{cgi}
              ->escapeHTML( $self->_cut_long_string($searchinfolders) )
        ),
        searchinfolderstitle => $self->{cgi}->escapeHTML($searchinfolders),
        MONTHNAMES           => q{"}
          . join(
            q{","},
            map { langinfo($_) } ( MON_1, MON_2, MON_3, MON_4, MON_5, MON_6,
                MON_7, MON_8, MON_9, MON_10, MON_11, MON_12
            )
          )
          . q{"},
        MONTHNAMESABBR => q{"}
          . join(
            q{","},
            map { langinfo($_) }
              ( ABMON_1, ABMON_2, ABMON_3, ABMON_4, ABMON_5, ABMON_6,
                ABMON_7, ABMON_8, ABMON_9, ABMON_10, ABMON_11, ABMON_12
              )
          )
          . q{"},
        DAYNAMES => q{"}
          . join( q{","},
            map { langinfo($_) }
              ( DAY_1, DAY_2, DAY_3, DAY_4, DAY_5, DAY_6, DAY_7 ) )
          . q{"},
        DAYNAMESABBR => q{"}
          . join( q{","},
            map { langinfo($_) }
              ( ABDAY_1, ABDAY_2, ABDAY_3, ABDAY_4, ABDAY_5, ABDAY_6, ABDAY_7 )
          )
          . q{"},
        DAYNAMESMIN => q{"}
          . join( q{","},
            map { substr langinfo($_), 0, 2 }
              ( ABDAY_1, ABDAY_2, ABDAY_3, ABDAY_4, ABDAY_5, ABDAY_6, ABDAY_7 )
          )
          . q{"},
        DATEFORMAT => $dfmt,
        FIRSTDAY   => $LANG eq 'de' ? 1 : 0
    };
    my $content =
      $self->render_template( $PATH_TRANSLATED, $REQUEST_URI,
        $self->read_template( $self->config( 'template', 'search' ) ), $vars );
    return print_compressed_header_and_content( '200 OK', 'text/html', $content,
        'Cache-Control: no-cache, no-store' );
}

sub _get_temp_filename {
    my ( $self, $type ) = @_;
    my $searchid = $self->{cgi}->param('searchid');
    return "/tmp/webdavcgi-search-$REMOTE_USER-$searchid.$type";
}

sub _get_result_template {
    my ( $self, $tmplname ) = @_;
    return $CACHE{$self}{resulttemplate}{$tmplname} ||=
      $self->read_template($tmplname);
}

sub _add_search_result {
    my ( $self, $base, $file, $counter ) = @_;
    if ( open my $fh, '>>', $self->_get_temp_filename('result') ) {
        my $filename =
          $file eq q{}
          ? q{.}
          : $self->{cgi}
          ->escapeHTML( $self->{backend}->getDisplayName( $base . $file ) );
        my $full = $base . $file;
        my @stat = $self->{backend}->stat($full);
        my $uri  = $REQUEST_URI . $self->{cgi}->escape($file);
        $uri =~ s/\%2f/\//xmsig;
        my $mime =
          $self->{backend}->isDir($full)
          ? '<folder>'
          : get_mime_type($full);
        my $suffix =
          $file eq q{..} ? 'folderup'
          : (
            $self->{backend}->isDir($full) ? 'folder'
            : ( $file =~ /[.]([\w?]+)$/xmsi ? lc($1) : 'unknown' )
          );
        my $category = $CACHE{categories}{$suffix} ||=
             $suffix ne 'unknown'
          && $FILETYPES =~ /^(\w+).*(?<=\s)\Q$suffix\E(?=\s)/xms
          ? "category-$1"
          : q{};
        print(
            {$fh} $self->render_template(
                $PATH_TRANSLATED,
                $REQUEST_URI,
                $self->_get_result_template(
                    $self->config( 'resulttemplate', 'result' )
                ),
                {
                    fileuri   => $self->{cgi}->escapeHTML($uri),
                    filename  => $filename,
                    qfilename => $self->quote_ws($filename),
                    dirname   => $self->{cgi}
                      ->escapeHTML( $self->{backend}->dirname($uri) ),
                    iconurl => $self->{backend}->isDir($full)
                    ? $self->get_icon($mime)
                    : $self->can_create_thumb($full)
                      && ($self->{cgi}->cookie('settings.enable.thumbnails') // q{}) ne
                      'no' ? $self->{cgi}->escapeHTML($uri) . '?action=thumb'
                    : $self->get_icon($mime),
                    iconclass => "icon $category suffix-$suffix "
                      . ( $self->can_create_thumb($full) ? 'thumbnail' : q{} ),
                    mime         => $self->{cgi}->escapeHTML($mime),
                    type         => $mime eq '<folder>' ? 'folder' : 'file',
                    parentfolder => $self->{cgi}->escapeHTML(
                        $self->{backend}->dirname( $base . $file )
                    ),
                    lastmodified => $self->{backend}->isReadable($full)
                    ? strftime( $self->tl('lastmodifiedformat'),
                        localtime $stat[9] )
                    : q{-},
                    size => ( $self->render_byte_val( $stat[7] ) )[0]
                }
            )
          )
          || carp('Cannot write result to temporary file.');
        $counter->{results}++;
        close($fh) || carp('Cannot closet temporary file.');
    }
    return;
}

sub _strptime {
    my ( $self, $str, $offset ) = @_;
    $offset //= 0;
    if ( !defined $str || $str =~/^\s*$/xms) {
        return;
    }
    my $ret;
    if (
        eval {
            $ret = Time::Piece->strptime( $str, langinfo(D_FMT) ) + $offset;
        }
      )
    {
        return $ret;
    }
    return;
}

sub _filter_files {
    my ( $self, $base, $file, $counter ) = @_;
    my $ret      = 0;
    my $query    = $self->{query};
    my $size     = $CACHE{$self}{search}{size} //= $self->{cgi}->param('size');
    my $searchin = $CACHE{$self}{search}{searchin} //=
      $self->{cgi}->param('searchin') // 'filename';
    my $time = $CACHE{$self}{search}{time} //= $self->{cgi}->param('time');
    my $mstartdate = $CACHE{$self}{search}{mstartdate} //=
      $self->_strptime( scalar $self->{cgi}->param('mstartdate') );
    my $menddate = $CACHE{$self}{search}{menddate} //=
      $self->_strptime( scalar $self->{cgi}->param('menddate'), 86_399_999 )
      ;
    my $cstartdate = $CACHE{$self}{search}{cstartdate} //=
      $self->_strptime( scalar $self->{cgi}->param('cstartdate') );
    my $cenddate = $CACHE{$self}{search}{cenddate} //=
      $self->_strptime( scalar $self->{cgi}->param('cenddate'), 86_399_999 );

    my $full = $base . $file;
    my @stat = $self->{backend}->stat($full);
    my $now  = time;

    $ret =
         defined $query
      && $searchin eq 'filename'
      && $self->{backend}->basename($file) !~ /$query/xmsi;

    $ret |=
         defined $query
      && $self->config( 'allow_contentsearch', 0 )
      && $searchin eq 'content'
      && ( !$self->{backend}->isReadable($full)
        || !$self->{backend}->isFile($full)
        || $self->{backend}->getFileContent( $full, $self->{sizelimit} ) !~
        /$query/xmsig );

    $ret |=
        !$self->{cgi}->param('filetype')
      && $self->{backend}->isFile($full)
      && !$self->{backend}->isLink($full);
    $ret |=
      !$self->{cgi}->param('foldertype') && $self->{backend}->isDir($full);
    $ret |= !$self->{cgi}->param('linktype') && $self->{backend}->isLink($full);

    if ( defined $size && $size =~ /^\d+$/xms ) {
        my $sizecomparator = $self->{cgi}->param('sizecomparator');
        if ( $sizecomparator =~ /^[<>=]{1,2}$/xms ) {
            my $filesize = $stat[7];
            my $realsize = $size *
              ( $self->{BYTEUNITS}{ $self->{cgi}->param('sizeunits') } || 1 );
            $ret |=
              !$self->_compare_vals( $filesize, $sizecomparator, $realsize );
        }
    }
    if ( defined $time && $time =~ /^[\d.,]+$/xms ) {
        my $timecomparator = $self->{cgi}->param('timecomparator');
        my $timeunits      = $self->{cgi}->param('timeunits');
        if ( $timecomparator =~ /^[<>=]{1,2}$/xms
            && exists $TIMEUNITS{$timeunits} )
        {
            $time=~s/,/./xmsg;
            $ret |= $self->{backend}->isDir($full)
              || !$self->_compare_vals( $now - $stat[9],
                $timecomparator, $time * $TIMEUNITS{$timeunits} );
        }
    }
    $ret |= defined $mstartdate && $stat[9] <= $mstartdate;
    $ret |= defined $menddate && $stat[9] >= $menddate;
    $ret |= defined $cstartdate && $stat[10] <= $cstartdate;
    $ret |= defined $cenddate && $stat[10] >= $cenddate;
    
    if (  !$self->config( 'disable_dupsearch', 0 )
        && $self->{cgi}->param('dupsearch') )
    {
        if (  !$ret
            && $self->{backend}->isFile($full)
            && !$self->{backend}->isLink($full)
            && !$self->{backend}->isDir($full) )
        {    ## && ($self->{backend}->stat($full))[7] <= $self->{sizelimit}) {
            push @{ $counter->{dupsearch}{sizes}{ $stat[7] } },
              { base => $base, file => $file };
        }
        $ret = 1;
    }
    return $ret;
}

sub _compare_vals {
    my ( $self, $v1, $op, $v2 ) = @_;
    if ( !defined $v1 || !defined $v2 ) {
        return 0;
    }
    if ( $op eq q{<=>} ) { return $v1 <=> $v2; }
    if ( $op eq q{<} )   { return $v1 < $v2; }
    if ( $op eq q{=} || $op eq q{==} ) { return $v1 == $v2; }
    if ( $op eq q{>} )   { return $v1 > $v2; }
    if ( $op eq q{cmp} ) { return $v1 cmp $v2; }
    if ( $op eq q{lt} )  { return $v1 lt $v2; }
    if ( $op eq q{eq} )  { return $v1 eq $v2; }
    if ( $op eq q{gt} )  { return $v1 gt $v2; }
    if ( $op eq q{le} )  { return $v1 le $v2; }
    if ( $op eq q{ge} )  { return $v1 ge $v2; }
    return 0;
}

sub _limits_reached {
    my ( $self, $counter ) = @_;
    $counter->{results} //= 0;
    $counter->{level} //= 0;
    return
         $counter->{results} >= $self->{resultlimit}
      || ( time - $counter->{started} ) > $self->{searchtimeout}
      || $counter->{level} > $self->{maxdepth};
}

sub _do_search {
    my ( $self, $base, $file, $counter ) = @_;
    my $backend      = $self->{backend};
    my $full         = $base . $file;
    my $fullresolved = $self->{backend}->resolve($full);
    $counter->{level}++;
    return if $self->_limits_reached($counter);
    if ( !$self->_filter_files( $base, $file, $counter ) ) {
        $self->_add_search_result( $base, $file, $counter );
    }
    if ( $backend->isDir($full) ) {
        $counter->{folders}++;
        return if exists $counter->{visited}{$fullresolved};
        $counter->{visited}{$fullresolved} = 1;
        foreach
          my $f ( sort @{ $backend->readDir( $full, get_file_limit($full) ) } )
        {
            $f .= $backend->isDir( $full . $f ) ? q{/} : q{};
            $self->_do_search( $base, "$file$f", $counter );

        }
    }
    else {
        $counter->{files}++;
    }
    $counter->{maxlevel} //= $counter->{level};
    if ( $counter->{level} > $counter->{maxlevel} ) {
        $counter->{maxlevel} = $counter->{level};
    }
    $counter->{level}--;
    return;
}

sub _get_sample_data {
    my ( $self, $data, $size ) = @_;
    foreach my $fileinfo ( @{ $data->{dupsearch}{sizes}{$size} } ) {
        if ( $size > 0 ) {
            my $full = $fileinfo->{base} . $fileinfo->{file};
            my $md5  = md5_hex( $self->{backend}
                  ->getFileContent( $full, $self->{duplicate_sample_size} ) );
            push @{ $data->{dupsearch}{md5sample}{$size}{$md5} }, $fileinfo;
        }
        else {
            push @{ $data->{dupsearch}{md5sample}{$size}{0} }, $fileinfo;
        }
    }
    return;
}

sub _get_full_data {
    my ( $self, $data, $size, $md5sample ) = @_;
    foreach
      my $fileinfo ( @{ $data->{dupsearch}{md5sample}{$size}{$md5sample} } )
    {
        if ( $size <= $self->{duplicate_sample_size} ) {
            push @{ $data->{dupsearch}{md5}{$size}{$md5sample} }, $fileinfo;
            next;
        }
        my $md5 = md5_hex(
            $self->{backend}->getFileContent(
                $fileinfo->{base} . $fileinfo->{file},
                $self->{sizelimit}
            )
        );
        push @{ $data->{dupsearch}{md5}{$size}{$md5} }, $fileinfo;
    }
    return;
}

sub _add_duplicate_cluster_result {
    my ( $self, $data, $size, $md5 ) = @_;
    if ( open my $fh, '>>', $self->_get_temp_filename('result') ) {
        my ( $s, $st ) = $self->render_byte_val($size);
        my $bytesavings =
          ( scalar( @{ $data->{dupsearch}{md5}{$size}{$md5} } ) - 1 ) * $size;
        my @savings = $self->render_byte_val($bytesavings);

        my ( $sl, $slt ) = $self->render_byte_val( $self->{sizelimit} );
        print(
            {$fh} $self->render_template(
                $PATH_TRANSLATED,
                $REQUEST_URI,
                $self->_get_result_template(
                    $self->config( 'dupsearchtemplate', 'dupsearch' )
                ),
                {
                    filecount =>
                      scalar( @{ $data->{dupsearch}{md5}{$size}{$md5} } ),
                    digest         => $md5,
                    size           => $s,
                    sizetitle      => $st,
                    bytesize       => $size,
                    sizelimit      => $self->{sizelimit},
                    sizelimittext  => $sl,
                    sizelimittitle => $slt,
                    savings        => $savings[0],
                    savingstitle   => $savings[1],
                    bytesavings    => $bytesavings,
                }
            )
        ) || carp('Cannot write search results to tempoarary file.');
        close($fh) || carp('Cannot close temporary file.');
    }
    foreach my $fileinfo ( @{ $data->{dupsearch}{md5}{$size}{$md5} } ) {
        $self->_add_search_result( $fileinfo->{base}, $fileinfo->{file},
            $data );
    }
    return;
}

sub _add_duplicate_savings {
    my ( $self, $data ) = @_;
    $data->{dupsearch}{savings} //= 0;
    if ($data->{dupsearch}{savings} == 0) {
        return;
    }
    if ( open my $fh, '>>', $self->_get_temp_filename('result') ) {
        my @savings = $self->render_byte_val( $data->{dupsearch}{savings} );
        print(
            {$fh} $self->render_template(
                $PATH_TRANSLATED,
                $REQUEST_URI,
                $self->_get_result_template(
                    $self->config(
                        'dupsearchsavingstemplate', 'dupsearchsavings'
                    )
                ),
                {
                    savings      => $savings[0],
                    savingstitle => $savings[1],
                    bytesavings  => $data->{dupsearch}{savings},
                    filecount    => $data->{dupsearch}{filecount},
                }
            )
        ) || carp('Cannot write result data to temporary file.');
        close($fh) || carp('Cannot close temporary file.');
    }
    return;
}

sub _do_dup_search {
    my ( $self, $data ) = @_;
    foreach my $size ( sort { $a <=> $b } keys %{ $data->{dupsearch}{sizes} } )
    {
        if ( $self->_limits_reached($data) ) {
            return;
        }
        ## check count of files with same size:
        if ( scalar( @{ $data->{dupsearch}{sizes}{$size} } ) <= 1 ) {
            next;
        }
        ## get sample data:
        $self->_get_sample_data( $data, $size );
        ## check sample data md5 sums:
        foreach my $md5sample ( keys %{ $data->{dupsearch}{md5sample}{$size} } )
        {
            if (
                scalar( @{ $data->{dupsearch}{md5sample}{$size}{$md5sample} } )
                <= 1 )
            {
                next;
            }
            $self->_get_full_data( $data, $size, $md5sample );
        }
        ## check md5 sums:
        foreach my $md5 ( keys %{ $data->{dupsearch}{md5}{$size} } ) {
            my $count = scalar( @{ $data->{dupsearch}{md5}{$size}{$md5} } );
            if ( $count <= 1 ) {
                next;
            }
            ## TODO: compare bitwise
            $self->_add_duplicate_cluster_result( $data, $size, $md5 );
            $data->{dupsearch}{savings}   += ( $count - 1 ) * $size;
            $data->{dupsearch}{filecount} += $count - 1;
        }
    }
    return;
}

sub _handle_search {
    my ($self) = @_;

    my @files = $self->{cgi}->param('files');
    if ( scalar(@files) == 0 ) { @files = (q{}) }
    my @results = ();
    unlink $self->_get_temp_filename('result');
    my %counter = ( started => time(), results => 0, files => 0, folders => 0 );

    if ( $self->{query} = $self->{cgi}->param('query') ) {
        $self->{query} = join '.*?', map { quotemeta } split /\s+/xms,
          $self->{query};                                      ## replace all
        $self->{query} =~ s/([^\#\\]*)\\[%*]/$1\.\*\?/xmsg;    ## wildcards *,%
        $self->{query} =~ s/([^\#\\]*)\\[?_]/$1\./xmsg;        ## wildcards ?,_
        $self->{query} =~ s/([^\#\\]*)\\\#/$1\\d+/xmsg;        ## wildcard #
        $self->{query} =~
          s/([^\#\\]*)\\\[(.*?([^\#\\]))\\\]/$1\[$2\]/xmsg;    ## [...]
        $self->{query} =~ s/\\\\([\#?%*_\[\]])/$1/xmsg;    ## quoted wildcards
        if ( $self->{query} =~ /[.][*][?]or[.][*][?]/xmsi ) {
            $self->{query} = '('
              . join( q{|}, split /[.][*][?]or[.][*][?]/xmsi, $self->{query} )
              . ')';
        }

        $self->{query} =~
          s/([.][*][?]){2,}/$1/xmsg;    ## replace .*? sequence with one .*?
        if ( eval { "super"=~/$self->{query}/xms } ) {
            $self->{query} = quotemeta $self->{cgi}->param('query');
        }

    }

    #carp("query=$self->{query}");
    foreach my $file (@files) {
        last if $self->_limits_reached( \%counter );
        $self->_do_search( $PATH_TRANSLATED, $file, \%counter );
    }

    if (  !$self->config( 'disable_dupsearch', 0 )
        && $self->{cgi}->param('dupsearch') )
    {
        $self->_do_dup_search( \%counter );
        $self->_add_duplicate_savings( \%counter );
    }

    $counter{completed} = time;
    my $duration = $counter{completed} - $counter{started};
    my $status   = sprintf
      $self->tl('search.completed'),
      $counter{results} // 0,
      $duration,
      $counter{files}   // 0,
      $counter{folders} // 0;
    my $data =
       !$counter{results}
      ? $self->{cgi}->div( $self->tl('search.noresult') )
      : undef;
    my %messages = ();
    if (   $self->_limits_reached( \%counter )
        || $counter{maxlevel} >= $self->{maxdepth} )
    {
        $messages{warn} = $self->{cgi}->escapeHTML(
            sprintf $self->tl('search.limitsreached'),
            $self->{resultlimit}, $self->{searchtimeout},
            $self->{maxdepth}
        );
    }

    $self->_get_search_result( $status, $data, \%messages );
    unlink $self->_get_temp_filename('result');
    return 1;
}

sub _get_search_result {
    my ( $self, $status, $data, $messages ) = @_;
    my %jsondata = $messages ? %{$messages} : ();
    my $tmpfn = $self->_get_temp_filename('result');
    $jsondata{status} = $status || $self->tl('search.inprogress');
    if ($data) {
        $jsondata{data} = $data;
    }
    else {
        if ( open my $fh, '<', $tmpfn ) {
            local $RS = undef;
            $jsondata{data} = $self->{cgi}->div( scalar <$fh> );
            close($fh) || carp("Cannot close temporary file $tmpfn.");
        }
    }
    print_compressed_header_and_content(
        '200 OK', 'application/json',
        JSON::encode_json( \%jsondata ),
        'Cache-Control: no-cache, no-store'
    );
    return 1;
}

sub _render_selected_files {
    my ( $self, $format ) = @_;
    my $ret = q{};
    foreach my $file ( $self->{cgi}->param('files') ) {
        my $f = $format;
        $f =~ s/\$v/$self->{cgi}->escapeHTML($file)/exmsg;
        $ret .= $f;
    }
    return $ret;
}

sub exec_template_function {
    my ( $self, $fn, $ru, $func, $param ) = @_;
    my $content;
    if ( $func eq '_render_selected_files' ) {
        $content = $self->_render_selected_files($param);
    }
    elsif ( $func eq 'getSearchId' ) {
        $content = time;
    }
    return $content
      // $self->SUPER::exec_template_function( $fn, $ru, $func, $param );
}

sub _print_open_search {
    my ($self) = @_;
    my $type = $self->{cgi}->param('searchin') eq 'content'
      && $self->config( 'allow_contentsearch', 0 ) ? 'content' : 'filename';
    my $template =
      $type eq 'content'
      ? qq@$ENV{SCRIPT_URI}?action=search&amp;query={searchTerms}&amp;searchin=content@
      : qq@$ENV{SCRIPT_URI}?action=search&amp;query={searchTerms}&amp;searchin=filename@;
    my $content =
        q{<?xml version="1.0" encoding="utf-8" ?>}
      . q{<OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/">}
      . qq{<ShortName>WebDAV CGI $type search in $REQUEST_URI</ShortName>}
      . qq{<Description>WebDAV CGI $type search in $REQUEST_URI</Description>}
      . qq{<InputEncoding>utf-8</InputEncoding><Url type="text/html" template="$template" />}
      . qq{<Image height="16" width="16" type="image/x-icon">https://$HTTP_HOST}
      . $self->getExtensionUri( 'Search', 'htdocs/search.ico' )
      . qq@</Image><Image height="64" width="64" type="image/png">https://$ENV{HTTP_HOST}@
      . $self->getExtensionUri( 'Search', 'htdocs/search64x64.png' )
      . q@</Image></OpenSearchDescription>@;
    print_header_and_content( '200 OK', 'text/xml', $content );
    return 1;
}
1;
