package ZimbraManager::SOAP::Friendly;

use Mojo::Base 'ZimbraManager::SOAP';

=head1 NAME

ZimbraManager::Soap::Friendly - class to manage Zimbra with perl and SOAP

=head1 SYNOPSIS

    use ZimbraManager::Soap::Friendly;

    my $ret = $self->soap->callFriendly(functionname, %params, $authtoken));

=head1 USAGE

Examples in Webbrowser:

    http://localhost:3000/auth?user=adminuser&password=MyAdminPassword

    http://localhost:3000/getAccountInfo?user=roman@zimbra.example.com&plain=yes

    http://localhost:3000/getAccountInfo?user=roman@zimbra.example.com


    http://localhost:3000/getAccount?user=roman@zimbra.example.com&plain=yes

    http://localhost:3000/getAccount?user=roman@zimbra.example.com


    http://localhost:3000/getAllAccounts?name=zimbra.example.com&domain=zimbra.example.com&plain=yes

    http://localhost:3000/getAllAccounts?name=zimbra.example.com&domain=zimbra.example.com


=head1 DESCRIPTION

Helper class for Zimbra adminstration with a user friendly interface

=cut

=head1 ATTRIBUTES

=cut

my $map = {
    auth => {
        args => [ qw(password accountName)],
        out  => sub {
            my ($password, $accountName) = @_;
            return {    persistAuthTokenCookie => 1,
                        password => $password,
                        account =>  {
                            by => 'name',
                            _ => $accountName}
                    };
        },
    },
    getAccountInfo => {
        args => [ qw(accountName)],
        out  => sub {
            my ($accountName) = @_;
            return {   account => {
                            by => 'name',
                            _  => $accountName}
                    };
        },
    },
    getAccount => {
        args => [ qw(accountName)],
        out  => sub {
            my ($accountName) = @_;
            return {   account => {
                            by => 'name',
                            _  => $accountName}
                    };
        },
    },
    getAllAccounts => {
        args => [ qw(serverName domainName)],
        out  => sub {
            my ($serverName, $domainName) = @_;
            return {    server => {
                            by => 'name',
                            _  => $serverName },
                        domain => {
                            by => 'name',
                            _  => $domainName }
                    };
        },
    },
    modifyAccount => {
        args => [ qw(zimbraUUID modifyKey modifyValue)],
        out  => sub {
            my ($zimbraUUID, $modifyKey, $modifyValue ) = @_;
            return {    id => $zimbraUUID,
                        a => {
                            n => $modifyKey,
                            _ => $modifyValue }
                        }
                    };
        },
    },
    getAllDomains => {
        args => [ ],
        out  => sub {
            return { {} };
        },
    },
    getDomainInfo => {
        args => [ qw(domainName)],
        out  => sub {
            my $domainName = shift;
            return {    domain => {
                            by => 'name',
                            _  => $domainName }
                    };
        },
    },
    createAccount => {
        args => [ qw(uid defaultEmailDomain plainPassword givenName surName country displayName localeLang cosId) ],
        out  => sub {
            my ($uid, $defaultEmailDomain, $plainPassword, $givenName, $surName, $country, $displayName, $localeLang, $cosId) = @_;
            return {
                name     => $uid . '@' . $defaultEmailDomain,
                password => $plainPassword,
                a => [
                        {
                            n => 'givenName',
                            _ => $givenName,
                        },
                        {
                            n => 'sn',
                            _ => $surName,
                        },
                        {
                            n => 'c',
                            _ => $country,
                        },
                        {
                            n => 'displayName',
                            _ => $displayName,
                        },
                        {
                            n => 'zimbraPrefLocale',
                            _ => $localeLang,
                        },
                        {
                            n => 'zimbraPasswordMustChange',
                            _ => 'FALSE',
                        },
                        {
                            n => 'zimbraCOSid',
                            _ => $config->{General}->{defaultCOS},
                        },
                ],
            };
        },
    },
    addAccountAlias => {
        args => [ qw(zimbraUUID emailAlias) ],
        out  => sub {
            my ($zimbraUUID, $emailAlias) = @_;
            return {
                id => $zimbraUUID,
                alias => $emailAlias
            };
        },
    },
    removeAccountAlias => {
        args => [ qw(zimbraUUID emailAlias) ],
        out  => sub {
            my ($zimbraUUID, $emailAlias) = @_;
            return {
                id => $zimbraUUID,
                alias => $emailAlias
            };
        },
    },
    deleteAccount => {
        args => [ qw(zimbraUUID) ],
        out  => sub {
            my ($zimbraUUID) = @_;
            return {
                id => $zimbraUUID
            };
        },
    },
};

=head1 METHODS

All the methods of L<Mojo::Base> plus:

=head2 private functions

Private functions used in the startup function

=head3 helperHashingAllAccounts

Helper function for processing AllAccounts SOAP call

=cut

my $helperHashingAllAccounts = sub {
    my $ret = shift;
    my $accounts;
    for my $za ( @{ $ret->{account} } ) {
        my $name = $za->{name};
        my $id = $za->{id};
        my %kv = map { $_->{'n'} => $_->{'_'} } @{$za->{a}};
        $accounts->{$name} = {
            'name' => $name,
            'id' => $id,
            'kv' => \%kv,
        };
    }
    return $accounts;
};

=head2 callFriendly

Calls Zimbra with the given argument and returns the SOAP response as perl hash.

=cut

sub callFriendly {    
    my $self      = shift;
    my $action    = shift;
    my $args      = shift;
    my $authToken = shift;

    $self->log->debug(dumper($action, $args, $authToken));

    # check input
    if (not exists $map->{$action}) {
        die "no valid function ($action) given";
    }
    if (ref $args ne 'HASH') {
        die 'parameter $args is not a HASH';
    }
    for $key ($map->{$action}->{args}) {
        if (not exist $args->{key}) {
            die "function $action: mandatory key/value (key: $k) not given";
        }
    }

    # build argument list
    my @orderedArgs;
    for $key ($map->{$action}->{args}) {
        push @orderedArgs, $args->{$key};
    }
    my $soapArgsBuild = $map->{$action}->{out}->(@orderedArgs);

    # build SOAP action name
    my $action .= 'Request';

    $self->log->debug(dumper($action, $soapArgsBuild, $authToken));

    return {
        $self->soap->call($action, $soapArgsBuild, $authToken)
    };
}



__END__

=head1 LICENSE

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see L<http://www.gnu.org/licenses/>.

=head1 COPYRIGHT

Copyright (c) 2014 by Roman Plessl. All rights reserved.

=head1 AUTHOR

S<Roman Plessl E<lt>roman.plessl@oetiker.chE<gt>>

=head1 HISTORY

 2014-04-29 rp Initial Version

=cut

# Emacs Configuration
#
# Local Variables:
# mode: cperl
# eval: (cperl-set-style "PerlStyle")
# mode: flyspell
# mode: flyspell-prog
# End:
#
# vi: sw=4 et
