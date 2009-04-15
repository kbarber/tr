package TR;
use TR::Global;
use Module::Pluggable search_path => 'TR::Context',
                      sub_name    => 'context_handlers',
                      instantiate => 'new';

use Module::Pluggable search_path => 'TR::Plugins',
                      sub_name    => 'plugins',
                      instantiate => 'new';

use Module::Pluggable search_path => 'TR::C',
                      sub_name    => 'controllers',
                      instantiate => 'new';

use Config::Any;
use attributes;
use Want;

use CGI::Simple;

# Schema validation support.
use Kwalify qw(validate);
use JSON::XS qw(decode_json);

use TR::Pod;
use TR::Exceptions;
use base qw/TR::Attributes Class::Accessor::Fast/;
__PACKAGE__->mk_ro_accessors(qw/request
                                stash
                                config
                                /);

__PACKAGE__->mk_accessors(qw/debug
                             context
                             version/);

my $VERSION = '0.01';

=head2 new

  Instantiate new object.  If no CGI or Apache::Request
  object passed, will try and load CGI object.

  Example:
    PACKAGE->new();
    PACKAGE->new(request => $cgi_object);
    PACKAGE->new(request => $apache_request_object);

=cut
sub new {
  my ($proto, %args) = @_;
  my ($class) = ref $proto || $proto;

  # Either passed CGI object or Apache::Request
  my $request = $args{'request'};
  if (not defined $request) {
    $request = new CGI::Simple;
  }

  my $self = bless {
               version => $VERSION,
               stash   => {},
             }, $class;

  if ($args{'config'}) {
    $self->{'config'} = Config::Any->load_files({ files => [$args{'config'}] }) 
  }

  eval {
    $self->_init();

    foreach my $context ($self->context_handlers()) {
      next unless $context->can('handles');
      if ($context->handles(request => $request)) {
        $self->context($context);
        last;
      };
    }

    if (not $self->context()) {
      E::Invalid::ContentType->throw("Don't know how to handle: " .
                                     $request->content_type());
    }
  };
  if ($@) {
    warn "$@\n";
    $self->_error_handler($@);
  }

  return $self;
}

=head2 handler

=cut
sub handler {
  my $self = shift;

  eval {
    $self->forward($self->context->request->url(-absolute => 1));
  };
  if ($@) {
    $self->_error_handler($@);
  }

  if ($self->context) {
    $self->context->view($self->stash);
  }
}

=head2 forward

  Takes a path and works out whether to handle it or pass it off to another 
  module to handle.

=cut
sub forward {
  my ($self, $path, %args) = @_;

  my $handlers_by_path = $self->_get_handler_paths;

  if (my $handler = $handlers_by_path->{$path}) {
    if (ref($self) eq $handler->{'package'}) {
      $self->_run_method($args{'method'}, context => $self->context);
    }
    else {
      if (my $new_control = $self->_get_controller(type => $handler->{'package'})) {
        $new_control->_run_method($args{'method'}, context => $self->context);
      }
    }
  }
  else {
    $self->_run_method($args{'method'}, context => $self->context);
  }

  # If the caller is expecting something returned, return what's stored in stash,
  # (for internal calls) TODO remove, this was just to copy tr.test's way.
  # ie:
  #   my $result = $self->foward(...); # Result returned
  #   $self->forward(...); # Result left in stash
  if (want('SCALAR')) {
    return delete $self->stash->{'result'};
  }

  return;
}

=head2
  
  Returns a controller matching given type

=cut
sub _get_controller {
  my ($self, %args) = @_;

  foreach my $controller ($self->controllers({context => $self->context->request})) {
    if (ref($controller) eq $args{'type'}) {
      return $controller;
    }
  }

  return;
}

=head2 _run_method 

  Called to run a method on the current object.

  Checks that it is a public method.

=cut
sub _run_method {
  my ($self, $method, %args) = @_;

  if (not $method) {
    $method = $args{'context'}->method();
  }

  if ($method) {
    $method =~ s/\./_/;
    if ($self->_is_public_method($method)) {
      # Hook to allow a plugins to run before a method has been called.
      foreach my $plugin ($self->plugins) {
        next unless $plugin->can('pre_method');
        $plugin->pre_method(method    => $method,
                            framework => $self);
      }

      # Run the method
      $self->$method();

      # Hook to allow a plugins to run after a method has been called.
      foreach my $plugin ($self->plugins) {
        next unless $plugin->can('post_method');
        $plugin->post_method(method    => $method,
                             framework => $self);
      }

      return;
    }
    else {
      E::Invalid::Method->throw(error    => $method,
                                err_code => '-32601' );
    }
  }

  E::Invalid::Method->throw(error    => 'No method given',
                            err_code => '-32601' );
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
        my $pod = new TR::Pod;

        if (my $doc = $pod->get_documentation(package => ref($self),
                                              method  => $params->{'show'})) {
          $self->stash->{'result'}->{'doc'}->{'method'} = $params->{'show'};
          $self->stash->{'result'}->{'doc'}->{'poddoc'} = $doc;
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

        my $pod = new TR::Pod;
        if (my $schema = $pod->get_schema(package => ref($self),
                                          method  => $params->{'show'})) {
          $self->stash->{'result'}->{'doc'}->{'schema'} = $schema;
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
    $self->log(level   => 'error',
               message => $exception->time .
                          ' :DEBUG INFO: ' .
                          $exception->trace->as_string);

    my %error;
    $error{'message'} = $exception->description() .
                        ': ' .
                        $exception->error;

    $error{'err_code'} = $exception->err_code();
    $self->stash->{'error'} =\%error;
  }
  else {
    $self->stash->{'error'}->{'message'} = "Unknown error: $exception";
    $self->log(level   => 'error',
               message => "Unknown error: $exception");
  }
}

=head2 log

  Handles logging

=cut
sub log {
  my ($self, %args) = @_;
}

=head2 _init

  Override in modules.

=cut
sub _init {
  my $self = shift;
  $self->maybe::next::method(@_);
}

1;
