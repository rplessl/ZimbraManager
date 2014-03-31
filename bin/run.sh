#!/bin/sh

export PERL_LWP_SSL_VERIFY_HOSTNAME=0
export PERL_LWP_SSL_VERIFY_MODE='SSL_VERIFY_NONE'

#`dirname $0`/zimbra-manager.pl prefork --listen='http://*:13000'

`dirname $0`/zimbra-manager.pl daemon --listen='http://*:13000'
