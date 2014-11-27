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
use YAML::Syck;

use lib "$Bin";
use ourSession;
use ourLanguage;
use ourUtils;
use ourLDAP;
use ourError;

my $REPORT_PATH = "$Bin/report";
my %_POST       = ();

#
sub read_param {
    $_POST{'sid'} = param('sid') || '';
    $_POST{'sid'} =~ s/[^0-9a-f]//g;

    $_POST{'confirm'} = param('confirm') || '';
    $_POST{'message'} = param('message') || '';
}

sub do_report {
    my ( $h, $message ) = @_;

    my $now = time();
    my $yaml_file = sprintf( "%s_%s", "$REPORT_PATH/$now", $_POST{'sid'} );

    my %hash = (
        message   => $message,
        'time'    => $now,
        id        => $h->{'id'},
        ip        => $h->{'ip'},
        timestamp => $h->{'timestamp'},
        name      => $h->{'name'},
        sid       => $_POST{'sid'},
        ua        => $ENV{'HTTP_USER_AGENT'} || '',
    );

    DumpFile( $yaml_file, \%hash );
}

sub main {
    read_param();

    my ( $status, $sid, $h ) = sessionCheck( $_POST{'sid'} );

    if ( $status > 0 ) {
        my ( $role, $degree ) = getRole( $h->{'id'} );

        my $is_exist = isUserExist( $h->{'id'}, $degree, $role );
        my $is_suspended = isUserSuspended( $h->{'id'}, $degree, $role );

        if ($is_suspended) {
            print header( -charset => 'utf-8' );
            print show_user_error(-3);
            exit();
        }

        if ( !$is_exist ) {
            print header( -charset => 'utf-8' );
            print show_user_error(-2);
            exit();
        }

        if ( ( $_POST{'message'} ne '' ) && ( $_POST{'confirm'} eq '1' ) ) {
            do_report( $h, $_POST{'message'} );
            print redirect( -uri => "show-report.cgi?sid=$_POST{'sid'}" );
        }

        print header( -charset => 'utf-8' );
        my $template = HTML::Template::Pro->new(
            case_sensitive => 1,
            filename       => "$Bin/template/$G_LANG/do-report.tmpl"
        );

        $template->param( SID => $sid );
        $template->output( print_to => \*STDOUT );
    }
    else {
        print header( -charset => 'utf-8' );
        print show_session_error($status);
    }
}

main();
