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
use HTML::StripTags qw(strip_tags);

my $CMD  = $ARGV[0] or usage("ERROR: No given command name!\n");
my $ARGS = $ARGV[1] or usage("ERROR: No given arguments!\n");

sub usage {
    my ($msg) = @_;

    warn($msg);

    print STDERR <<EOF;
Usage:
    $0 [action | command] "key1=value1&key2=value2..."
EOF

    exit(-1);
}

sub find_commands {
    my ($cmd_pattern) = @_;

    $cmd_pattern =~ s/\..*$//g;    # strip filename extension

    my @cmds = ();
    opendir( DH, $Bin );
    @cmds = grep { m/^\Q$cmd_pattern\E\.(pl|cgi)$/ && -f "$Bin/$_" }
        readdir(DH);
    closedir(DH);

    @cmds = map {"$Bin/$_"} @cmds;

    return ( sort(@cmds) )[0];
}

sub main {
    my $command = find_commands($CMD);

    if ($command) {    # found command to run
        my $result = '';
        $result = qx($command "$ARGS");

        # strip all html tags
        if ( $result =~ m{<pre[^<>]*>(.*)</pre>}s ) {
            my $msg = $1;
            $msg = strip_tags($msg);
            $msg =~ s/[\n\r]//g;
            print "$msg\n";
        }
    }
    else {             # command not found
        die("ERROR: Cannot find at least one command!");
    }
}

main;
