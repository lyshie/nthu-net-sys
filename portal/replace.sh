#!/bin/bash
     for fl in *.cgi; do
     mv $fl $fl.old
     sed 's/\/usr\/bin\/perl/\/usr\/local\/bin\/perl/g' $fl.old > $fl
     rm -f $fl.old
     done

chmod 755 *.cgi
chmod 644 *.pm
chown -R webservd:webservd tmp/ magic/ bugs/ keys/
