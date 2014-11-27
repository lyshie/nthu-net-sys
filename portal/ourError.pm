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
package ourError;

BEGIN { $INC{'ourError.pm'} ||= __FILE__ }

use strict;
use warnings;

use CGI qw(:standard);
use Exporter;
use FindBin qw($Bin);
use HTML::Template::Pro;
use lib "$Bin";
use ourTemplate;
use ourLanguage;

our @ISA    = qw(Exporter);
our @EXPORT = qw(
    show_error
    show_user_error
    show_session_error
);

#
my %_GET_ = ();

sub _read_param {
    $_GET_{'sid'} = param('sid') || '';
    $_GET_{'sid'} =~ s/[^0-9a-f]//g;
}
_read_param();

#
my %SESSION_ERRORS = (
    '0'  => "不存在的連線 (Session empty)",
    '-1' => "連線逾期 (Session expired)",
    '-2' => "IP 連線位址不同 (IP mismatch)",
    '-4' => "無效的參考來源 (Invalid referer)",
);

my %USER_ERRORS = (
    '-1' => "使用者已經存在 (User already exist)",
    '-2' => "使用者不存在 (User not exist)",
    '-3' => "使用者已經被停用 (User already suspended)",
    '-4' => "使用者不被允許 (User not permitted)",
    '-5' =>
        "使用者密碼已經被停用 (User password already suspended)",
);

sub show_error {
    my ( $error_id, $error_msg, $redir_uri, $redir_msg ) = @_;

    my $redir
        = defined($redir_uri) ? $redir_uri : 'javascript:history.go(-1);';
    my $msg = defined($redir_msg) ? $redir_msg : "返回上一頁 (Go back)";

    my $is_redir = 0;
    $is_redir = 1 if ( $redir !~ m/javascript/ );

    my $template = HTML::Template::Pro->new(
        case_sensitive => 1,
        filename       => "$Bin/template/$G_LANG/error.tmpl"
    );

    $template->param( SID       => $_GET_{'sid'} );
    $template->param( ERROR_ID  => $error_id );
    $template->param( ERROR_MSG => $error_msg );
    $template->param( REDIR     => $is_redir );
    $template->param( REDIR_URI => $redir );
    $template->param( REDIR_MSG => $msg );
    return $template->output();
}

sub show_user_error {
    my ($error_id) = @_;

    return show_error( "USER($error_id)", $USER_ERRORS{$error_id} || '' );
}

sub show_session_error {
    my ($error_id) = @_;

    return show_error( "SESSION($error_id)", $SESSION_ERRORS{$error_id} || '',
        "empty.cgi", "回首頁 (Go Home)" );
}

1;
