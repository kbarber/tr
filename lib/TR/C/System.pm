package TR::C::System;
use TR::Standard;
use base 'TR::Attributes';
__PACKAGE__->mk_ro_accessors(qw/context config version/);

my $VERSION = '0.04';

sub new {
  my ($proto, %args) = @_;
  my ($class) = ref $proto || $proto;

  my $self = bless \%args, $class;
  $self->{'version'} = $VERSION;
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
    ' 'http://tr.test.alfresco.com/t/'

  Response:
    {
      "jsonrpc":"2.0",
      "result": {"schema": " ...Kwalify schema... "} 
    }

=cut
sub system_schema :Global {
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

  $self->context->result(doc => {version => $self->version});

  if ($self->context) {
    if (my $params = $self->context->params()) {
      if ($self->_is_public_method($params->{'show'})) {
        $self->context->result(doc => {method => $params->{'show'}});

        my $pod = new TR::Pod;
        if (my $schema = $pod->get_schema('package' => ref($self),
                                          method    => $params->{'show'})) {
          $self->context->result(doc => {schema => $schema});
        }
        else {
          $self->context->result(doc => {schema => 'No schema.'});
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
    ' 'http://tr.test.alfresco.com/t/ldap/user'

  Response:
    {
      "jsonrpc":"2.0",
      "result": {"version":"x.x"} 
    }

=cut
sub system_version :Global {
  my $self = shift;

  $self->context->result({version => $self->version});

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
    ' 'http://tr.test.alfresco.com/t/ldap/user'

  Response:
    {
      "jsonrpc":"2.0",
      "result": {"doc":" ...documentation... "} 
    }

=cut
sub system_doc :Global {
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

  $self->context->result({doc => {version => $self->version}});

  # See if documentation for a specific method was wanted
  if ($self->context) {
    if (my $params = $self->context->params()) {
      if ($self->_is_public_method($params->{'show'})) {
        my $pod = new TR::Pod;

        if (my $doc = $pod->get_documentation('package' => ref($self),
                                              method    => $params->{'show'})) {
          $self->context->result({doc => {method => $params->{'show'}}});
          $self->context->result({doc => {poddoc => $doc}});
          return;
        }
      }
    }
  }

  # Else display list of available methods
  my %result;
  my $handlers = $self->_get_handler_paths();
  foreach my $path (keys %{$handlers}) {
    my $methods = $handlers->{$path}{'methods'};
    my $package = $handlers->{$path}{'package'};
    if ($path eq '') {
      $path = 'GLOBAL';
    }
    $result{$path} = $methods;
  }
  $self->context->result({doc => {paths => \%result}});
}

1;
