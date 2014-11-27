#!/bin/sh

grep '\->param' *.cgi *.pm | grep template | grep -v "_H" | grep -v "\(CONFIRM\|PROFILE\|DEGREE\|LOOP\)"
