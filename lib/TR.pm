package TR;
use TR::Global;
use Module::Pluggable search_path => 'TR::Context',
                      sub_name    => 'context_handlers',
                      instantiate => 'new';

use Module::Pluggable search_path => 'TR::Plugins',
                      sub_name    => 'plugins',
                      instantiate => 'new';

use attributes;
use Want;

use CGI();

# Schema validation support.
use Kwalify qw(validate);
use JSON::XS qw(decode_json);

use TR::Pod;
use TR::Exceptions;
use base qw/TR::Attributes TR::Plugins/;
__PACKAGE__->mk_ro_accessors(qw/request
                                stash
                                pod
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

  my $pod = new TR::Pod;

  my $self = bless {
               version => $VERSION,
               stash   => {},
               request => $request,
               pod     => $pod,
             }, $class;

  eval {
    $self->_load_plugins(); # TODO Deprecate
    $self->_init();

    my ($content_type) = $self->request->content_type() || 'text/html';
    foreach my $context ($self->context_handlers()) {
      next unless $context->can('handles');
      last if $context->handles(content_type => $content_type,
                                framework    => $self);
    }

    if (not $self->context()) {
      E::Invalid::ContentType->throw("Don't know how to handle: " .
                                     $content_type);
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

  # If the caller is expecting something returned, return what's stored in stash,
  # (for internal calls)
  # ie:
  #   my $result = $self->foward(...); # Result returned
  #   $self->forward(...); # Result left in stash
  if (want('SCALAR')) {
    return delete $self->stash->{'result'};
  }

  return;
}

=head2 _run_method 

  Called to run a method on the current object.

  Checks that it is a public method.

=cut
sub _run_method {
  my $self   = shift;
  my $method = shift || $self->context->method();

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
