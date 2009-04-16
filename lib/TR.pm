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

use attributes;
use Want;

use CGI::Simple;

use TR::Pod;
use TR::Config;
use TR::Exceptions;
use base 'TR::Attributes';
__PACKAGE__->mk_ro_accessors(qw/request
                                config/);

__PACKAGE__->mk_accessors(qw/debug
                             context
                             version/);

my $VERSION = '0.02';

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
             }, $class;

  if ($args{'config'}) {
    if (-f $args{'config'}) {
      $self->{'config'} = new TR::Config($args{'config'});
    }
    else {
      die "Couldn't find config file: $args{'config'}";
    }
  }

  eval {
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
    $self->context->view();
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
    $self->_run_method($args{'method'},
                       'package' => $handler->{'package'},
                       context   => $self->context);
  }
  else {
    $self->_run_method($args{'method'}, context => $self->context);
  }

  return;
}

=head2
  
  Returns a controller matching given type

=cut
sub _get_controller {
  my ($self, %args) = @_;

  return if not $args{'type'};

  my @controllers = $self->controllers(context => $self->context,
                                       config  => $self->config);

  foreach my $controller (@controllers) {
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

    my $control; 
    
    if (not $control = $self->_get_controller(type => $args{'package'})) {
      $control = $self; # For now
    }

    if ($control->_is_public_method($method)) {
      # Hook to allow a plugins to run before a method has been called.
      foreach my $plugin ($self->plugins) {
        next unless $plugin->can('pre_method_hook');
        $plugin->pre_method_hook(control => $control,
                                 method  => $method);
      }

      # Run the method
      $control->$method();

      # Hook to allow a plugins to run after a method has been called.
      foreach my $plugin ($self->plugins) {
        next unless $plugin->can('post_method_hook');
        $plugin->post_method_hook(control => $control,
                                  method  => $method);
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
    $self->context->result({error => \%error});
  }
  else {
    $self->context->result({error => "Unknown error: $exception"});
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

1;
