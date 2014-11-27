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

use CGI::Session;
use FindBin qw($Bin);
use Data::Dump;

my $SESSION_PATH = "$Bin/../../portal/tmp";

sub get_sessions {
    opendir( DH, $SESSION_PATH );
    my @sessions = grep { -f "$SESSION_PATH/$_" } readdir(DH);
    closedir(DH);

    return map { substr( $_, 8 ) } @sessions;
}

sub main {
    my @sessions = get_sessions();

    foreach my $sid (@sessions) {
        print "=" x 10, " $sid ", "=" x 10, "\n";
        my $s
            = CGI::Session->load( "driver:file;serializer:FreezeThaw;id:md5",
            $sid, { 'Directory' => "$SESSION_PATH" } );
        if ( !$s->is_expired() && !$s->is_empty() ) {
            my $data = $s->dataref();
            foreach ( sort keys(%$data) ) {
                if ( $data->{$_} =~ m/^\d{10,10}$/ ) {
                    printf(
                        "%20s = %s (%s)\n",
                        $_, scalar( localtime( $data->{$_} ) ),
                        $data->{$_}
                    );
                }
                else {
                    printf( "%20s = %s\n", $_, $data->{$_} );
                }
            }
        }
        print "\n";
    }
}

main;
