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
package HTTPHelper;

use strict;
use warnings;

our $VERSION = '2.0';

use base qw{ Exporter };
our @EXPORT_OK =
  qw( print_header_and_content print_compressed_header_and_content print_file_header
  print_header_and_content print_local_file_header fix_mod_perl_response
  read_request_body get_byte_ranges get_etag get_mime_type get_if_header_components
  get_dav_header get_supported_methods get_parent_uri get_base_uri_frag );

use CGI::Carp;
use POSIX qw( strftime );
use Digest::MD5;


use DefaultConfig qw( 
  $CGI $PATH_TRANSLATED
  $CHARSET %MIMETYPES $MIMEFILE $ENABLE_COMPRESSION $BUFSIZE
  $ENABLE_ACL $ENABLE_CALDAV $ENABLE_CARDDAV $ENABLE_CALDAV_SCHEDULE 
  $ENABLE_LOCK $ENABLE_BIND $ENABLE_SEARCH $BACKEND_INSTANCE
);

require bytes;

sub _get_header_hashref {
    my ($header) = @_;
    if ( !defined $header || ref($header) eq 'HASH' ) {
        return $header // {};
    }

    my %params = ();
    foreach my $line ( split /\r?\n/xms, $header ) {
        my ( $h, $v ) = split /:[ ]/xms, $line;
        $params{$h} = $v;
    }
    return \%params;
}

sub print_header_and_content {
    my ( $status, $type, $content, $add_header, $cookies ) = @_;

    $status  //= '403 Forbidden';
    $type    //= 'text/plain';
    $content //= q{};

    my $cgi = $CGI;

    my $contentlength = bytes::length($content);

    my %header = (
        -status         => $status,
        -type           => $type,
        -Content_Length => $contentlength,
        -ETag           => get_etag(),
        -charset        => $CHARSET,
        -cookie         => $cookies,
        'MS-Author-Via' => 'DAV',
        'DAV'           => get_dav_header(),
    );
    if ( defined $cgi->http('Translate') ) { $header{'Translate'} = 'f'; }
    %header = ( %header, %{ _get_header_hashref($add_header) } );

#binmode STDOUT, ":encoding(\U$CHARSET\E)" || carp('Cannot set bindmode for STDOUT.'); # WebDAV works but web doesn't so ignore wide character warnings
    binmode(STDOUT) || carp('Cannot set bindmode for STDOUT.');
    print($cgi->header( \%header ) . $content) || carp('Cannot write header and content to STDOUT.');
    fix_mod_perl_response( \%header );
    return;
}

sub print_compressed_header_and_content {
    my ( $status, $type, $content, $add_header, $cookies ) = @_;
    my $cgi    = $CGI;
    my $header = _get_header_hashref($add_header);
    if ( $ENABLE_COMPRESSION
        && ( my $enc = $cgi->http('Accept-Encoding') ) )
    {
        my $orig = $content;
        if ( $enc =~ /gzip/xmsi ) {
            require IO::Compress::Gzip;
            my $g = IO::Compress::Gzip->new( \$content );
            $g->write($orig);
            ${$header}{'Content-Encoding'} = 'gzip';
        }
        elsif ( $enc =~ /deflate/xmsi ) {
            require IO::Compress::Deflate;
            my $d = IO::Compress::Deflate->new( \$content );
            $d->write($orig);
            ${$header}{'Content-Encoding'} = 'deflate';
        }
    }
    return print_header_and_content( $status, $type, $content, $header,
        $cookies );
}

sub print_local_file_header {
    my ( $fn, $addheader ) = @_;
    my $cgi    = $CGI;
    my @stat   = stat $fn;
    no locale;
    my %header = (
        -status         => '200 OK',
        -type           => get_mime_type($fn),
        -Content_Length => $stat[7],
        -ETag           => get_etag($fn),
        -Last_Modified =>
          strftime( '%a, %d %b %Y %T GMT', gmtime( $stat[9] || 0 ) ),
        -charset        => $CHARSET,
        'DAV'           => get_dav_header(),
        'MS-Author-Via' => 'DAV',
    );
    if ( defined $cgi->http('Translate') ) {
        $header{'Translate'} = 'f';
    }
    %header = ( %header, %{ _get_header_hashref($addheader) } );
    print $cgi->header( \%header );
    return \%header;
}

sub print_file_header {
    my ( $backend, $fn, $addheader ) = @_;
    my $cgi     = $CGI;
    my @stat    = $backend->stat($fn);
    no locale;
    my %header  = (
        -status         => '200 OK',
        -type           => get_mime_type($fn),
        -Content_Length => $stat[7],
        -ETag           => get_etag($fn),
        -Last_Modified  => strftime( '%a, %d %b %Y %T GMT', gmtime $stat[9] ),
        -charset        => $CHARSET,
        -Cache_Control  => 'no-cache, no-store',
        'MS-Author-Via' => 'DAV',
        'DAV'           => get_dav_header(),
        'Accept-Ranges' => 'bytes',
    );
    if ( defined $cgi->http('Translate') ) {
        $header{'Translate'} = 'f';
    }
    my ( $start, $end, $count ) = get_byte_ranges();
    if ( defined $start ) {
        $header{-status} = '206 Partial Content';
        $header{-Content_Range} = sprintf 'bytes %s-%s/%s', $start, $end,
          $stat[7];
        $header{-Content_Length} = $count;
    }
    %header = ( %header, %{ _get_header_hashref($addheader) } );
    print $cgi->header( \%header );
    return \%header;
}

sub fix_mod_perl_response {
    my ($headerref) = @_;
    my $cgi = $CGI;
    ## mod_perl fix for unknown status codes:
    my $stat200re = qr{(?:20[16789]|2[1-9])}xms;
    my $stat300re = qr{(?:30[89]|3[1-9])}xms;
    my $stat400re = qr{(?:41[89]|4[2-9])}xms;
    my $stat500re = qr{(?:50[6-9]|5[1-9])}xms;
    if (
        $ENV{MOD_PERL}
        && ${$headerref}{-status} =~
        /^(?:$stat200re|$stat300re|$stat400re|$stat500re)/xms # /^(20[16789]|2[1-9]|30[89]|3[1-9]|41[89]|4[2-9]|50[6-9]|5[1-9])/xms
        && ${$headerref}{-status} =~ /^(\d)/xms
        && ${$headerref}{-Content_Length} > 0
      )
    {
        $cgi->r->status("${1}00");
    }

    return;
}

sub read_request_body {
    my $body = q{};
    while ( read STDIN, my $buffer, $BUFSIZE ) {
        $body .= $buffer;
    }
    return $body;
}

sub get_byte_ranges {
    no locale;
    my $etag = get_etag($PATH_TRANSLATED);
    my $lm   = strftime( '%a, %d %b %Y %T GMT',
        gmtime( ( $BACKEND_INSTANCE->stat($PATH_TRANSLATED) )[9] ) );
    my $ifrange = $CGI->http('If-Range') || $etag;
    return if $ifrange ne $etag && $ifrange ne $lm;
    my $range = $CGI->http('Range');
    if ( $range && $range =~ /bytes=(\d+)\-(\d+)/xms ) {
        return ( $1, $2, $2 - $1 + 1 ) if $1 < $2;
    }
    return;
}

sub _read_mime_types {
    my ($mimefile) = @_;
    if ( open my $f, '<', $mimefile ) {
        while ( my $e = <$f> ) {
            next if $e =~ /^\s*(\#.*)?$/xms;
            my ( $type, @suffixes ) = split /\s+/xms, $e;
            foreach (@suffixes) { $MIMETYPES{$_} = $type }
        }
        close($f) || carp("Cannot close filehandle for '$mimefile'.");
    }
    else {
        carp "Cannot open $mimefile";
    }
    $MIMETYPES{default} = 'application/octet-stream';
    return;
}

sub get_mime_type {
    my ($filename) = @_;
    ## read mime.types file once:
    if ( defined $MIMEFILE ) { _read_mime_types($MIMEFILE); }
    $MIMEFILE = undef;
    my $extension = 'default';
    if ( $filename =~ /[.]([^.]+)$/xms ) {
        $extension = lc $1;
    }
    return $MIMETYPES{$extension} || $MIMETYPES{default};
}

sub get_etag {
    my ($file) = @_;
    $file //= $PATH_TRANSLATED;
    my $backend = $BACKEND_INSTANCE;

    my (
        $dev,  $ino,   $mode,  $nlink, $uid,     $gid, $rdev,
        $size, $atime, $mtime, $ctime, $blksize, $blocks
    ) = $backend->stat($file);
    my $digest = Digest::MD5->new;
    $digest->add($file);
    $digest->add( $size  || 0 );
    $digest->add( $mtime || 0 );
    return q{"} . $digest->hexdigest() . q{"};
}

sub get_if_header_components {
    my ($if) = @_;
    my ( $ret, $rtag, @tokens );
    if ( defined $if ) {
        if ( $if =~ s/^<([^>]+)>\s*//xms ) {
            $rtag = $1;
        }
        while (
            $if =~ s/^[(](Not\s*)?([^\[)]+\s*)?\s*(\[([^\])]+)\])?[)]\s*//xmsi )
        {
            push @tokens,
              {
                token => ( $1 ? $1 : q{} ) . ( $2 ? $2 : q{} ),
                etag => $4
              };
        }
        $ret = { rtag => $rtag, list => \@tokens };
    }
    return $ret;
}

sub get_dav_header {
    ## supported DAV compliant classes:
    my $DAV = '1';
    $DAV .= $ENABLE_LOCK ? ', 2' : q{};
    $DAV .= ', 3, <http://apache.org/dav/propset/fs/1>, extended-mkcol';
    $DAV .=
         $ENABLE_ACL
      || $ENABLE_CALDAV
      || $ENABLE_CARDDAV ? ', access-control' : q{};
    $DAV .=
      $ENABLE_CALDAV || $ENABLE_CALDAV_SCHEDULE
      ? ', calendar-access, calendarserver-private-comments'
      : q{};
    $DAV .=
      $ENABLE_CALDAV || $ENABLE_CALDAV_SCHEDULE
      ? ', calendar-schedule,calendar-availability,calendarserver-principal-property-search,calendarserver-private-events,calendarserver-private-comments,calendarserver-sharing,calendar-auto-schedule'
      : q{};
    $DAV .= $ENABLE_CARDDAV ? ', addressbook' : q{};
    $DAV .= $ENABLE_BIND    ? ', bind'        : q{};
    return $DAV;
}

sub get_supported_methods {
    my ($backend, $path) = @_;
    my @methods;
    my @rmethods = qw( OPTIONS GET HEAD PROPFIND PROPPATCH COPY GETLIB );
    my @wmethods = qw( POST PUT MKCOL MOVE DELETE );
    if ($ENABLE_LOCK) {
        push @rmethods, qw( LOCK UNLOCK );
    }
    if (   $ENABLE_ACL
        || $ENABLE_CALDAV
        || $ENABLE_CALDAV_SCHEDULE
        || $ENABLE_CARDDAV )
    {
        push @rmethods, 'REPORT';
    }
    if ($ENABLE_SEARCH) {
        push @rmethods, 'SEARCH';
    }
    if ( $ENABLE_ACL || $ENABLE_CALDAV || $ENABLE_CARDDAV )
    {
        push @wmethods, 'ACL';
    }
    if ( $ENABLE_CALDAV || $ENABLE_CALDAV_SCHEDULE ) {
        push @wmethods, 'MKCALENDAR';
    }
    if ($ENABLE_BIND) {
        push @wmethods, qw( BIND UNBIND REBIND);
    }
    @methods = @rmethods;
    if ( !defined $path || $backend->isWriteable($path) ) {
        push @methods, @wmethods;
    }
    return \@methods;
}
sub get_parent_uri {
    my ($uri) = @_;
    return $uri && $uri =~ m{^(.*?)/[^/]+/?$}xms ? ( $1 || q{/} ) : q{/};
}
sub get_base_uri_frag {
    my ($uri) = @_;
    return $uri && $uri =~ m{([^/]+)/?$}xms ? ( $1 // q{/} ) : q{/};
}

1;
