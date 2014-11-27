#!/bin/sh

grep '\->param' *.pl *.pm | grep -v "_H" | grep -v "\(CONFIRM\|PROFILE\|DEGREE\|LOOP\)"
