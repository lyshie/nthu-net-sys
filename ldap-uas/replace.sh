#!/bin/bash
     for fl in *.pl; do
     mv $fl $fl.old
     sed 's/\/usr\/bin\/perl/\/usr\/local\/bin\/perl/g' $fl.old > $fl
     rm -f $fl.old
     done

chmod 755 *.pl
chmod 644 *.pm
chown -R webservd:webservd bugs/
