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
use Authen::Passphrase;

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
sub password_check {
    my ( $config, $ldap, $mesg, $result );
    my %_NOT_CHANGE  = ();
    my %_SAME_AS_UID = ();

    $config = ldap_init_config( $_GET{'profile'} );
    $ldap   = ldap_connect($config);

    $mesg = $ldap->search(
        base   => $config->{'user_dn'},
        scope  => 'sub',
        filter => '(uid=*)',
        attrs  => [ 'uid', 'userPassword', 'description' ]
    );

    $result = '';
    if ( !$mesg->code() ) {
        foreach my $entry ( $mesg->entries ) {
            my $uid         = $entry->get_value('uid')          || '';
            my $password    = $entry->get_value('userpassword') || '';
            my $description = $entry->get_value('description')  || '';

            my $ppr;
            eval { $ppr = Authen::Passphrase->from_rfc2307($password); };
            if ( $ppr && $ppr->match($uid) ) {
                $_SAME_AS_UID{$uid} = 1;
            }

            if ( $description !~ m/chpasswd/ ) {
                $_NOT_CHANGE{$uid} = 1;
            }
        }

        $result .= sprintf( "帳號與密碼相同者 %s 筆：\n",
            scalar( keys(%_SAME_AS_UID) ) );
        foreach ( sort keys(%_SAME_AS_UID) ) {
            $result .= "$_\n";
        }

        $result
            .= sprintf(
            "\n帳號建立後，尚未變更密碼者 %s 筆：\n",
            scalar( keys(%_NOT_CHANGE) ) );
        foreach ( sort keys(%_NOT_CHANGE) ) {
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

    $log_msg = 'Password check';
    _L( $0, $log_msg );    # syslog

    $result = password_check();

    return $result;
}

sub main {
    read_param();

    my $result = do_action();

    my $template = HTML::Template->new(
        filename => getTemplate("password_check.tmpl") );
    $template->param( RESULT => _H($result) );

    print header( -charset => 'utf-8' );    # later output
    print $template->output();
}

main();

