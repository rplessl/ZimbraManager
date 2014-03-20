ZimbraManager
=============
Zimbra commandline administration with Perl and SOAP. 

This tool runs much faster than calling 'zmprov' from the command line.

Use Case
--------
If you like to manage user accounts in scripts you can call the 'zmprov'
command of Zimbra. Unfortunatly always a java environment will be started
which takes multiple seconds for a hugh amount (>10'000) of accounts.

This ZimbraManager is a Mojo Web Service which keeps a session for user
management open and allows to set run SOAP requests based on user REST
requests as input.

Installation
------------
Build infrastructure to run the framework

    $ cd /opt
    $ git clone https://github.com/rplessl/ZimbraManager
    $ cd ZimbraManager
    $ ./setup/build-perl-modules.sh

Fetch WSDLs and XML Schemas

    $ ./bin/get-wsdl.sh zimbra.example.com

Usage
----- 

    $ ./bin/zimbra-manager.pl prefork

or 

    $ ./bin/zimbra-manager.pl daemon



LICENSE
--------
LGPL license (see LICENSE)

Contact info
------------
Roman Plessl <roman.plessl@oetiker.ch> 

http://www.oetiker.ch/home/unternehmen/team/rp/
