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
# sizelimit - file size limit (default: 2097152 (=2MB)) 
# chunksize - chunk size (bytes in a row, default: 16) 

package WebInterface::Extension::HexDump;

use strict;

use WebInterface::Extension;
our @ISA = qw( WebInterface::Extension  );


sub init { 
	my($self, $hookreg) = @_; 
	my @hooks = ('css','locales','javascript', 'gethandler','fileactionpopup');
	$hookreg->register(\@hooks, $self);
	
	$$self{sizelimit} = $self->config('sizelimit', 2097152);
	$$self{chunksize} = $self->config('chunksize', 16);
}
sub handle { 
	my ($self, $hook, $config, $params) = @_;
	my $ret = $self->SUPER::handle($hook, $config, $params);
	return $ret if $ret;
	
	my $cgi = $$self{cgi};
	if ($hook eq 'fileactionpopup') {
		$ret =  { action=>'hexdump', label=>'hexdump',  classes=>'access-readable', type=>'li' };
	} elsif ($hook eq 'gethandler' && $cgi->param('action') eq 'hexdump') {
		my $content = $cgi->div({title=>$self->tl('hexdump')},
			$cgi->div($cgi->escapeHTML($cgi->param('file'))) 
			.$cgi->pre({class=>'hexdump'}, $cgi->escapeHTML($self->renderHexDump($cgi->param('file')))));
		main::printCompressedHeaderAndContent('200 OK','text/html', $content, 'Cache-Control: no-cache, no-store');
		$ret = 1;
	}
	 
	return $ret;
}
sub renderHexDump {
	my ($self,$filename) = @_;
	my $chunksize = $$self{chunksize};
	my $hexstrlen = $chunksize * 2 + $chunksize/2 - 1;
        my $content ='';
        my $file = $$self{backend}->getLocalFilename($main::PATH_TRANSLATED.$filename);
        if (open(my $fh, '<', $file)) {
                binmode $fh;
                my $buffer;
                my $counter= 0;
                while (my $bytesread = read($fh, $buffer, $chunksize)) {
                        my @unpacked = unpack('W' x $bytesread, $buffer);
                        my $hexmap = join("", map { sprintf('%02x',$_) } @unpacked);
                        $content.=sprintf("\%07x: \%-${hexstrlen}s  \%s\n",
                        		$counter++ *$chunksize,
                        		join(' ', ($hexmap=~/(....)/g)),
                        		join('', map { chr($_) =~ /([[:print:]])/ ? $1 : '.' } @unpacked)
                	);
                	last if $counter * $chunksize > $$self{sizelimit};
                }
                close($fh);
        }
        return $content;
}

1;