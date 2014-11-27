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

# lyshie: constant, return code
sub RET_NULL     {0}
sub RET_WARNING  {1}
sub RET_ERROR    {2}
sub RET_CRITICAL {4}

my %_GET = ();

sub read_param {
    $_GET{'profile'} = defined( param('profile') ) ? param('profile') : 'm99';
    $_GET{'profile'} =~ s/[^0-9a-zA-Z\-_]//g;

    $_GET{'uid'} = defined( param('uid') ) ? param('uid') : '';
    $_GET{'uidnumber'}
        = defined( param('uidnumber') ) ? param('uidnumber') : '';
    $_GET{'gidnumber'}
        = defined( param('gidnumber') ) ? param('gidnumber') : '';
}

sub check_uid_duplicate {
    my ( $ldap, $config ) = @_;

    my $ret_code = RET_NULL();
    my $result   = "<span class=\"title\">check_uid_duplicate()</span><br />";

    my $ref;
    my $ref_sp;
    $ref = ldap_get_users( $ldap, $config, undef,
        "(uidnumber=$_GET{'uidnumber'})" );

    $ref_sp = ldap_get_users(
        $ldap, $config,
        $config->{'suspended_user_dn'},
        "(uidnumber=$_GET{'uidnumber'})"
    );

    my $num_active   = scalar( @{$ref} );
    my $num_inactive = scalar( @{$ref_sp} );
    my $total        = $num_active + $num_inactive;

    if ( $total == 1 ) {
        $result .= "沒問題！<br />";
    }
    else {
        $ret_code = RET_ERROR();
        $result
            .= "<span class=\"error\">存在有 $total 個相同 uidNumber ($_GET{'uidnumber'}) 的帳號。</span><br />";
    }

    return ( $ret_code, $result );
}

sub check_gid_exist {
    my ( $ldap, $config ) = @_;

    my $ret_code = RET_NULL();
    my $result   = "<span class=\"title\">check_gid_exist()</span><br />";

    my $group_name
        = ldap_query_group_name( $ldap, $config, $_GET{'gidnumber'} );

    if ( $group_name ne $_GET{'gidnumber'} ) {
        $result .= "沒問題！<br />";
    }
    else {
        $ret_code = RET_WARNING();
        $result
            .= "<span class=\"warning\">找不到對應的群組名稱。</span><br />";
    }

    return ( $ret_code, $result );
}

sub check_home_dir {
    my ( $ldap, $config ) = @_;

    my $ret_code = RET_NULL();
    my $result   = "<span class=\"title\">check_home_dir()</span><br />";

    my $realm = $config->{'realm_short'};
    my $group_name
        = ldap_query_group_name( $ldap, $config, $_GET{'gidnumber'} );
    my $user = ldap_get_user( $ldap, $config, $_GET{'uid'} );

    my $homedir = $user->[0]->{'homedirectory'};
    my $right_homedir
        = replace_pattern( $config->{'mkhomedir_style'}, $user->[0] );

    if ( $homedir eq $right_homedir ) {
        $result .= "沒問題！<br />";
    }
    else {
        $ret_code = RET_WARNING();
        $result
            .= "<span class=\"warning\">目錄名稱不符合格式 ($homedir != $right_homedir)。</span><br />";
    }

    return ( $ret_code, $result );
}

sub check_user_password {
    my ( $ldap, $config ) = @_;

    my $ret_code = RET_NULL();
    my $result   = "<span class=\"title\">check_user_password()</span><br />";

    my $user = ldap_get_user( $ldap, $config, $_GET{'uid'} );

    my $userpassword = $user->[0]->{'userpassword'};

    if ( $userpassword =~ /^{CRYPT}/ ) {
        $result .= "沒問題！<br />";
    }
    else {
        $ret_code = RET_ERROR();
        $result
            .= "<span class=\"error\">密碼不符合格式 (^{CRYPT})。</span><br />";
    }

    return ( $ret_code, $result );
}

sub check_login_shell {
    my ( $ldap, $config ) = @_;

    my $ret_code = RET_NULL();
    my $result   = "<span class=\"title\">check_login_shell()</span><br />";

    my $user = ldap_get_user( $ldap, $config, $_GET{'uid'} );

    my $loginshell = $user->[0]->{'loginshell'};

    if ( $loginshell eq $config->{'default_shell'} ) {
        $result .= "沒問題！<br />";
    }
    else {
        $ret_code = RET_WARNING();
        $result
            .= "<span class=\"warning\">[$loginshell] 不是預設的登入 Shell ($config->{'default_shell'})。</span><br />";
    }

    return ( $ret_code, $result );
}

sub check_name_consisten {
    my ( $ldap, $config ) = @_;

    my $ret_code = RET_NULL();
    my $result = "<span class=\"title\">check_name_consisten()</span><br />";

    my $user = ldap_get_user( $ldap, $config, $_GET{'uid'} );

    my $uid   = defined( $user->[0]->{'uid'} )   ? $user->[0]->{'uid'}   : '';
    my $gecos = defined( $user->[0]->{'gecos'} ) ? $user->[0]->{'gecos'} : '';
    my $sn    = defined( $user->[0]->{'sn'} )    ? $user->[0]->{'sn'}    : '';
    my $cn    = defined( $user->[0]->{'cn'} )    ? $user->[0]->{'cn'}    : '';

    if ( $uid ne $gecos ) {
        $ret_code = RET_CRITICAL();
        $result
            .= "<span class=\"warning\">[uid = $uid] 不同於 [gecos = $gecos]。</span><br />";
    }

    if ( index( $uid, $sn ) == -1 ) {
        $ret_code = RET_ERROR();
        $result
            .= "<span class=\"warning\">學生帳號：[sn = $sn] 不為 [uid = $uid] 的子字串。</span><br />";
    }

    if ( $cn eq '' ) {
        $ret_code = RET_ERROR();
        $result
            .= "<span class=\"warning\">[cn = $cn] 為空字串。</span><br />";
    }

    if ( $ret_code == RET_NULL() ) {
        $result .= "沒問題！<br />";
    }

    return ( $ret_code, $result );
}

sub check_quota {
    my ( $ldap, $config ) = @_;

    my $ret_code = RET_NULL();
    my $result   = "<span class=\"title\">check_quota()</span><br />";

    my $tmp = getQuota(
        $config->{'getquota_host'},
        $config->{'getquota_port'},
        $_GET{'uid'}
    );

    if ( $tmp =~ /DISK_USAGE:\s+(\d+?KB).+DISK_QUOTA:\s+(\d+?KB)/sg ) {
        $result .= "Quota 沒問題！ ($1/$2)<br />";
    }
    else {
        $ret_code = RET_ERROR();
        $result
            .= "<span class=\"error\">Quota 沒有設定 (none)。</span><br />";
    }

    if ( $tmp =~ /\.MBOX_SIZE:\s+(\d+?KB).+\.MBOX_FILES:\s+(\d+?)/sg ) {
        $result .= ".MBOX 沒問題！ ($1/$2)<br />";
    }
    else {
        $ret_code = RET_ERROR();
        $result
            .= "<span class=\"error\">.MBOX 沒有設定 (none)。</span><br />";
    }

    return ( $ret_code, $result );
}

sub do_action {
    my $ret_code = 0;
    my $result   = '';
    my $tmp      = '';

    my $config = ldap_init_config( $_GET{'profile'} );
    my $ldap   = ldap_connect($config);

    ( $ret_code, $tmp ) = check_uid_duplicate( $ldap, $config );
    $result .= $tmp;

    ( $ret_code, $tmp ) = check_gid_exist( $ldap, $config );
    $result .= $tmp;

    ( $ret_code, $tmp ) = check_home_dir( $ldap, $config );
    $result .= $tmp;

    ( $ret_code, $tmp ) = check_user_password( $ldap, $config );
    $result .= $tmp;

    ( $ret_code, $tmp ) = check_login_shell( $ldap, $config );
    $result .= $tmp;

    ( $ret_code, $tmp ) = check_name_consisten( $ldap, $config );
    $result .= $tmp;

    ( $ret_code, $tmp ) = check_quota( $ldap, $config );
    $result .= $tmp;

    ldap_disconnect($ldap);

    return $result;
}

sub main {
    read_param();

    my $result = do_action();

    my $template
        = HTML::Template->new( filename => getTemplate("verify_user.tmpl") );
    $template->param( UID       => _H( $_GET{'uid'} ) );
    $template->param( UIDNUMBER => _H( $_GET{'uidnumber'} ) );
    $template->param( GIDNUMBER => _H( $_GET{'gidnumber'} ) );
    $template->param( RESULT => $result );    # omit check html entities

    print header( -charset => 'utf-8' );      # later output
    print $template->output();
}

main();
