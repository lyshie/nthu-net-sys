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
package ourLanguage;

BEGIN { $INC{'ourLanguage.pm'} ||= __FILE__ }

use strict;
use warnings;

use Exporter;

our @ISA    = qw(Exporter);
our @EXPORT = qw(
    $G_DEFAULT_LANG
    $G_LANG
    detectLanguage
);

our $G_DEFAULT_LANG = 'zh-tw';
our $G_LANG         = $G_DEFAULT_LANG;

my %SUPPORTED_LANGS = (
    'C'     => 'zh-tw',
    'c'     => 'zh-tw',
    'E'     => 'en-us',
    'e'     => 'en-us',
    'en-us' => 'en-us',
    'en'    => 'en-us',
    'zh-tw' => 'zh-tw',
    'tw'    => 'zh-tw',
    'zh'    => 'zh-tw',
    'zh-cn' => 'zh-cn',
    'cn'    => 'zh-cn',
);

sub detectLanguage {
    my ($language) = @_;

    $language = defined($language) ? $language : 'zh-tw';

    # zh-TW,zh;q=0.8,en-US;q=0.6,en;q=0.4
    # zh-tw,en;q=0.7,en-us;q=0.3
    my $line 
        = $language
        || $ENV{'HTTP_ACCEPT_LANGUAGE'}
        || $ENV{'HTTP_USER_AGENT'}
        || '';

    if ( $line ne '' ) {
        my $regexp = join( '|', keys(%SUPPORTED_LANGS) );
        if ( $line =~ m/($regexp)/i ) {
            $G_LANG = $SUPPORTED_LANGS{ lc($1) } || $G_LANG;
        }
    }

    return $G_LANG;
}

#detectLanguage();

1;
