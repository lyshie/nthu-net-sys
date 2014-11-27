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
use lib "$Bin";
use lib_crypt;

my %_GET = ();

sub _default {
    my ( $var, $def ) = @_;
    return defined($var) ? $var : $def;
}

sub get_param {
    $_GET{'name'}      = _default( param('name'),      '' );
    $_GET{'name_en'}   = _default( param('name_en'),   '' );
    $_GET{'id'}        = _default( param('id'),        '' );
    $_GET{'language'}  = _default( param('language'),  'C' );
    $_GET{'target'}    = _default( param('target'),    'ua.net.nthu.edu.tw' );
    $_GET{'charset'}   = _default( param('charset'),   'utf-8' );
    $_GET{'condition'} = _default( param('condition'), '' );
}

sub main {

    get_param();

    my $name      = $_GET{'name'};
    my $name_en   = $_GET{'name_en'};
    my $id        = $_GET{'id'};
    my $language  = $_GET{'language'};
    my $charset   = $_GET{'charset'};
    my $condition = $_GET{'condition'};
    my $ip        = $ENV{'REMOTE_ADDR'} || '';
    my $timestamp = time();

    my $data = <<EOF
charset = $charset
name = $name
name_en = $name_en
id = $id
ip = $ip
timestamp = $timestamp
language = $language
condition = $condition
EOF
        ;

    my $enc_data = lib_crypt::encrypt($data);

    print header( -charset => $charset );
    print <<EOF
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="zh-tw"
 lang="zh-tw" dir="ltr">
<head>
	<title></title>
</head>
<body>
<pre>
$data
<a href="https://$_GET{'target'}/portal/index.cgi?debug=1&amp;data=$enc_data" target="_blank">Login as this user...</a>
</pre>
</body>
</html>
EOF
        ;
}

main();
