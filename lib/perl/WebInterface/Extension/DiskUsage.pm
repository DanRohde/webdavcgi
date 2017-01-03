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
# enable_fileaction - disables fileaction entry
# disable_fileactionpopup - disables fileaction entry in popup menu
# disable_apps - disables sidebar menu entry
# timeout - timeout in seconds (default: 60)
# filelimit - limits file count for treemap (default: 50)
# folderlimit - limits folder count for details and treemap (default: 50)
# template - dialog template (default: diskusage)
# followsymlinks - follows sym links (default: 1 (on))

package WebInterface::Extension::DiskUsage;

use strict;
use warnings;
our $VERSION = '2.0';

use base qw( WebInterface::Extension  );

#use JSON;
use POSIX qw(strftime);

use DefaultConfig qw( $LANG $PATH_TRANSLATED $REQUEST_URI );
use HTTPHelper qw( print_compressed_header_and_content );

use vars
  qw( $_DEFAULT_TIMEOUT $_DEFAULT_FFLIMIT $_MAX_FILENAMELIST_LENGTH $_MAX_SUFFIXES $_MAX_SUFFIX_LENGTH );

{
    $_DEFAULT_TIMEOUT         = 60;
    $_DEFAULT_FFLIMIT         = 50;
    $_MAX_FILENAMELIST_LENGTH = 100;
    $_MAX_SUFFIXES            = 10;
    $_MAX_SUFFIX_LENGTH       = 5;
}

sub init {
    my ( $self, $hookreg ) = @_;
    my @hooks = qw(css javascript locales posthandler appsmenu);
    if ( $self->config( 'enable_fileaction', 0 ) ) {
        push @hooks, 'fileaction';
    }
    if ( !$self->config( 'disable_fileactionpopup', 0 ) ) {
        push @hooks, 'fileactionpopup';
    }
    if ( !$self->config( 'disable_apps', 0 ) ) { push @hooks, 'apps'; }
    $hookreg->register( \@hooks, $self );
    return $self;
}

sub handle_hook_fileaction {
    my ( $self, $config, $params ) = @_;
    return {
        action   => 'diskusage',
        label => 'du_diskusage',
        type    => 'li',
        classes => 'access-readable',
        path  => $params->{path},
    };
}

sub handle_hook_fileactionpopup {
    my ( $self, $config, $params ) = @_;
    return {
        action   => 'diskusage',
        label   => 'du_diskusage',
        path    => $params->{path},
        type    => 'li',
        classes => 'action sel-noneormulti sel-dir access-readable hideit',
    };
}

sub handle_hook_apps {
    my ( $self, $config, $params ) = @_;
    return $self->handle_apps_hook( $self->{cgi},
        'action diskusage sel-noneormulti sel-dir',
        'du_diskusage_short', 'du_diskusage' );
}
sub handle_hook_appsmenu {
    my ( $self, $config, $params ) = @_;
    return $self->handle_hook_fileactionpopup($config,$params);
}
sub handle_hook_posthandler {
    my ( $self, $hook, $config, $params ) = @_;
    my $action = $config->{cgi}->param('action') // q{};
    if ( $action eq 'diskusage' ) {
        print_compressed_header_and_content(
            '200 OK', 'text/html',
            $self->_render_diskusage_template() // q{},
            'Cache-Control: no-cache, no-store'
        );
        return 1;
    }
    return 0;
}

sub _get_abs_uri {
    my ( $self, $path ) = @_;
    return $REQUEST_URI . $self->_get_uri( $self->_get_folder_name($path) );
}

sub _render_diskusage_template {
    my ($self) = @_;

    require DateTime;
    require DateTime::Format::Human::Duration;
    require JSON;

    my $cgi     = $self->{cgi};
    my $counter = { start => time };
    my $json    = JSON->new();

    $self->{counter} = $counter;
    $self->{json}    = $json;

    my @files = $self->get_cgi_multi_param('file');
    if (@files < 1) {
        push @files, q{};
    }
    foreach my $file ( @files ) {
        $self->_get_disk_usage( $PATH_TRANSLATED, $file, $counter );
    }
    if (
        time - $counter->{start} >
        $self->config( 'timeout', $_DEFAULT_TIMEOUT ) )
    {
        print_compressed_header_and_content(
            '200 OK',
            'application/json',
            $json->encode(
                {
                    error => $cgi->escapeHTML(
                        sprintf $self->tl('du_timeout'),
                        $self->config( 'timeout', $_DEFAULT_TIMEOUT )
                    )
                }
            ),
            'Cache-Control: no-cache, no-store'
        );
        return;
    }

    my $sizeall      = $counter->{size}{all};
    my $filecountall = $counter->{count}{all}{files};
    my @folders      = reverse sort {
        $counter->{size}{path}{$a} <=> $counter->{size}{path}{$b}
          || -( $a cmp $b )
    } keys %{ $counter->{size}{path} };

    my $maxfilesizesum = $counter->{size}{allmaxsum};

    # limit folders for view and fix sizeall,filecountall for treemap:
    if ( $self->config( 'folderlimit', $_DEFAULT_FFLIMIT ) > 0
        && scalar(@folders) >
        $self->config( 'folderlimit', $_DEFAULT_FFLIMIT ) )
    {
        splice @folders, $self->config( 'folderlimit', $_DEFAULT_FFLIMIT );
        $sizeall        = 0;
        $filecountall   = 0;
        $maxfilesizesum = 0;
        foreach my $folder (@folders) {
            $sizeall        += $counter->{size}{path}{$folder};
            $filecountall   += $counter->{count}{files}{$folder};
            $maxfilesizesum += $counter->{size}{pathmax}{$folder};
        }
    }
    $self->{folders}        = \@folders;
    $self->{sizeall}        = $sizeall;
    $self->{filecountall}   = $filecountall;
    $self->{maxfilesizesum} = $maxfilesizesum;

    my $lang = $LANG eq 'default' ? 'en' : $LANG;
    my $hdr = DateTime::Format::Human::Duration->new();

    my @pbvsum = $self->render_byte_val( $counter->{size}{all} );
    my $filenamelist = join ', ', @files;
    if ( $filenamelist eq q{} ) { $filenamelist = q{.}; }
    if ( length $filenamelist > $_MAX_FILENAMELIST_LENGTH ) {
        $filenamelist =
          substr( $filenamelist, 0, $_MAX_FILENAMELIST_LENGTH ) . '...';
    }

    my $vars = {
        diskusageof => sprintf(
            $self->tl('du_diskusageof'),
            $self->quote_ws( $cgi->escapeHTML($filenamelist) )
        ),
        files => $counter->{count}{all}{files}
          || 0,
        folders => $counter->{count}{all}{folders}
          || 0,
        sum => $counter->{count}{all}{sum}
          || 0,
        size              => $pbvsum[0],
        sizetitle         => $pbvsum[1],
        bytesize          => $counter->{size}{all},
        biggestfoldername => $cgi->escapeHTML(
            $self->_get_folder_name( $counter->{size}{biggestfolder}{path} )
        ),
        biggestfolderuri =>
          $self->_get_abs_uri( $counter->{size}{biggestfolder}{path} ),
        biggestfolderfilecount =>
          $counter->{count}{files}{ $counter->{size}{biggestfolder}{path} }
          || 0,
        biggestfolderfoldercount =>
          $counter->{count}{folders}{ $counter->{size}{biggestfolder}{path} }
          || 0,
        biggestfoldersum =>
          $counter->{count}{sum}{ $counter->{size}{biggestfolder}{path} }
          || 0,
        biggestfoldersize =>
          ( $self->render_byte_val( $counter->{size}{biggestfolder}{size} ) )
          [0],
        biggestfoldersizetitle =>
          ( $self->render_byte_val( $counter->{size}{biggestfolder}{size} ) )
          [1],
        biggestfolderage => $hdr->format_duration_between(
            DateTime->from_epoch(
                epoch => $counter->{size}{biggestfolder}{age} || 0,
                locale => $lang
            ),
            DateTime->now( locale => $lang ),
            precision         => 'seconds',
            significant_units => 2
        ),
        biggestfolderagetitle => strftime(
            $self->tl('lastmodifiedformat'),
            localtime( $counter->{size}{biggestfolder}{age} || 0 )
        ),

        biggestfilename =>
          $cgi->escapeHTML( $counter->{size}{biggestfile}{file} ),
        biggestfilepathuri =>
          $self->_get_abs_uri( $counter->{size}{biggestfile}{path} ),
        biggestfilepathname => $self->{cgi}->escapeHTML(
            $self->_get_folder_name( $counter->{size}{biggestfile}{path} )
        ),
        biggestfilesize =>
          ( $self->render_byte_val( $counter->{size}{biggestfile}{size} ) )[0],
        biggestfilesizetitle =>
          ( $self->render_byte_val( $counter->{size}{biggestfile}{size} ) )[1],
        biggestfileage => $hdr->format_duration_between(
            DateTime->from_epoch(
                epoch => $counter->{size}{biggestfile}{age} || 0,
                locale => $lang
            ),
            DateTime->now( locale => $lang ),
            precision         => 'seconds',
            significant_units => 2
        ),
        biggestfileagetitle => strftime(
            $self->tl('lastmodifiedformat'),
            localtime( $counter->{size}{biggestfile}{age} || 0 )
        ),

        oldestfoldername => $cgi->escapeHTML(
            $self->_get_folder_name( $counter->{age}{oldestfolder}{path} )
        ),
        oldestfolderuri =>
          $self->_get_abs_uri( $counter->{age}{oldestfolder}{path} ),
        oldestfolderfilecount =>
          $counter->{count}{files}{ $counter->{age}{oldestfolder}{path} }
          || 0,
        oldestfolderfoldercount =>
          $counter->{count}{folders}{ $counter->{age}{oldestfolder}{path} }
          || 0,
        oldestfoldersum =>
          $counter->{count}{sum}{ $counter->{age}{oldestfolder}{path} }
          || 0,
        oldestfoldersize =>
          ( $self->render_byte_val( $counter->{age}{oldestfolder}{size} ) )[0],
        oldestfoldersizetitle =>
          ( $self->render_byte_val( $counter->{age}{oldestfolder}{size} ) )[1],
        oldestfolderage => $hdr->format_duration_between(
            DateTime->from_epoch(
                epoch => $counter->{age}{oldestfolder}{age} || 0,
                locale => $lang
            ),
            DateTime->now( locale => $lang ),
            precision         => 'seconds',
            significant_units => 2
        ),
        oldestfolderagetitle => strftime(
            $self->tl('lastmodifiedformat'),
            localtime( $counter->{age}{oldestfolder}{age} || 0 )
        ),

        newestfoldername => $cgi->escapeHTML(
            $self->_get_folder_name( $counter->{age}{newestfolder}{path} )
        ),
        newestfolderuri =>
          $self->_get_abs_uri( $counter->{age}{newestfolder}{path} ),
        newestfolderfilecount =>
          $counter->{count}{files}{ $counter->{age}{newestfolder}{path} }
          || 0,
        newestfolderfoldercount =>
          $counter->{count}{folders}{ $counter->{age}{newestfolder}{path} }
          || 0,
        newestfoldersum =>
          $counter->{count}{sum}{ $counter->{age}{newestfolder}{path} }
          || 0,
        newestfoldersize =>
          ( $self->render_byte_val( $counter->{age}{newestfolder}{size} ) )[0],
        newestfoldersizetitle =>
          ( $self->render_byte_val( $counter->{age}{newestfolder}{size} ) )[1],
        newestfolderage => $hdr->format_duration_between(
            DateTime->from_epoch(
                epoch => $counter->{age}{newestfolder}{age} || 0,
                locale => $lang
            ),
            DateTime->now( locale => $lang ),
            precision         => 'seconds',
            significant_units => 2
        ),
        newestfolderagetitle => strftime(
            $self->tl('lastmodifiedformat'),
            localtime( $counter->{age}{newestfolder}{age} || 0 )
        ),

        oldestfilename => $cgi->escapeHTML(
            $self->_get_folder_name( $counter->{age}{oldestfile}{file} )
        ),
        oldestfilepathuri =>
          $self->_get_abs_uri( $counter->{age}{oldestfile}{path} ),
        oldestfilepathname => $self->{cgi}->escapeHTML(
            $self->_get_folder_name( $counter->{age}{oldestfile}{path} )
        ),
        oldestfilesize =>
          ( $self->render_byte_val( $counter->{age}{oldestfile}{size} ) )[0],
        oldestfilesizetitle =>
          ( $self->render_byte_val( $counter->{age}{oldestfile}{size} ) )[1],
        oldestfileage => $hdr->format_duration_between(
            DateTime->from_epoch(
                epoch => $counter->{age}{oldestfile}{age} || 0,
                locale => $lang
            ),
            DateTime->now( locale => $lang ),
            precision         => 'seconds',
            significant_units => 2
        ),
        oldestfileagetitle => strftime(
            $self->tl('lastmodifiedformat'),
            localtime( $counter->{age}{oldestfile}{age} || 0 )
        ),

        newestfilename => $cgi->escapeHTML(
            $self->_get_folder_name( $counter->{age}{newestfile}{file} )
        ),
        newestfilepathuri =>
          $self->_get_abs_uri( $counter->{age}{newestfile}{path} ),
        newestfilepathname => $self->{cgi}->escapeHTML(
            $self->_get_folder_name( $counter->{age}{newestfile}{path} )
        ),
        newestfilesize =>
          ( $self->render_byte_val( $counter->{age}{newestfile}{size} ) )[0],
        newestfilesizetitle =>
          ( $self->render_byte_val( $counter->{age}{newestfile}{size} ) )[1],
        newestfileage => $hdr->format_duration_between(
            DateTime->from_epoch(
                epoch => $counter->{age}{newestfile}{age} || 0,
                locale => $lang
            ),
            DateTime->now( locale => $lang ),
            precision         => 'seconds',
            significant_units => 2
        ),
        newestfileagetitle => strftime(
            $self->tl('lastmodifiedformat'),
            localtime( $counter->{age}{newestfile}{age} || 0 )
        ),

        time => time(),
    };

    my $content =
      $self->render_template( $PATH_TRANSLATED, $REQUEST_URI,
        $self->read_template( $self->config( 'template', 'diskusage' ) ),
        $vars );

    return $content;

}

sub _render_disk_usage_details {
    my ( $self, $template ) = @_;
    my $tmpl =
      $template =~ /^'(.*)'$/xms ? $1 : $self->read_template($template);
    my $counter     = $self->{counter};
    my $statfstring = sprintf
      '%s %%d, %s %%d, %s %%d',
      $self->tl('statfiles'),
      $self->tl('statfolders'),
      $self->tl('statsum');
    my $details = q{};
    my $cgi     = $self->{cgi};

    return '[]' if $counter->{size}{all} == 0;

    foreach my $folder ( @{ $self->{folders} } ) {
        my $perc =
          $counter->{size}{all} > 0
          ? 100 * $counter->{size}{path}{$folder} / $counter->{size}{all}
          : 0;
        my $title = sprintf
          '%.2f%%, ' . $statfstring,
          $perc,
          $counter->{count}{files}{$folder}   // 0,
          $counter->{count}{folders}{$folder} // 0,
          $counter->{count}{sum}{$folder}     // 0;
        my @pbv = $self->render_byte_val( $counter->{size}{path}{$folder} );
        my $foldername = $self->_get_folder_name($folder);
        my $uri        = $self->_get_uri($foldername);

        my $vars = {
            foldername      => $cgi->escapeHTML($foldername),
            qfoldername     => $self->quote_ws( $cgi->escapeHTML($foldername) ),
            folderuri       => $REQUEST_URI . $uri,
            foldersize      => $pbv[0],
            foldersizetitle => $pbv[1],
            filecount       => $counter->{count}{files}{$folder} || 0,
            foldercount     => $counter->{count}{folders}{$folder} || 0,
            sumcount        => $counter->{count}{sum}{$folder} || 0,
            percstyle       => sprintf( 'width: %.0f%%;', $perc ),
        };

        $details .=
          $self->render_template( $PATH_TRANSLATED, $REQUEST_URI, $tmpl,
            $vars );
    }
    return $details;
}

sub exec_template_function {
    my ( $self, $fn, $ru, $func, $param ) = @_;
    my $content;
    if ( $func eq 'details' ) {
        $content = $self->_render_disk_usage_details($param);
    }
    elsif ( $func eq 'json' ) {
        if ( $param eq 'treemapdata' ) {
            $content = $self->_collect_treemap_data();
        }
        elsif ( $param eq 'suffixesbycount' ) {
            $content = $self->_collect_suffix_data('count');
        }
        elsif ( $param eq 'suffixesbysize' ) {
            $content = $self->_collect_suffix_data('size');
        }
    }
    return $content
      // $self->SUPER::exec_template_function( $fn, $ru, $func, $param );
}

sub _collect_suffix_data {
    my ( $self, $key ) = @_;
    my $counter = $self->{counter};
    my @data    = map {
        {
            x => $_,
            y => $counter->{suffixes}{$key}{$_},
            l => $key eq 'size'
            ? ( $self->render_byte_val( $counter->{suffixes}{$key}{$_} ) )[0]
            : sprintf '%s',
            $counter->{suffixes}{$key}{$_}
        }
      } reverse sort {
        $counter->{suffixes}{$key}{$a} <=> $counter->{suffixes}{$key}{$b}
          || -( $a cmp $b )
      } keys %{ $counter->{suffixes}{$key} };
    if ( scalar(@data) > $_MAX_SUFFIXES ) {
        my @deleted = splice @data, $_MAX_SUFFIXES;
        my $others = 0;
        foreach my $s (@deleted) { $others += $s->{y} }
        push @data,
          {
            x => $self->tl('du_others'),
            y => $others,
            l => $key eq 'size'
            ? ( $self->render_byte_val($others) )[0]
            : sprintf '%s',
            $others
          };
    }
    return $self->{cgi}
      ->escapeHTML( $self->{json}->encode( { data => \@data } ) );
}

sub _collect_treemap_data {
    my ($self)  = @_;
    my $cgi     = $self->{cgi};
    my $counter = $self->{counter};
    my %mapdata =
      ( id => $REQUEST_URI, uri => $cgi->escape($REQUEST_URI), children => [] );
    my $cc          = 0;
    my $ccst        = 1 / 5;
    my $statfstring = sprintf
      '%s %%d, %s %%d, %s %%d',
      $self->tl('statfiles'),
      $self->tl('statfolders'),
      $self->tl('statsum');

    my ( $filecountall, $sizeall, $maxfilesizesum ) =
      ( $self->{filecountall}, $self->{sizeall}, $self->{maxfilesizesum} );

    return '[]' if $counter->{size}{all} == 0;

    foreach my $folder ( @{ $self->{folders} } ) {

        # collect treemap data:
        my $files        = $counter->{size}{files}{$folder};
        my @childmapdata = ();
        my $foldersize   = $counter->{size}{path}{$folder};
        my @files =
          reverse sort { $files->{$a} cmp $files->{$b} || -( $a cmp $b ) }
          keys %{$files};
        my $foldername = $self->_get_folder_name($folder);
        my $uri        = $self->_get_uri($foldername);
        my $perc =
          $counter->{size}{all} > 0
          ? 100 * $counter->{size}{path}{$folder} / $counter->{size}{all}
          : 0;
        my $title = sprintf
          '%.2f%%, ' . $statfstring,
          $perc,
          $counter->{count}{files}{$folder}   // 0,
          $counter->{count}{folders}{$folder} // 0,
          $counter->{count}{sum}{$folder}     // 0;
        my @pbv = $self->render_byte_val( $counter->{size}{path}{$folder} );

        # limit files for treemap and fix foldersize:
        if ( $self->config( 'filelimit', $_DEFAULT_FFLIMIT ) > 0
            && scalar(@files) >
            $self->config( 'filelimit', $_DEFAULT_FFLIMIT ) )
        {
            splice @files, $self->config( 'filelimit', $_DEFAULT_FFLIMIT );
            $foldersize = 0;
            foreach my $file (@files) { $foldersize += $files->{$file}; }
        }
        foreach my $file (@files) {
            my @pbvfile = $self->render_byte_val( $files->{$file} );
            my $_perc =
              $foldersize > 0 ? ( $files->{$file} // 0 ) / $foldersize : 0;

            my $_uri = $self->_get_uri($foldername);
            push @childmapdata,
              {
                uri   => $_uri,
                title => "<br/>$foldername: $pbv[0] $title",
                val   => $pbvfile[0],
                id    => $file,
                size  => [ _gs($_perc), _gs($_perc), _gs($_perc) ],
                color => [ _gs($cc), _gs($cc), _gs($cc) ]
              };
        }
        my $perccount =
            $filecountall > 0
          ? $counter->{count}{files}{$folder} / $filecountall
          : 0;
        my $percfolder =
          $sizeall > 0 ? $counter->{size}{path}{$folder} / $sizeall : 0;
        my $percfile =
            $maxfilesizesum > 0
          ? $counter->{size}{pathmax}{$folder} / $maxfilesizesum
          : 0;
        push @{ $mapdata{children} },
          {
            id       => $foldername,
            uri      => $uri,
            color    => [ $cc, $cc, $cc ],
            size     => [ _gs($percfolder), _gs($perccount), _gs($percfile) ],
            children => \@childmapdata
          };
        $cc = ( $cc + $ccst > 1 ) ? 0 : $cc + $ccst;
    }
    return $cgi->escapeHTML( $self->{json}->encode( \%mapdata ) );
}

sub _gs {
    my ($v) = @_;
    my $r = sprintf '%.4f', $v;
    $r =~ s/,/./xms;
    return $r;
}

sub _get_folder_name {
    my ( $self, $folder ) = @_;
    my $foldername = $folder;
    $foldername =~ s/^\Q$PATH_TRANSLATED\E//xms;
    if ( $foldername eq q{} ) { $foldername = q{./}; }
    return $foldername;
}

sub _get_uri {
    my ( $self, $relpath ) = @_;
    return join q{/}, map { $self->{cgi}->escape($_) } split m{/}xms, $relpath;
}

sub _get_disk_usage {
    my ( $self, $path, $file, $counter ) = @_;

    my $backend = $self->{backend};

    $file =~ s{^/}{}xms;
    my $full = $path . $file;

    return
      if time() - $counter->{start} >
      $self->config( 'timeout', $_DEFAULT_TIMEOUT );

    my $fullresolved = $backend->resolve($full);
    return if $counter->{visited}{$fullresolved};
    $counter->{visited}{$fullresolved} = 1;

    $counter->{count}{all}{sum}++;
    $counter->{count}{sum}{$path}++;
    if ( $file ne q{} ) { $counter->{count}{subdir}{sum}{$path}{$file}++; }

    if ( $backend->isDir($full) ) {
        $counter->{count}{all}{folders}++;
        $counter->{count}{folders}{$path}++;

        return
          if !$self->config( 'followsymlinks', 1 ) && $backend->isLink($full);

        foreach my $f ( @{ $backend->readDir($full) } ) {
            $f .= $backend->isDir( $full . $f ) ? q{/} : q{};
            $self->_get_disk_usage( $full, $f, $counter );
        }
    }
    else {
        my @stat = $self->{backend}->stat( $path . $file );
        my $age  = $stat[9] // 0;
        my $fs   = $stat[7] // 0;
        $counter->{count}{all}{files}++;
        $counter->{count}{files}{$path}++;

        $counter->{size}{all} += $fs;
        $counter->{size}{path}{$path} += $fs;

        if (  !$counter->{size}{pathmax}{$path}
            || $fs > $counter->{size}{pathmax}{$path} )
        {
            if ( $counter->{size}{pathmax}{$path} ) {
                $counter->{size}{allmaxsum} -=
                  $counter->{size}{pathmax}{$path};
            }
            $counter->{size}{allmaxsum} += $fs;
            $counter->{size}{pathmax}{$path} = $fs;
        }

        if (  !$counter->{age}{oldestfile}{age}
            || $age < $counter->{age}{oldestfile}{age} )
        {
            $counter->{age}{oldestfile} = {
                age  => $age,
                path => $path,
                file => $file,
                size => $fs
            };
        }

        if (  !$counter->{age}{newestfile}{age}
            || $age > $counter->{age}{newestfile}{age} )
        {
            $counter->{age}{newestfile} =
              { age => $age, path => $path, file => $file, size => $fs };
        }

        if (  !$counter->{age}{oldestfolder}{age}
            || $age < $counter->{age}{oldestfolder}{age} )
        {
            $counter->{age}{oldestfolder} = {
                age  => $age,
                path => $path,
                size => $counter->{size}{path}{$path}
            };

        }

        if (  !$counter->{age}{newestfolder}{age}
            || $age > $counter->{age}{newestfolder}{age} )
        {
            $counter->{age}{newestfolder} = {
                age  => $age,
                path => $path,
                size => $counter->{size}{path}{$path}
            };

        }

        if (  !$counter->{age}{lastmodified}
            || $age > ( $counter->{age}{lastmodified}{$path} // 0 ) )
        {
            $counter->{age}{lastmodified}{$path} = $age;

        }

        if (  !$counter->{size}{biggestfile}{age}
            || $fs > $counter->{size}{biggestfile}{size} )
        {
            $counter->{size}{biggestfile} = {
                age  => $age,
                path => $path,
                file => $file,
                size => $fs
            };
        }

        if (  !$counter->{size}{biggestfolder}{age}
            || $counter->{size}{path}{$path} >
            $counter->{size}{biggestfolder}{size} )
        {
            $counter->{size}{biggestfolder} = {
                age  => $counter->{age}{lastmodified}{$path},
                path => $path,
                size => $counter->{size}{path}{$path}
            };
        }

        $counter->{size}{files}{$path}{ $file eq q{} ? q{.} : $file } = $fs;

        if ( $file =~ /([.][^.]+)$/xms && length $1 < $_MAX_SUFFIX_LENGTH ) {
            $counter->{suffixes}{size}{ lc $1 } += $fs;
            $counter->{suffixes}{count}{ lc $1 }++;
        }
    }
    return;
}
1;
