package TR::C::System;
use TR::Standard;
use TR::Pod;

use vars qw($VERSION);
use version; $VERSION = qv('1.3');

=head1 NAME

    TR::C::System

=head1 VERSION

    See $VERSION

=head1 SYNOPSIS

    package TR::C::example;
    use TR::Standard;

    use base 'TR::C::System';

    sub _init {
        # Setup...
    }

    sub helloworld :Local {
        my $self = shift;
        my $params = $self->context->params;
        $self->context->result('Hello world');
    }

=head1 DESCRIPTION 

    Base TR:C module provides documentation/schema functions,
    logging and config.

    All other Control modules should use this as base.

=head1 CONFIGURATION AND ENVIRONMENT

    See <TR>

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 AUTHOR

=head1 DIAGNOSTICS

=head1 BUGS AND LIMITATIONS

    Probably a few.

=head1 SUBROUTINES/METHODS

=cut

use base 'TR::Attributes';
__PACKAGE__->mk_ro_accessors(qw/context config version log/);

sub new {
    my ( $proto, %args ) = @_;
    my ($class) = ref $proto || $proto;

    my $self = bless \%args, $class;
    $self->{'version'} = $VERSION->normal;
    $self->{'log'}     = Log::Log4perl->get_logger();
    $self->_init();

    return $self;
}

sub _init {
}

=head2 system_schema

  Request:
    time curl -H 'Content-Type: application/json' -u test:test -X POST -d '
    {
      "jsonrpc":"2.0",
      "method":"system.schema",
      "params":{
        "show":"doc"
      }
    }
    ' 'http://<server>:<port>/t/'

  Response:
    {
      "jsonrpc":"2.0",
      "result": {"schema": " ...Kwalify schema... "} 
    }

=cut

sub system_schema : Global {

=begin schema
  {
    "type": "map",
    "required": true,
    "mapping": {
      "show":   { "type": "str", "required": true }
    }
  }
=cut

    my $self = shift;

    $self->context->result( doc => { version => $self->version } );

    if ( $self->context ) {
        if ( my $params = $self->context->params() ) {
            if ( $self->_is_public_method( $params->{'show'} ) ) {
                $self->context->result( doc => { method => $params->{'show'} } );

                my $pod = new TR::Pod;
                if (my $schema = $pod->get_schema(
                        'package' => ref($self),
                        'method'  => $params->{'show'}
                    )) {
                    $self->context->result( doc => { schema => $schema } );
                }
                else {
                    $self->context->result(
                        doc => { schema => 'No schema.' } );
                }
                return;
            }
        }
    }

    return;
}

=head2 system_version

  Request:
    time curl -H 'Content-Type: application/json' -u test:test -X POST -d '
    {
      "jsonrpc":"2.0",
      "method":"system.version",
    }
    ' 'http://<server>:<port>/t/ldap/user'

  Response:
    {
      "jsonrpc":"2.0",
      "result": {"version":"x.x"} 
    }

=cut

sub system_version : Global {
    my $self = shift;

    $self->context->result( { version => $self->version } );

    return;
}

=head2 system_doc

  Request:
    time curl -H 'Content-Type: application/json' -u test:test -X POST -d '
    {
      "jsonrpc":"2.0",
      "method":"system.doc",
      "params":{
        "show":"getDnByUid"
      }
    }
    ' 'http://<server>:<port>/t/ldap/user'

  Response:
    {
      "jsonrpc":"2.0",
      "result": {"doc":" ...documentation... "} 
    }

=cut

sub system_doc : Global {

=begin schema
  {
    "type": "map",
    "required": false,
    "mapping": {
      "show":   { "type": "str", "required": false }
    }
  }
=cut

    my $self = shift;

    $self->context->result( { doc => { version => $self->version } } );

    # See if documentation for a specific method was wanted
    if ( $self->context ) {
        if ( my $params = $self->context->params() ) {
            if ( $self->_is_public_method( $params->{'show'} ) ) {
                my $pod = new TR::Pod;

                if (my $doc = $pod->get_documentation(
                        'package' => ref($self),
                        'method'  => $params->{'show'}
                    )) {

                    # Variable subtitution.
                    my $server   = $self->context->request->server_name();
                    my $port     = $self->context->request->server_port();
                    my $protocol = $self->context->request->protocol();

                    $doc =~ s/<server>/$server/ximg;
                    $doc =~ s/<port>/$port/ximg;
                    $doc =~ s/<protocol>/$protocol/ximg;

                    $self->context->result( { doc => { method => $params->{'show'} } } );
                    $self->context->result( { doc => { poddoc => $doc } } );
                    return;
                }
            }
        }
    }

    # Else display list of available methods
    my %result;
    my $handlers = $self->_get_handler_paths();
    foreach my $path ( keys %{$handlers} ) {
        my $methods = $handlers->{$path}{'methods'};
        my $package = $handlers->{$path}{'package'};
        if ( not $path ) {
            $path = 'GLOBAL';
        }
        $result{$path} = $methods;
    }
    $self->context->result( { doc => { paths => \%result } } );

    return;
}

=head1 LICENSE AND COPYRIGHT

  Copyright (C) 2009 Alfresco Software Ltd <http://www.alfresco.com>

  This file is part of TR.
    
  TR is free software: you can redistribute it and/or modify
  it under the terms of the GNU Affero General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
    
  TR is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU Affero General Public License
  along with TR.  If not, see <http://www.gnu.org/licenses/>.

=cut

1;
