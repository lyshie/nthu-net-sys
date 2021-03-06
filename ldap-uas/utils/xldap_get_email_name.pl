#!/usr/bin/perl -w

#
#    Copyright (C) 2011~2014 SHIE, Li-Yi (lyshie) <lyshie@mx.nthu.edu.tw>
#
#    https://github.com/lyshie
#	
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation,  either version 3 of the License,  or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful, 
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not,  see <http://www.gnu.org/licenses/>.
#
use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin";
use ourUtils;

my %_VAR = (
    'ID'     => $ARGV[0] || usage(),
    'DEGREE' => $ARGV[1], 
    'ROLE'   => $ARGV[2],
);

my %COUNT = ();

sub usage {
    print <<EOF
Usage:
\t$0 [ID]    [DEGREE] [ROLE]
\t$0 9800001 98       student
EOF
        ;
    exit(1);
}

sub main {
    print getEmailName( $_VAR{ID}, $_VAR{DEGREE}, $_VAR{ROLE} ), "\n";
}

main();
