#!/usr/bin/perl
#########################################################################
# (C) ZE CMS, Humboldt-Universitaet zu Berlin
# Written 2010-2011 by Daniel Rohde <d.rohde@cms.hu-berlin.de>
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

package WebDAV::Search;

use strict;
#use warnings;

use Date::Parse;

use vars qw( %CACHE );

use WebDAV::Common;
our @ISA = ( 'WebDAV::Common' );

sub new {
       my $this = shift;
       my $class = ref($this) || $this;
       my $self = { };
       bless $self, $class;
       $$self{config}=shift;
       $self->initialize();
       return $self;
}

sub getSchemaDiscovery {
	my ($self, $ru, $resps) =  @_;
	push @{$resps}, { href=>$ru, status=>'207 Multistatus',
			'query-schema'=> { basicsearchschema=> { properties => {
				propdesc => [
					{ 'any-other-property'=>undef, searchable=>undef, selectable=>undef, caseless=>undef, sortable=>undef }
				]
			}, operators => { 'opdesc allow-pcdata="yes"' =>
							[
								{ like => undef, 'operand-property'=>undef, 'operand-literal'=>undef },
								{ contains => undef }
							]
			}}}};
}
sub buildExprFromBasicSearchWhereClause {
        my ($self,$op, $xmlref, $superop) = @_;
        my ($expr,$type) = ( '', '', undef);
        my $ns = '{DAV:}';
        if (!defined $op) {
                my @ops = keys %{$xmlref};
                return $self->buildExprFromBasicSearchWhereClause($ops[0], $$xmlref{$ops[0]});
        }

        $op=~s/\Q$ns\E//;
        $type='bool';

        if (ref($xmlref) eq 'ARRAY') {
                foreach my $oo (@{$xmlref}) {
                        my ($ne,$nt) = $self->buildExprFromBasicSearchWhereClause($op, $oo, $superop);
                        my ($nes,$nts) = $self->buildExprFromBasicSearchWhereClause($superop, undef, $superop);
                        $expr.= $nes if $expr ne "";
                        $expr.= "($ne)";
                }
                return $expr;
        }

        study $op;
        if ($op =~ /^(and|or)$/) {
                if (ref($xmlref) eq 'HASH') {
                        foreach my $o (keys %{$xmlref}) {
                                $expr .= $op eq 'and' ? ' && ' : ' || ' if $expr ne "";
                                my ($ne, $nt) =  $self->buildExprFromBasicSearchWhereClause($o, $$xmlref{$o}, $op);
                                $expr .= "($ne)";
                        }
                } else {
                        return $op eq 'and' ? ' && ' : ' || ';
                }
        } elsif ($op eq 'not') {
                my @k = keys %{$xmlref};
                my ($ne,$nt) = $self->buildExprFromBasicSearchWhereClause($k[0], $$xmlref{$k[0]});
                $expr="!($ne)";
        } elsif ($op eq 'is-collection') {
                $expr="getPropValue(\$self,'{DAV:}iscollection',\$filename,\$request_uri)==1";
        } elsif ($op eq 'is-defined') {
                my ($ne,$nt)=$self->buildExprFromBasicSearchWhereClause('{DAV:}prop',$$xmlref{'{DAV:}prop'});
                $expr="$ne ne '__undef__'";
        } elsif ($op =~ /^(language-defined|language-matches)$/) {
                $expr='0!=0';
        } elsif ($op =~ /^(eq|lt|gt|lte|gte)$/) {
                my $o = $op;
                my ($ne1,$nt1) = $self->buildExprFromBasicSearchWhereClause('{DAV:}prop',$$xmlref{'{DAV:}prop'});
                my ($ne2,$nt2) = $self->buildExprFromBasicSearchWhereClause('{DAV:}literal', $$xmlref{'{DAV:}literal'});
                $ne2 =~ s/'/\\'/sg;
                $ne2 = $main::SEARCH_SPECIALCONV{$nt1} ? $main::SEARCH_SPECIALCONV{$nt1}."('$ne2')" : "'$ne2'";
                my $cl= $$xmlref{'caseless'} || $$xmlref{'{DAV:}caseless'} || 'yes';
                $expr = (($nt1 =~ /(string|xml)/ && $cl ne 'no')?"lc($ne1)":$ne1)
                      . ' '.($main::SEARCH_SPECIALOPS{$nt1}{$o} || $o).' '
                      . (($nt1 =~ /(string|xml)/ && $cl ne 'no')?"lc($ne2)":$ne2);
        } elsif ($op eq 'like') {
                my ($ne1,$nt1) = $self->buildExprFromBasicSearchWhereClause('{DAV:}prop',$$xmlref{'{DAV:}prop'});
                my ($ne2,$nt2) = $self->buildExprFromBasicSearchWhereClause('{DAV:}literal', $$xmlref{'{DAV:}literal'});
                $ne2=~s/\//\\\//gs;     ## quote slashes
                $ne2=~s/(?<!\\)_/./gs;  ## handle unescaped wildcard _ -> .
                $ne2=~s/(?<!\\)%/.*/gs; ## handle unescaped wildcard % -> .*
                my $cl= $$xmlref{'caseless'} || $$xmlref{'{DAV:}caseless'} || 'yes';
                $expr = "$ne1 =~ /$ne2/s" . ($cl eq 'no'?'':'i');
        } elsif ($op eq 'contains') {
                my $content = ref($xmlref) eq "" ? $xmlref : $$xmlref{content};
                my $cl = ref($xmlref) eq "" ? 'yes' : ($$xmlref{caseless} || $$xmlref{'{DAV:}caseless'} || 'yes');
                $content=~s/\//\\\//g;
                $expr="\Q$$self{backend}\E->getFileContent(\$filename) =~ /\\Q$content\\E/s".($cl eq 'no'?'':'i');
        } elsif ($op eq 'prop') {
                my @props = keys %{$xmlref};
                $props[0] =~ s/'/\\'/sg;
                $expr = "getPropValue(\$self,'$props[0]',\$filename,\$request_uri)";
                $type = $main::SEARCH_PROPTYPES{$props[0]} || $main::SEARCH_PROPTYPES{default};
                $expr = $main::SEARCH_SPECIALCONV{$type}."($expr)" if exists $main::SEARCH_SPECIALCONV{$type};
        } elsif ($op eq 'literal') {
                $expr = ref($xmlref) ne "" ? convXML2Str($xmlref) : $xmlref;
                $type = $op;
        } else {
                $expr= $xmlref;
                $type= $op;
        }

        return ($expr, $type);
}
sub getPropValue {
        my ($self,$prop, $fn, $uri) = @_;
        my (%stat,%r200,%r404);

        return $CACHE{getPropValue}{$fn}{$prop} if exists $CACHE{getPropValue}{$fn}{$prop};

        my $propname = $prop;
        $propname=~s/^{[^}]*}//;

        my $propval = grep(/^\Q$propname\E$/,@main::PROTECTED_PROPS)==0 ? $$self{db}->db_getProperty($fn, $prop) : undef;

        if (! defined $propval) {
                main::getPropertyModule()->getProperty($fn, $uri, $propname, undef, \%r200, \%r404) ;
                $propval = $r200{prop}{$propname};
        }

        $propval = defined $propval ? $propval : '__undef__';

        $CACHE{getPropValue}{$fn}{$prop} = $propval;

        return $propval;
}
sub convXML2Str {
        my ($xml) = @_;
        return defined $xml ? lc(create_xml($xml,1)) : $xml;
}
sub doBasicSearch {
        my ($self,$expr, $base, $href, $depth, $limit, $matches, $visited) = @_;
        return if defined $limit && $limit > 0 && $#$matches + 1 >= $limit;

        return if defined $depth && $depth ne 'infinity' && $depth < 0 ;

        $base.='/' if $$self{backend}->isDir($base) && $base !~ /\/$/;
        $href.='/' if $$self{backend}->isDir($base) && $href !~ /\/$/;

        my $filename = $base;
        my $request_uri = $href;

        my $res = eval  $expr ;
        if ($@) {
                warn("doBasicSearch: problem in $expr: $@");
        } elsif ($res) {
                push @{$matches}, { fn=> $base, href=> $href };
        }
        my $nbase = $$self{backend}->resolve($base);
        return if exists $$visited{$nbase} && ($depth eq 'infinity' || $depth < 0);
        $$visited{$nbase}=1;

        if ($$self{backend}->isDir($base) && $$self{backend}->isReadable($base)) {
                foreach my $sf (@{$$self{backend}->readDir($base,main::getFileLimit($base),$$self{utils})}) {
                        my $nbase = $base.$sf;
                        my $nhref = $href.$sf;
                        $self->doBasicSearch($expr, $base.$sf, $href.$sf, defined $depth  && $depth ne 'infinity' ? $depth - 1 : $depth, $limit, $matches, $visited);
                }
        }
}
sub handleBasicSearch {
        my ($self,$xmldata, $resps, $error) = @_;
        # select > (allprop | prop)
        my ($propsref,  $all, $noval) = main::handlePropFindElement($$xmldata{'{DAV:}select'});
        # where > op > (prop,literal)
        my ($expr,$type) =  $self->buildExprFromBasicSearchWhereClause(undef, $$xmldata{'{DAV:}where'});
        # from > scope+ > (href, depth, include-versions?)
        my @scopes;
        if (ref($$xmldata{'{DAV:}from'}{'{DAV:}scope'}) eq 'HASH') {
                push @scopes, $$xmldata{'{DAV:}from'}{'{DAV:}scope'};
        } elsif (ref($$xmldata{'{DAV:}from'}{'{DAV:}scope'}) eq 'ARRAY') {
                push @scopes, @{$$xmldata{'{DAV:}from'}{'{DAV:}scope'}};
        } else {
                push @scopes, { '{DAV:}href'=>$main::REQUEST_URI, '{DAV:}depth'=>'infinity'};
        }
        # limit > nresults
        my $limit = $$xmldata{'{DAV:}limit'}{'{DAV:}nresults'};

        my $host = $$self{cgi}->http('Host');
        my @matches;
        foreach my $scope (@scopes) {
                my $depth = $$scope{'{DAV:}depth'};
                my $href = $$scope{'{DAV:}href'};
                my $base = $href;
                $base =~ s@^(https?://([^\@]+\@)?\Q$host\E(:\d+)?)?$main::VIRTUAL_BASE@@;
                $base = $main::DOCUMENT_ROOT.main::uri_unescape(main::uri_unescape($base));

                if (!$$self{backend}->exists($base)) {
                        push @{$error}, { 'search-scope-valid'=> { response=> { href=>$href, status=>'HTTP/1.1 404 Not Found' } } };
                        return;
                }
                $self->doBasicSearch($expr, $base, $href, $depth, $limit, \@matches);
        }
        # orderby > order+ (caseless=(yes|no))> (prop|score), (ascending|descending)?
        my $sortfunc="";
        if (exists $$xmldata{'{DAV:}orderby'} && $#matches>0) {
                my @orders;
                if (ref($$xmldata{'{DAV:}orderby'}{'{DAV:}order'}) eq 'ARRAY') {
                        push @orders, @{$$xmldata{'{DAV:}orderby'}{'{DAV:}order'}};
                } elsif (ref($$xmldata{'{DAV:}orderby'}{'{DAV:}order'}) eq 'HASH') {
                        push @orders, $$xmldata{'{DAV:}orderby'}{'{DAV:}order'};
                }
                foreach my $order (@orders) {
                        my @props = keys %{$$order{'{DAV:}prop'}};
                        my $prop = $props[0] || '{DAV:}displayname';
                        my $proptype = $main::SEARCH_PROPTYPES{$prop} || $main::SEARCH_PROPTYPES{default};
                        my $type = $$order{'{DAV:}descending'} ?  'descending' : 'ascending';
                        my($ta,$tb,$cmp);
                        $ta = qq@getPropValue(\$self,'$prop',\$\$a{fn},\$\$a{href})@;
                        $tb = qq@getPropValue(\$self,'$prop',\$\$b{fn},\$\$b{href})@;
                        if ($main::SEARCH_SPECIALCONV{$proptype}) {
                                $ta = $main::SEARCH_SPECIALCONV{$proptype}."($ta)";
                                $tb = $main::SEARCH_SPECIALCONV{$proptype}."($tb)";
                        }
                        $cmp = $main::SEARCH_SPECIALOPS{$proptype}{cmp} || 'cmp';
                        $sortfunc.=" || " if $sortfunc ne "";
                        $sortfunc.="$ta $cmp $tb" if $type eq 'ascending';
                        $sortfunc.="$tb $cmp $ta" if $type eq 'descending';
                }
        }
        $sortfunc = 'return $$a{fn} cmp $$b{fn} ' if $sortfunc eq '';

        foreach my $match ( sort { eval($sortfunc) } @matches ) {
                push @{$resps}, { href=> $$match{href}, propstat=>main::getPropStat($$match{fn},$$match{href},$propsref,$all,$noval) };
        }

}

1;
