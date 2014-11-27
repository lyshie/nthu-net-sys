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
use URI::Escape;

my $sid  = param('sid')  || '';
my $mode = param('mode') || '';

sub safe_check {
    my $addr = $ENV{'REMOTE_ADDR'} || '';

    if ( ( $addr eq '' )
        || $addr !~ m/^(?:140\.114\.64\.|127\.0\.0\.)/ )
    {
        print "FAIL: remote address not allow\n";
        exit(1);
    }
}

print header();

safe_check();

if ( $mode eq 'env' ) {
    print q{<pre>};
    foreach ( sort keys(%ENV) ) {
        print "$_ = $ENV{$_}\n";
    }
    print q{</pre>};
}
else {
    opendir( DH, $Bin );

    my @cgis = grep { "$Bin/$_" =~ m/\.(?:cgi|php)$/ } readdir(DH);

    closedir(DH);

    print q{<ul>};
    foreach ( sort @cgis ) {
        my $url = "http://r309-2.cc.nthu.edu.tw/portal/$_?sid=$sid";
        $url = uri_escape($url);
        print <<EOF
<li>
<a href="http://r309-2.cc.nthu.edu.tw/w3c-validator/check?uri=$url" target="_blank">[W3C]</a>&nbsp;&nbsp;
<a href="$_?sid=$sid" target="_blank">$_</a>
</li>
EOF
            ;
    }
    print q{</ul>};
}
