package LWFW;
use LWFW::Global;

use attributes;
use Want;

use CGI();

# Schema validation support.
use Kwalify qw(validate);
use JSON::XS qw(decode_json);

use LWFW::Pod;
use LWFW::Exceptions;
use base qw/LWFW::Attributes LWFW::Plugins/;
__PACKAGE__->mk_ro_accessors(qw/request context stash version pod/);
__PACKAGE__->mk_accessors(qw/debug/);

my $VERSION = '0.01';

use Data::Dumper;

=head2 new

  Instantiate new object.  If no CGI or Apache::Request
  object passed, will try and load CGI object.

  Example:
    PACKAGE->new();
    PACKAGE->new($cgi_object);
    PACKAGE->new($apache_request_object);

=cut
sub new {
  my $proto = shift;
  my($class) = ref $proto || $proto;

  # Either passed CGI object or Apache::Request
  my $request = shift;
  if (not defined $request) {
    $request = new CGI();
  }

  my $pod = new LWFW::Pod;

  my $self = bless {
               version => $VERSION,
               stash   => {},
               request => $request,
               pod     => $pod,
             }, $class;

  eval {
    $self->_load_plugins();
    $self->_init();

    # Have different handlers per content-type?
    my ($content_type) = $self->request->content_type() || 'text/html';
    if ($content_type =~ m#([^/]+)/([^/]+)#) {
      my $content_package = join('::', __PACKAGE__, ucfirst($1), ucfirst($2));
      eval("use $content_package;
            \$self->{'context'} = new $content_package(\$self)");
      if ($@) {
        E::Invalid::ContentType->throw($@);
      }
    }
    else {
      E::Invalid::ContentType->throw("Don't know how to handle: " .
                                     $content_type);
    }
  };
  if ($@) {
    $self->_error_handler($@);
  }

  return $self;
}

=head2 handler

=cut
sub handler {
  my $self = shift;

  eval {
    $self->forward($self->request->url(-absolute => 1));
  };
  if ($@) {
    $self->_error_handler($@);
  }

  if ($self->context) {
    $self->context->view();
  }
}

=head2 forward

  Takes a path and works out whether to handle it or pass it off to another 
  module to handle.

  Has some ugly reblessing hackery at the moment, going to restructure code
  later :(

=cut
sub forward {
  my ($self, $path, %args) = @_;

  my $handlers_by_path = $self->_get_handler_paths;

  if (my $handler = $handlers_by_path->{$path}) {
    my $handler_module = $handler->{'package'};

    my ($handler, $orig_class);
    if (ref($self) eq $handler_module) {
      $handler = $self;
    }
    else {
      # Don't need to do this if internally forwarding with a module
      $orig_class = ref($self);
      $handler = bless $self, $handler_module;
      $handler->_init();
    }
    $handler->_run_method($args{'method'});
    if ($orig_class) {
      bless $self, $orig_class;
    }

  }
  else {
    $self->_run_method($args{'method'});
  }

  if (want('SCALAR')) {
    return delete $self->stash->{'result'};
  }

  return;
}

=head2 _run_method 

  Called to run a method on the current object.

  Checks that it is a public method.

  Maybe ACL/Audit hooks later.

=cut
sub _run_method {
  my $self   = shift;
  my $method = shift || $self->context->method();

  if ($method) {
    $method =~ s/\./_/;
    if ($self->_is_public_method($method)) {
      if (my $schema = $self->pod->get_schema(package => ref($self),
                                              method  => $method)) {
        $self->validate_params(schema => $schema);
      }
      return $self->$method($self->context());
    }
    else {
      E::Invalid::Method->throw($method);
    }
  }

  E::Invalid::Method->throw('No method given');
}

=head2 validate_params
 
  Valids params with given schema.

=cut
sub validate_params {
  my ($self, %args) = @_;

  if ($args{'schema'}) {
    my $schema = decode_json($args{'schema'});
    my $params = $self->context->params();
    eval {
      validate($schema, $params);
    };
    if ($@) {
      E::Invalid::Params->throw($@);
    }
  }
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

  $self->stash->{'result'} = {version => $self->version};

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

  $self->stash->{'result'}->{'doc'}->{'version'} = $self->version;

  # See if documentation for a specific method was wanted
  if ($self->context) {
    if (my $params = $self->context->params()) {
      if ($self->_is_public_method($params->{'show'})) {
        if (my $pod = $self->pod->get_documentation(package => ref($self),
                                                    method  => $params->{'show'})) {
          $self->stash->{'result'}->{'doc'}->{'method'} = $params->{'show'};
          $self->stash->{'result'}->{'doc'}->{'poddoc'} = $pod;
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
  $self->stash->{'result'}->{'doc'}->{'paths'} = \%result;
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

  $self->stash->{'result'}->{'doc'}->{'version'} = $self->version;

  if ($self->context) {
    if (my $params = $self->context->params()) {
      if ($self->_is_public_method($params->{'show'})) {
        $self->stash->{'result'}->{'doc'}->{'method'} = $params->{'show'};
        if (my $pod = $self->pod->get_schema(package => ref($self),
                                             method  => $params->{'show'})) {
          $self->stash->{'result'}->{'doc'}->{'schema'} = $pod;
        }
        else {
          $self->stash->{'result'}->{'doc'}->{'schema'} = 'No schema.';
        }
        return;
      }
    }
  }

  return;
}

=head2 _error_handler

  Handle errors in module.

=cut
sub _error_handler {
  my ($self, $exception) = @_;

  if (ref($exception)) {
    $self->stash->{'error'} = $exception->description() . ': ' .
                                     $exception->error;

    if ($self->debug()) {
      warn $exception->time . ' :DEBUG INFO: ' . $exception->trace->as_string;
                                 
    }
  }
  else {
    $self->stash->{'error'} = "Unknown error: $exception";
  }
}

=head2 _init

  Override in modules.

=cut
sub _init {
  my $self = shift;
  $self->maybe::next::method(@_);
}

1;
