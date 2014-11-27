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
use Authen::Passphrase::MD5Crypt;
use Net::Telnet;

use lib "$Bin";
use ourSession;
use ourLanguage;
use ourTemplate;
use ourUtils;
use ourLDAP;
use ourError;
use lib_crypt;

#
my %_POST = ();

#
sub read_param {
    $_POST{'sid'} = param('sid') || '';
    $_POST{'sid'} =~ s/[^0-9a-f]//g;

    $_POST{'uid'} = param('uid') || '';
    $_POST{'uid'} =~ s/[^0-9a-z\:_\-\.]//g;

    $_POST{'password'} = param('password') || 'jk#$e:012[~';
}

sub check_quota {
    my ( $ldap, $config, $uid ) = @_;

    my $result = "";

    my $tmp = getQuota( $config->{'getquota_host'},
        $config->{'getquota_port'}, $uid );

    if ( $tmp =~ /DISK_USAGE:\s+(\d+?KB).+DISK_QUOTA:\s+(\d+?KB)/sg ) {
        $result .= "Quota ($1/$2)\n";
    }
    else {
        $result .= "Quota (none)\n";
    }

    if ( $tmp =~ /\.MBOX_SIZE:\s+(\d+?KB).+\.MBOX_FILES:\s+(\d+?)/sg ) {
        $result .= ".MBOX ($1/$2)\n";
    }
    else {
        $result .= ".MBOX (none)\n";
    }

    return $result;
}

sub add_user {
    my ( $id, $degree, $password, $name, $role, $custom_name ) = @_;

    my ( $config, $ldap, $code, $result );

    my ( $c, $msg ) = passwordStrength( $id, $password );
    if ( $c < 1 ) {    # lyshie_20110919: password too weak
        $result .= "密碼強度不足，無法建立 ($msg)\n";
        $result .= "Password is too weak. Failed to create. ($msg)\n";
        return $result;
    }

    if ( $degree =~ m/^\d+$/ ) {    # student
        $config = ldap_init_config("m$degree");
        $ldap   = ldap_connect($config);

        my $gid = ldap_query_group_gid( $ldap, $config,
            $config->{'default_group'} );
        my $uid = ldap_query_next_uid( $ldap, $config );

        my $username = "s$id";
        my $hostname = $config->{'realm_short'};

     #        my $home_dir
     #            = "/$hostname/" . $config->{'default_group'} . "/$username";
        my $home_dir = replace_pattern( $config->{'mkhomedir_style'},
            { 'uid' => $username, 'gid' => $config->{'default_group'} } );

=cut
        if ( $degree < 98 ) {    # oz (97, 96, 95...)
            $home_dir
                = "/$hostname/u/" . substr( $username, 0, -2 ) . "/$username";
        }
        else {                   # m98 above
            $home_dir
                = "/$hostname/" . substr( $username, 0, -2 ) . "/$username";
        }
=cut

        my %attrs = (
            uid        => $username,
            loginshell => $config->{'default_shell'},
            uidnumber  => $uid,
            gidnumber  => $gid,
            objectclass =>
                [ 'inetOrgPerson', 'posixAccount', 'shadowAccount' ],
            gecos         => $username,
            cn            => $name,
            homedirectory => $home_dir,
            userpassword  => generatePassword($password),
            description => "create(" . time() . ',' . getRemoteAddr() . ");",
            sn          => $id,
        );
        ( $code, $result ) = ldap_add_user( $ldap, $config, \%attrs );

        if ( !$code ) {
            my $tmp = makeHomeDir(
                $config->{'mkhomedir_host'},
                $config->{'mkhomedir_port'},
                $username, $uid, $gid, $home_dir
            );
            setQuota(
                $config->{'setquota_host'}, $config->{'setquota_port'},
                $username,                  $uid,
                $config->{'realm_short'},   $config->{'quota_size'},
            );

            if ( $tmp =~ m/Return = 0/i ) {
                $result
                    .= "\n完成建立使用者目錄\nCreated user home directory\n\n"
                    . check_quota( $ldap, $config, $username ) . "\n";
            }
            else {
                $result
                    .= "\n無法建立使用者目錄\nFailed to create user home directory\n";
            }
        }
    }
    else {    # non-student
        $config = ldap_init_config("$role");
        $ldap   = ldap_connect($config);

        my $gid = ldap_query_group_gid( $ldap, $config,
            $config->{'default_group'} );
        my $uid = ldap_query_next_uid( $ldap, $config );

        my $username = $custom_name;
        $username =~ s/@.*$//g;
        my $hostname = $config->{'realm_short'};

=cut
        my $home_dir
            = "/$hostname/" . $config->{'default_group'} . "/$username";
=cut

        my $home_dir = replace_pattern( $config->{'mkhomedir_style'},
            { 'uid' => $username, 'gid' => $config->{'default_group'} } );

        my %attrs = (
            uid        => $username,
            loginshell => $config->{'default_shell'},
            uidnumber  => $uid,
            gidnumber  => $gid,
            objectclass =>
                [ 'inetOrgPerson', 'posixAccount', 'shadowAccount' ],
            gecos         => $username,
            cn            => $name,
            homedirectory => $home_dir,
            userpassword  => generatePassword($password),
            description => "create(" . time() . ',' . getRemoteAddr() . ");",
            sn          => $id,
        );
        ( $code, $result ) = ldap_add_user( $ldap, $config, \%attrs );

        if ( !$code ) {
            my $tmp = makeHomeDir(
                $config->{'mkhomedir_host'},
                $config->{'mkhomedir_port'},
                $username, $uid, $gid, $home_dir
            );
            setQuota(
                $config->{'setquota_host'}, $config->{'setquota_port'},
                $username,                  $uid,
                $config->{'realm_short'},   $config->{'quota_size'},
            );

            if ( $tmp =~ m/Return = 0/i ) {
                $result
                    .= "\n完成建立使用者目錄\nCreated user home directory\n\n"
                    . check_quota( $ldap, $config, $username ) . "\n";
            }
            else {
                $result
                    .= "\n無法建立使用者目錄\nFailed to create user home directory\n";
            }
        }
    }

    ldap_disconnect($ldap);

    return $result;
}

sub main {
    read_param();

    my ( $status, $sid, $h ) = sessionCheck( $_POST{'sid'} );

    if ( $status > 0 ) {
        unless ( $h->{'condition_bool'} ) {
            print redirect( -uri => qq{switch-user.cgi?sid=$sid} );
            exit();
        }

        my ( $role, $degree ) = getRole( $h->{'id'} );

        #my $email = getEmailName( $h->{'id'}, $degree, $role );
        my $is_exist = isUserExist( $h->{'id'}, $degree, $role );
        my $is_suspended = isUserSuspended( $h->{'id'}, $degree, $role );

        if ($is_exist) {
            print header( -charset => 'utf-8' );
            print show_user_error(-1);
            exit();
        }

        if ($is_suspended) {
            print header( -charset => 'utf-8' );
            print show_user_error(-3);
            exit();
        }

        my ( $custom_name, $checksum ) = split( /\:/, $_POST{'uid'} );
        my $ret;
        $custom_name = defined($custom_name) ? $custom_name : '';
        $checksum    = defined($checksum)    ? $checksum    : '';
        ( $ret, $checksum ) = lib_crypt::decrypt($checksum);
        if ( ( $ret != 0 ) || ( $custom_name ne $checksum ) ) {
            $custom_name = '';
        }

        my $result
            = add_user( $h->{'id'}, $degree, $_POST{'password'}, $h->{'name'},
            $role, $custom_name );

        my $template = HTML::Template::Pro->new(
            case_sensitive => 1,
            filename       => "$Bin/template/$G_LANG/apply-email.tmpl"
        );

        $template->param( SID    => $sid );
        $template->param( RESULT => $result );

        print header( -charset => 'utf-8', -expires => 'now' ); # later output
        $template->output( print_to => \*STDOUT );
    }
    else {
        print header( -charset => 'utf-8' );
        print show_session_error($status);
    }
}

main();
