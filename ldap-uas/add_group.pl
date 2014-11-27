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
use HTML::Template;
use Net::Telnet;

use lib "$Bin";
use ourTemplate;
use ourLDAP;

#use ourUtils;

my %_GET = ();

sub read_param {
    $_GET{'profile'} = defined( param('profile') ) ? param('profile') : 'm99';
    $_GET{'profile'} =~ s/[^0-9a-zA-Z\-_]//g;

    $_GET{'group'} = defined( param('group') ) ? param('group') : '';

    $_GET{'confirm'} = defined( param('confirm') ) ? param('confirm') : '';

    # lyshie: set default max uidNumber
    my $config    = ldap_init_config( $_GET{'profile'} );
    my $ldap      = ldap_connect($config);
    my $gidnumber = ldap_query_max_gid( $ldap, $config ) + 1;
    $_GET{'gidnumber'}
        = defined( param('gidnumber') ) ? param('gidnumber') : $gidnumber;
    ldap_disconnect($ldap);
}

# lyshie: the following codes should be moved to ourLDAP.pm
sub add_group {
    my ( $group, $gidnumber ) = @_;

    my ( $config, $ldap, $code, $result );

    $config = ldap_init_config( $_GET{'profile'} );
    $ldap   = ldap_connect($config);

    my %attrs = (
        cn          => $group,
        gidnumber   => $gidnumber,
        objectclass => ['posixGroup']
    );

    my @array = %attrs;
    my $ret
        = $ldap->add( "cn=$group," . $config->{'group_dn'}, attr => \@array );

    if ( !$ret->code() ) {
        $result
            .= sprintf( "OK: Create new group [group = %s], [gidNumber = %s]",
            $group, $gidnumber );
    }
    else {
        $result
            .= sprintf(
            "FAIL: Create new group [group = %s], [gidNumber = %s], [error = %s]",
            $group, $gidnumber, $ret->error() );
    }

    ldap_disconnect($ldap);

    return $result;
}

sub do_action {
    my $result  = '';
    my $log_msg = '';

    if ( $_GET{'confirm'} eq '1' ) {
        $log_msg = add_group( $_GET{'group'}, $_GET{'gidnumber'} );
        $result .= $log_msg . "\n";

        _L( $0, $log_msg );    # syslog
    }

    return $result;
}

sub main {
    read_param();

    my $result = do_action();

    my $template
        = HTML::Template->new( filename => getTemplate("add_group.tmpl") );
    $template->param( PROFILE   => $_GET{'profile'} );
    $template->param( CONFIRM   => $_GET{'confirm'} );
    $template->param( GROUP     => _H( $_GET{'group'} ) );
    $template->param( GIDNUMBER => _H( $_GET{'gidnumber'} ) );
    $template->param( RESULT    => _H($result) );

    print header( -charset => 'utf-8' );    # later output
    print $template->output();
}

main();

