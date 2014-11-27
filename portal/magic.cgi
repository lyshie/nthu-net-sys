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

use CGI qw(:standard);
use FindBin qw($Bin);
use HTML::Template::Pro;
use File::stat;

use lib "$Bin";
use ourSession;
use ourLanguage;
use ourUtils;
use ourLDAP;
use ourError;

#
my %_GET       = ();
my $MAGIC_PATH = "$Bin/magic";

#
sub read_param {
    $_GET{'sid'} = param('sid') || '';
    $_GET{'sid'} =~ s/[^0-9a-f]//g;

    $_GET{'magic'} = param('magic') || '';
    $_GET{'magic'} =~ s/[^0-9a-zA-Z]//g;
}

sub _clean_old_magic {
    my @files = ();

    opendir( DH, "$MAGIC_PATH" );
    @files = grep { -f "$MAGIC_PATH/$_" } readdir(DH);
    closedir(DH);

    my $now = time();
    foreach (@files) {
        my $st = stat("$MAGIC_PATH/$_");
        unlink("$MAGIC_PATH/$_") if ( ( $now - $st->atime() ) > 600 );
    }
}

sub main {
    read_param();

    my $file = "$MAGIC_PATH/$_GET{'magic'}";
    if ( -f $file ) {
        print header( -charset => 'utf-8', -type => 'text/plain' );
        print "OK\n";
        unlink($file);
    }
    else {
        print header( -charset => 'utf-8', -type => 'text/plain' );
        print "FAIL\n";
    }

    _clean_old_magic();
}

main();
