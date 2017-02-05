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
        files  => 'fileicons/*.svg',
        symbol => 'symbol-fi-%n',
        icon   => 'icon-fi-%n',
        cssdefault => '.icon{background-image:url(svg/sprite.svg#icon-fi-unknown);background-repeat:no-repeat;background-position:left center;background-size:20px 22px;}.icon:hover,.icon:active,.icon:focus{background-image:url(svg/sprite.svg#icon-fi-unknown-hover);}',
        css    => '.icon.category-%n{background-image:url(svg/sprite.svg#%i);}',
        hover  => 1,
        csshover    => '.icon.category-%n:hover,.icon.category-%n:focus,.icon.category-%n:active{background-image:url(svg/sprite.svg#%i-hover);}',
        hovercolors => { fill=> { '#808080' => '#000000',}, },
        inline => {
            cssdefault  => '.icon{background-repeat:no-repeat;background-position:left center;background-size:20px 22px;}',
            defaulticon => 'unknown',
            defaulticoncss => ' .icon,',
            defaulticoncsshover => '.icon:hover,.icon:focus,.icon:active,',
            css => '.icon.category-%n{background-image:url(data:image/svg+xml;utf-8,%d);}',
            csshover => '.icon.category-%n:hover,.icon.category-%n:focus,.icon.category-%n:active{background-image:url(data:image/svg+xml;utf8,%d);}',
        },
    },
    {
        files  => 'actionicons/*.svg',
        symbol => 'symbol-ai-%n',
        icon   => 'icon-ai-%n',
        cssdefault => q{},
        css    => '.action.%n{background-image:url(svg/sprite.svg#%i);}',
        hover  => 1,
        csshover    => '.action.%n:hover,.action.%n:focus,.action.%n:active{background-image:url(svg/sprite.svg#%i-hover);}',
        hovercolors => { fill => { '#808080', '#000000',}, },
        inline => {
            cssdefault     => q{},
            defaulticon    => 'action',
            defaulticoncss => q{},
            css      => '.action.%n,.ai-%n,.popup.label.ai-%n,.ui-button.ai-%n,.%ndialog.ui-dialog .ui-dialog-title{background-image:url(data:image/svg+xml;utf8,%d);background-repeat:no-repeat;background-size: 18px 18px;}',
            csshover => '.action.%n:hover,.action.%n:focus,.popup.label.ai-%n:hover,.popup.label.ai-%n:active,.popup.label.ai-%n:focus,.action.%n:active,.ai-%n:hover,.ai-%n:focus,.ai-%n:active,.ui-button.ai-%n:hover,.ui-button.ai-%n:focus,.ui-button.ai-%n:active{background-image:url(data:image/svg+xml;utf8,%d);background-repeat:no-repeat;background-size:18px 18px;}',
        },
    },
    {
        files  => 'symbols/*.svg',
        symbol => 'symbol-%n',
        icon   => 'icon-%n',
        cssdefault => q{},
        css    => '%m{background-image:url(svg/sprite#%i);}',
        csshover    => '%m:hover,%m:focus,.%m:active{background-image:url(svg/sprite.svg#%i-hover);}',
        hover  => 1,
        hovercolors => { fill => { '#808080', '#000000',}, },
        inline => {
            cssdefault => q{},
            defaulticon => 'unknown',
            defaulticoncss => q{},
            css  => '%m,.%n-icon,.%ndialog.ui-dialog .ui-dialog-title{background-image:url(data:image/svg+xml;utf8,%d);background-repeat:no-repeat;background-position-y:center;background-size: 18px 18px;}',
            csshover => '%m:hover,%m:focus,%m:active,.%n-icon:hover,%n-icon:active,%n-icon:focus{background-image:url(data:image/svg+xml;utf8,%d);background-position-y:center;background-repeat:no-repeat;background-size:18px 18px;}',
        },
        mapping => {
            'foldertree-expanded-folder'  => '.mft-node-expander',
            'foldertree-collapsed-folder' => '.mft-collapsed .mft-node-expander',
            'foldertree-empty-folder' => '.mft-node.mft-node-empty .mft-node-expander',
            'foldertree-unreadable-folder' => '.mft-node.mft-node-empty.isreadable-no .mft-node-expander',
            'contact' => '.contact-button',
            'help' => '.help-button',
            'logout' => '.logout-button',
            'stop' => '.action.autorefreshclear',
            'pause' => '.action.autorefreshtoggle.running',
            'play' => '.action.autorefreshtoggle',
            'sum' => '.sum',
            'home' => '.home-button',
            'consumption' => '.foldersize',
            'tooltip-help' => '.tooltip-help',
            'expand-sidebar' => '.action.collapse-sidebar.collapsed',
            'collapse-sidebar' => '.action.collapse-sidebar',
            'expand-head' => '.action.collapse-head.collapsed',
            'collapse-head' => '.action.collapse-head',
        },
    },
);


sub fix_ids {
    my ($a,$v,$e) = @_;
    if ($a eq 'id' && $v!~/^(?:icon|symbol|sprite|defs)-/xms && $e!~/^linearGradient$/) {
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
        $content .= @ak > 0 ? q{ }. join q{ }, map { fix_ids($_, $a->{$_}, $e) } @ak : q{};
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
sub my_sprintf {
    my ($p, %d) = @_;
    foreach (keys %d) {
        $p =~ s/[%]$_/${$d{$_}}/xmsg;
    }
    return $p;
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
        print {*STDERR} "$file\n";
        my $fb = $file=~/^.*\/(.*?)[.]svg$/xms ? ${1} : $file;
        my $symbolid = my_sprintf($setup->{symbol}, n=>\$fb);
        my $iconid   = my_sprintf($setup->{icon}, n=>\$fb);
        my $s = $parser->parsefile($file);

        my $m = $setup->{mapping} ? $setup->{mapping}->{$fb} // $fb : $fb;

        my $inlinesvg = [ {id=>'s', viewBox=> '0 0 1000 1000', width=>'1e3', height=>'1e3',
                           xmlns=>'http://www.w3.org/2000/svg', version=>'1.1'} ];
        my $inlinexml = [ 'svg', $inlinesvg ];


        shift @{$s->[1]};
        $s->[1] = eliminate_unwanted_g($s->[1]);
        push @{$defs}, 'symbol', [ {id=>$symbolid}, @{$s->[1]} ];
        push @{$svg}, 'g', [ { id=>$iconid }, 'use', [ {'xlink:href' => "\#${symbolid}"} ] ];

        push @{$inlinesvg}, @{$s->[1]};

        $css .= my_sprintf($setup->{css}, n=>\$fb, i=>\$iconid, m=>\$m);

        if ($fb eq $setup->{inline}->{defaulticon}) {
            $inlinecss .= $setup->{inline}->{defaulticoncss};
        }
        $inlinecss .= my_sprintf($setup->{inline}->{css}, n=>\$fb, m=>\$m, d=>\uri_escape_utf8(create_xml($inlinexml)));

        if ($setup->{hover}) {
            my $scopy = clone_var($s->[1]);
            replace_colors($scopy, %{$setup->{hovercolors}});

            my $inlinehoversvg = [ {id=>'s', viewBox=> '0 0 1000 1000', width=>'1e3', height=>'1e3',
                                    xmlns=>'http://www.w3.org/2000/svg', version=>'1.1'} ];
            my $inlinehoverxml = [ 'svg', $inlinehoversvg ];

            push @{$defs}, 'symbol', [ {id=>"${symbolid}-hover"}, @{$scopy} ];
            push @{$svg}, 'g', [ { id=>"${iconid}-hover"}, 'use', [ {'xlink:href' => "#${symbolid}-hover"} ] ];

            push @{$inlinehoversvg}, @{$scopy} ;

            $css .= my_sprintf($setup->{csshover}, n =>\$fb, i=>\$iconid, m=>\$m);
        
            if ($fb eq $setup->{inline}->{defaulticon}) {
                $inlinecss .= $setup->{inline}->{defaulticoncsshover} // q{};
            }
            $inlinecss .= my_sprintf($setup->{inline}->{csshover}, n=>\$fb, m=>\$m, d=>\uri_escape_utf8(create_xml($inlinehoverxml)));
            #print STDERR create_xml($inlinehoverxml)."\n";
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
