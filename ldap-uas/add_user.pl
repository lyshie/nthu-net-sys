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
use ourUtils;

my %_GET = ();

sub read_param {
    $_GET{'profile'} = defined( param('profile') ) ? param('profile') : 'm99';
    $_GET{'profile'} =~ s/[^0-9a-zA-Z\-_]//g;

    $_GET{'uid'}
        = defined( param('uid') ) ? param('uid') : 's學號或帳號';

    $_GET{'id'}
        = defined( param('id') ) ? param('id') : '學號或人事編號';

    $_GET{'name'} = defined( param('name') ) ? param('name') : '中文姓名';

    $_GET{'confirm'} = defined( param('confirm') ) ? param('confirm') : '';

    my $c = ldap_init_config( $_GET{'profile'} );

    $_GET{'homedirectory'}
        = defined( param('homedirectory') )
        ? param('homedirectory')
        : $c->{'mkhomedir_style'};
}

sub add_user {
    my ( $uid, $id, $name ) = @_;

    my ( $config, $ldap, $code, $result );

    $config = ldap_init_config( $_GET{'profile'} );
    $ldap   = ldap_connect($config);

    my $gidnumber
        = ldap_query_group_gid( $ldap, $config, $config->{'default_group'} );
    my $uidnumber = ldap_query_next_uid( $ldap, $config );

    my $hostname = $config->{'realm_short'};
    my $home_dir
        = ( $_GET{'homedirectory'} eq '' )
        ? "/$hostname/" . $config->{'default_group'} . "/$uid"
        : $_GET{'homedirectory'};

    my %attrs = (
        uid           => $uid,
        loginshell    => $config->{'default_shell'},
        uidnumber     => $uidnumber,
        gidnumber     => $gidnumber,
        objectclass   => [ 'inetOrgPerson', 'posixAccount', 'shadowAccount' ],
        gecos         => $uid,
        cn            => $name,
        homedirectory => $home_dir,
        userpassword  => '',
        description => "adm-create(" . time() . ',' . getRemoteAddr() . ");",
        sn          => lc($id),
    );

    # lyshie: first, add ldap entry
    ( $code, $result ) = ldap_add_user( $ldap, $config, \%attrs );

    # lyshie: second, make user home directory
    if ( !$code ) {
        $result = sprintf(
            "OK: Add user [uid = %s], [result = %s]",
            $uid,
            $result
                . makeHomeDir(
                $config->{'mkhomedir_host'},
                $config->{'mkhomedir_port'},
                $uid, $uidnumber, $gidnumber, $home_dir
                )
        );
    }
    else {
        $result = sprintf( "FAIL: Add user [uid = %s], [error = %s]",
            $uid, $result );
    }

    ldap_disconnect($ldap);

    return $result;
}

sub do_action {
    my $result  = '';
    my $log_msg = '';

    if ( $_GET{'confirm'} eq '1' ) {
        $log_msg = add_user( $_GET{'uid'}, $_GET{'id'}, $_GET{'name'} );
        $result .= $log_msg . " \n ";

        _L( $0, $log_msg );    # syslog
    }

    return $result;
}

sub main {
    read_param();

    my $result = do_action();

    my $template
        = HTML::Template->new( filename => getTemplate("add_user.tmpl") );
    $template->param( PROFILE       => $_GET{'profile'} );
    $template->param( UID           => _H( $_GET{'uid'} ) );
    $template->param( CONFIRM       => $_GET{'confirm'} );
    $template->param( ID            => _H( $_GET{'id'} ) );
    $template->param( NAME          => _H( $_GET{'name'} ) );
    $template->param( HOMEDIRECTORY => _H( $_GET{'homedirectory'} ) );
    $template->param( RESULT        => _H($result) );

    print header( -charset => 'utf-8' );    # later output
    print $template->output();
}

main();

