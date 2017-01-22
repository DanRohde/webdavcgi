#!/usr/bin/perl
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
# This script builds a sprite.svg file from a bunch of svg files and creates
# a style.css file using this sprite and create a style with inline SVGs.
# The svg files are created with Inkscape with following options:
#       file format: optimized svg
#       optimization options: css to attributes, no xml declaration, no metadata, ...

package main;
use strict;
use warnings;

our $VERSION = '1.0';

use XML::Parser;
use URI::Escape;
use Data::Dumper;


use vars qw( $UID @SETUP);

@SETUP = (
    {
        files => 'fileicons/*.svg',
        symbol => 'symbol-fi-%s',
        icon => 'icon-fi-%s',
        cssdefault => '.icon { background-image: url(svg/sprite.svg#icon-fi-unknown); background-repeat: no-repeat; background-position: left center; background-size: 20px 22px;} .icon:hover,.icon:active,.icon:focus { background-image: url(svg/sprite.svg#icon-fi-unknown-hover); }',
        css => ' .icon.category-%s ',
        hover => 1,
        csshover => ' .icon.category-%s:hover, .icon.category-%s:focus, .icon.category-%s:active ',
        hovercolors => { fill=> { '#808080' => '#000000'} },
        inline => {
            cssdefault => '.icon { background-repeat: no-repeat; background-position: left center; background-size: 20px 22px;} ',
            defaulticon => 'unknown',
            defaulticoncss => ' .icon, ',
            css => ' .icon.category-%s { background-image: url(data:image/svg+xml;utf-8,%s);} ',
            csshover => ' .icon.category-%s:hover, .icon.category-%s:focus, .icon.category-%s:active { background-image: url(data:image/svg+xml;utf8,%s);} '
        },
    },
);


sub fix_ids {
    my ($a,$v) = @_;
    if ($a eq 'id' && $v!~/^(?:icon|symbol|sprite|defs)-/xms) {
        $UID //= 0;
        $UID++;
        return qq{$a="s$UID"};
    }
    return qq{$a="$v"};
}
sub create_xml {
    my ($s,$o) = @_;
    my $content = q{};
    my $i = $o? $o : 0;
    while ($i < @{$s}) {
        my $e = $s->[$i];
        my $c = $s->[$i+1];
        if ($e =~/^0$/xms) {
            $c=~s/^\s*$//xms;
            $content .= $c;
            $i+=2; # skip content
            next;
        }
        $content .= "<$s->[$i]";
        my $a = $c->[0];
        my @ak = sort keys %{$a};
        $content .= @ak > 0 ? q{ }. join q{ }, map { fix_ids($_, $a->{$_}) } @ak : q{};
        if (@{$c} == 0) {
            $content .= q{/>};
        } else {
            $content .= q{>} . create_xml($c,1) . "</$e>";
        }
        $i+=2; # skip content
    }
    return $content;
}
sub replace_colors {
    my ($aref, %colors) = @_;
    for my $i (0 .. $#{$aref}) {
        my $v = $aref->[$i];
        if (ref $v eq 'HASH') {
            foreach my $a (keys %colors) {
                if (exists $v->{$a}) {
                    foreach my $c (keys %{$colors{$a}}) {
                        $v->{$a} =~ s/\Q$c\E/$colors{$a}->{$c}/xmsg;
                    }
                }
            }
        } elsif (ref $v eq 'ARRAY') {
            replace_colors($v, %colors);
        }
    }
    return;
}
sub clone_var {
    my ($v) = @_;
    if (ref $v eq 'ARRAY') {
        my @nv = ();
        foreach my $ae ( @{$v} ) {
            push @nv, clone_var($ae);
        }
        return \@nv;
    } elsif (ref $v eq 'HASH') {
        my %nv = ();
        foreach my $ak ( keys %{$v} ){
            $nv{$ak} = clone_var($v->{$ak});
        }
        return \%nv;
    }
    return $v;
}
sub eliminate_unwanted_g {
    my ($aref) = @_;
    my @na = ();
    my $i = 0;
    while ($i < @{$aref}) {
        my $e = $aref->[$i];
        my $c = $aref->[$i+1];
        if ($e eq 'g') {
            my $a = shift @{$c}; ## get attributes
            delete $a->{id};
            my $ar = eliminate_unwanted_g($c);
            my $j = 1;
            while ($j < @{$ar}) { ## add attributes from g
                if (ref $ar->[$j] eq 'ARRAY') {
                    $ar->[$j]->[0] = { %{$a}, %{$ar->[$j]->[0]} };
                }
                $j+=2;
            }
            push @na, @{$ar};
        } elsif (defined $e && defined $c) {
            push @na, $e, $c;
        }
        $i+=2;
    }
    return \@na;
}

my $parser = XML::Parser->new(ProtocolEncoding=>'UTF-8', Namespaces=>1, Style=>'Tree' );

my $defs = [ {id=>'sprite-defs'} ];
my $svg = [ {id=>'sprite-svg', viewBox=> '0 0 1000 1000', width=>'1e3', height=>'1e3',
             xmlns=>'http://www.w3.org/2000/svg', 'xmlns:xlink' => 'http://www.w3.org/1999/xlink', version=>'1.1'}, 'defs', $defs ];
my $xml = [ 'svg', $svg ];
push @{$defs}, 'style', [ {}, 0, 'g{display:none;}g:target,g:target g{display:inline;}' ];
my $css = q{};

my $inlinecss = q{};

foreach my $setup ( @SETUP ) {
    $css .= $setup->{cssdefault};
    $inlinecss .= $setup->{inline}->{cssdefault};
    for my $file ( glob $setup->{files} ) {
        my $fb = $file=~/^.*\/(.*?)[.]svg$/xms ? ${1} : $file;
        my $symbolid = sprintf $setup->{symbol}, $fb;
        my $iconid   = sprintf $setup->{icon}, $fb;
        my $s = $parser->parsefile($file);

        my $inlinesvg = [ {id=>'s', viewBox=> '0 0 1000 1000', width=>'1e3', height=>'1e3',
                           xmlns=>'http://www.w3.org/2000/svg', version=>'1.1'} ];
        my $inlinexml = [ 'svg', $inlinesvg ];


        shift @{$s->[1]};
        $s->[1] = eliminate_unwanted_g($s->[1]);
        push @{$defs}, 'symbol', [ {id=>$symbolid}, @{$s->[1]} ];
        push @{$svg}, 'g', [ { id=>$iconid }, 'use', [ {'xlink:href' => "\#${symbolid}"} ] ];

        push @{$inlinesvg}, @{$s->[1]};

        $css .= sprintf $setup->{css}, $fb;
        $css .= sprintf '{ background-image: url(svg/sprite.svg#%s); }', $iconid;

        if ($fb eq $setup->{inline}->{defaulticon}) {
            $inlinecss .= $setup->{inline}->{defaulticoncss};
        }
        $inlinecss .= sprintf $setup->{inline}->{css}, $fb, uri_escape(create_xml($inlinexml));

        if ($setup->{hover}) {
            my $scopy = clone_var($s->[1]);
            replace_colors($scopy, %{$setup->{hovercolors}});

            my $inlinehoversvg = [ {id=>'s', viewBox=> '0 0 1000 1000', width=>'1e3', height=>'1e3',
                                    xmlns=>'http://www.w3.org/2000/svg', version=>'1.1'} ];
            my $inlinehoverxml = [ 'svg', $inlinehoversvg ];

            push @{$defs}, 'symbol', [ {id=>"${symbolid}-hover"}, @{$scopy} ];
            push @{$svg}, 'g', [ { id=>"${iconid}-hover"}, 'use', [ {'xlink:href' => "#${symbolid}-hover"} ] ];

            push @{$inlinehoversvg}, @{$scopy} ;

            $css .= sprintf $setup->{csshover}, $fb, $fb, $fb;
            $css .= sprintf '{ background-image: url(svg/sprite.svg#%s-hover); }', $iconid;

            $inlinecss .= sprintf $setup->{inline}->{csshover}, $fb, $fb, $fb, uri_escape(create_xml($inlinehoverxml));

        }
    }
}
if (open my $sfh, '>', 'sprite.svg') {
    print {$sfh} create_xml($xml);
    close $sfh;
}
if (open my $cfh, '>', 'style.css') {
    print {$cfh} $css;
    close $cfh;
}
if (open my $ifh, '>', 'inlinestyle.css') {
    print {$ifh} $inlinecss;
    close $ifh;
}
1;
