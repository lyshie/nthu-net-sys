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
use ourUtils;

my %_GET = ();

sub read_param {
    $_GET{'profile'} = defined( param('profile') ) ? param('profile') : 'm99';
    $_GET{'profile'} =~ s/[^0-9a-zA-Z\-_]//g;

    $_GET{'uid'} = defined( param('uid') ) ? param('uid') : '';

    $_GET{'homedirectory'}
        = defined( param('homedirectory') ) ? param('homedirectory') : '';

    $_GET{'confirm'} = defined( param('confirm') ) ? param('confirm') : '';
}

# lyshie: the following codes should be moved to new function
sub do_action {
    my $result  = '';
    my $log_msg = '';

    if ( $_GET{'confirm'} eq '1' ) {
        my $config = ldap_init_config( $_GET{'profile'} );
        my $ldap   = ldap_connect($config);
        my $mesg   = $ldap->modify(
            'uid=' . $_GET{'uid'} . ',' . $config->{'user_dn'},
            replace => { 'homedirectory' => $_GET{'homedirectory'} }
        );

        if ( !$mesg->code() ) {
            my $users = ldap_get_user( $ldap, $config, $_GET{'uid'} );
            if ( $config->{'mkhomedir_host'} =~ m/^.+\-\d+\.$/ )
            {    # lyshie_20110423: multi-hosts
                foreach my $j ( 1 .. 9 )
                {    # lyshie_20110423: bad code! enumerate all hosts
                    my $host = $config->{'mkhomedir_host'};
                    $host =~ s/^(.+\-)\d+(\.)$/$1$j$2/;
                    $log_msg = sprintf(
                        "OK: Change home directory [uid = %s], [homeDirectory = %s], [result = %s], [host = %s]",
                        $_GET{'uid'},
                        $_GET{'homedirectory'},
                        makeHomeDir(
                            $host,
                            $config->{'mkhomedir_port'},
                            $_GET{'uid'},
                            $users->[0]->{'uidnumber'},
                            $users->[0]->{'gidnumber'},
                            $users->[0]->{'homedirectory'}
                        ),
                        $host
                    );
                    $result .= $log_msg . "\n";
                }
            }
            else {
                $log_msg = sprintf(
                    "OK: Change home directory [uid = %s], [homeDirectory = %s], [result = %s]",
                    $_GET{'uid'},
                    $_GET{'homedirectory'},
                    makeHomeDir(
                        $config->{'mkhomedir_host'},
                        $config->{'mkhomedir_port'},
                        $_GET{'uid'},
                        $users->[0]->{'uidnumber'},
                        $users->[0]->{'gidnumber'},
                        $users->[0]->{'homedirectory'}
                    )
                );
                $result .= $log_msg . "\n";
            }
        }
        else {
            $log_msg
                = sprintf(
                "FAIL: Change home directory [uid = %s], [homeDirectory = %s], [error = %s]",
                $_GET{'uid'}, $_GET{'homedirectory'}, $mesg->error() );
            $result .= $log_msg . "\n";
        }

        ldap_disconnect($ldap);

        _L( $0, $log_msg );    # syslog
    }

    return $result;
}

sub main {
    read_param();

    my $result = do_action();

    my $template = HTML::Template->new(
        filename => getTemplate("set_homedirectory.tmpl") );
    $template->param( PROFILE       => $_GET{'profile'} );
    $template->param( UID           => _H( $_GET{'uid'} ) );
    $template->param( CONFIRM       => $_GET{'confirm'} );
    $template->param( HOMEDIRECTORY => _H( $_GET{'homedirectory'} ) );
    $template->param( RESULT        => _H($result) );

    print header( -charset => 'utf-8' );    # later output
    print $template->output();
}

main();
