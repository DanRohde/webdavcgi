#!/usr/bin/perl
use strict;
use warnings;

our $VERSION = '1.0';

use URI::Escape;
use Encode;
use English qw(-no_match_vars);


local $RS=undef;
print uri_escape(encode('UTF-8', <>));

1;