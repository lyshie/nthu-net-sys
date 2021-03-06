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

use lib "$Bin";
use ourTemplate;
use ourLDAP;

#use ourUtils;

my %_GET = ();

sub read_param {
    $_GET{'profile'} = defined( param('profile') ) ? param('profile') : 'm99';
    $_GET{'profile'} =~ s/[^0-9a-zA-Z\-_]//g;
}

# lyshie: the following codes should be moved to ourLDAP.pm
sub user_check {
    my ( $config, $ldap, $mesg, $result );
    my %_USER_INCONSISTENT     = ();
    my %_PRIV_INCONSISTENT     = ();
    my %_UIDNUMBER_RANGE_ERROR = ();
    my %_GROUP_NOT_EXIST       = ();

    $config = ldap_init_config( $_GET{'profile'} );
    $ldap   = ldap_connect($config);

    $mesg = $ldap->search(
        base   => $config->{'user_dn'},
        scope  => 'sub',
        filter => '(uid=*)',
        attrs  => [ 'uid', 'sn', 'gecos', 'uidnumber', 'gidnumber' ]
    );

    $result = '';
    if ( !$mesg->code() ) {
        foreach my $entry ( $mesg->entries ) {
            my $uid       = $entry->get_value('uid')       || '';
            my $sn        = $entry->get_value('sn')        || '';
            my $gecos     = $entry->get_value('gecos')     || '';
            my $uidnumber = $entry->get_value('uidnumber') || '0';
            my $gidnumber = $entry->get_value('gidnumber') || '0';

            if ( $uid ne $gecos ) {
                $_USER_INCONSISTENT{$uid} = 1;
            }
            if ( index( $uid, $sn ) == -1 ) {
                $_USER_INCONSISTENT{$uid} = 1;
            }
            if ( index( $gecos, $sn ) == -1 ) {
                $_USER_INCONSISTENT{$uid} = 1;
            }

            if ( ldap_query_group_name( $ldap, $config, $gidnumber ) eq
                $gidnumber )
            {
                $_GROUP_NOT_EXIST{$uid} = 1;
            }

            if ( ( $uidnumber eq 0 ) || ( $gidnumber eq 0 ) ) {
                $_PRIV_INCONSISTENT{$uid} = 1;
            }

            if (   ( $uidnumber < $config->{'min_uid'} )
                || ( $uidnumber > $config->{'max_uid'} ) )
            {
                $_UIDNUMBER_RANGE_ERROR{$uid} = 1;
            }
        }

        $result .= sprintf( "帳號名稱不一致者 %s 筆：\n",
            scalar( keys(%_USER_INCONSISTENT) ) );
        foreach ( sort keys(%_USER_INCONSISTENT) ) {
            $result .= "$_\n";
        }

        $result .= sprintf( "\n權限異常者 %s 筆：\n",
            scalar( keys(%_PRIV_INCONSISTENT) ) );
        foreach ( sort keys(%_PRIV_INCONSISTENT) ) {
            $result .= "$_\n";
        }

        $result .= sprintf( "\nuidNumber 範圍異常者 %s 筆：\n",
            scalar( keys(%_UIDNUMBER_RANGE_ERROR) ) );
        foreach ( sort keys(%_UIDNUMBER_RANGE_ERROR) ) {
            $result .= "$_\n";
        }

        $result .= sprintf( "\n帳號所屬群組不存在者 %s 筆：\n",
            scalar( keys(%_GROUP_NOT_EXIST) ) );
        foreach ( sort keys(%_GROUP_NOT_EXIST) ) {
            $result .= "$_\n";
        }
    }
    else {
        $result = $mesg->error();
    }

    ldap_disconnect($ldap);

    return $result;
}

sub do_action {
    my $result  = '';
    my $log_msg = '';

    $log_msg = 'User check';
    _L( $0, $log_msg );    # syslog

    $result = user_check();

    return $result;
}

sub main {
    read_param();

    my $result = do_action();

    my $template
        = HTML::Template->new( filename => getTemplate("user_check.tmpl") );
    $template->param( RESULT => _H($result) );

    print header( -charset => 'utf-8' );    # later output
    print $template->output();
}

main();

