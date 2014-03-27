#!/bin/sh

#`dirname $0`/zimbra-manager.pl prefork --listen='http://*:13000'
`dirname $0`/zimbra-manager.pl daemon --listen='http://*:13000'
