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

use lib "$Bin";
use ourSession;
use ourLanguage;
use ourTemplate;
use ourUtils;
use ourError;
use ourLDAP;

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

    if ( $status > 0 ) {
        my $template = HTML::Template::Pro->new(
            case_sensitive => 1,
            filename       => "$Bin/template/$G_LANG/portal.tmpl"
        );

        my ( $role, $degree ) = getRole( $h->{'id'} );

        # lyshie_20110411: for testing purpose
        my $http_host = defined( $ENV{'HTTP_HOST'} ) ? $ENV{'HTTP_HOST'} : '';
        if ( $http_host =~ m/^(:?ua2\.net|r309\-2\.cc)/ ) {
            $template->param( IS_TEST => 1 );
        }

        $template->param( SID         => $sid );
        $template->param( NAME        => $h->{'name'} );
        $template->param( NAME_EN     => $h->{'name_en'} );
        $template->param( LANGUAGE    => $h->{'language'} );
        $template->param( ID          => $h->{'id'} );
        $template->param( OPENID      => $h->{'openid'} );
        $template->param( ROLE        => "$role-$degree" );
        $template->param( IP          => $h->{'ip'} );
        $template->param( REMOTE_ADDR => $ENV{'REMOTE_ADDR'} || '' );
        $template->param( PROG        => getProgramName($0) );
        $template->param( IS_SUSPENDED_PASSWORD =>
                isPasswordSuspended( $h->{'id'}, $degree, $role, $sid ) );
        $template->param( IS_STOP_PASSWORD =>
                isPasswordStop( $h->{'id'}, $degree, $role, $sid ) );
        $template->param(
            TIMESTAMP => scalar( localtime( $h->{'timestamp'} ) ) );

        print header( -charset => 'utf-8' );    # later output
        $template->output( print_to => \*STDOUT );
    }
    else {
        print header( -charset => 'utf-8' );
        print show_session_error($status);
    }
}

main();
