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

use lib "$Bin";
use ourSession;
use ourLanguage;
use ourUtils;
use ourError;

#
my %_GET = ();

#
sub read_param {
    $_GET{'sid'} = param('sid') || '';
    $_GET{'sid'} =~ s/[^0-9a-f]//g;
}

sub main {
    read_param();

    my ( $status, $sid, $h ) = sessionCheck( $_GET{'sid'} );

    if ( $status > 0 ) {    # session ok
        my ( $role, $degree ) = getRole( $h->{'id'} );

        if ( isUserSuspended( $h->{'id'}, $degree, $role ) )
        {                   # suspended => failed
            print header( -charset => 'utf-8' );
            print show_user_error(-3);
        }
        elsif ( !isUserExist( $h->{'id'}, $degree, $role ) )
        {                   # not exist => failed
            print header( -charset => 'utf-8' );
            print show_user_error(-2);
        }
        else {              # otherwise => ok
            print redirect( -uri => qq{view-log.cgi?sid=$sid} );
        }
    }
    else {                  # session failed
        print header( -charset => 'utf-8' );
        print show_session_error($status);
    }
}

main();
