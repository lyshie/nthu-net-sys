#!/bin/sh

curr_dir=`pwd`
dir=`dirname $0`
ABS_PATH=`cd $dir; pwd`
#ABS_PATH=$(dirname `readlink -f $0`)

for PROFILE in mx cc oz my m99 m100 m101 m102 m103
do
    echo "==== $PROFILE ========================"

    echo "1. Duplicated uidNumber check"
    "$ABS_PATH/xldap_duplicate_uidnumber.pl" $PROFILE

    echo "2. Last 24 hours created accounts"
    "$ABS_PATH/xldap_last_created.pl" $PROFILE 24 | sed 's/\[sn=.*$//'

    LAST_ACCOUNTS=`"$ABS_PATH/xldap_last_created.pl" $PROFILE 24 | grep sn= | cut -d' ' -f1 | xargs`

    if [ -z "$LAST_ACCOUNTS" ]; then
        continue;
    fi

    echo "3. Quota check for last 24 hours created accounts"
    "$ABS_PATH/xldap_quota_check.pl" $PROFILE "$LAST_ACCOUNTS"
    echo

    echo "4. Home Directory check for last 24 hours created accounts"
    "$ABS_PATH/xldap_homedir_check.pl" $PROFILE "$LAST_ACCOUNTS"
    echo
done
