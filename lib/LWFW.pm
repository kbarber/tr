package LWFW;
use strict;
use warnings;
use attributes;
use feature ":5.10";
use CGI;

use base qw/LWFW::Attributes LWFW::Plugins/;
__PACKAGE__->mk_ro_accessors(qw/request context/);

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

  my $self = bless {
               request => $request,
             }, $class;

  $self->_load_plugins();

  # Have different handlers per content-type?
  my $content_type = $self->request->content_type();
  if ($content_type =~ m#([^/]+)/([^/]+)#) {
    my $content_package = join('::', __PACKAGE__, ucfirst($1), ucfirst($2));
    eval("use $content_package;
          \$self->{'context'} = new $content_package(\$self)");
    if ($@) {
      warn "Don't know how to handle $content_type: $@\n";
    }
  }
  else {
      warn "Unknown content_type $content_type\n";
  }

  return $self;
}

=head2 dispatch

  Takes a path and works out whether to handle it or pass it off to another 
  module to handle.

=cut
sub dispatch {
    my $self = shift;

    my $path = shift || $self->request->url(-absolute => 1);
    
    if ((not defined $path) or ($path eq '')) {
      $path = '/';
    }
 
    my $handlers_by_path = $self->_get_handler_paths;

    if (my $handler = $handlers_by_path->{$path}) {
      my $handler_module = $handler->{'package'};
     
      my $new_module = bless $self, $handler_module;
      $new_module->_init();
      return $new_module->dispatch('/');

    }
    elsif(my $method = $self->context->method()) {
      if ($self->_is_public_method($method)) {
        return $self->$method();    
      }
      else {
        warn "Don't know how to handle $method\n"; 
      }
    }

    $self->doc();
 
    return 1;
}

=head2 doc
 
  Handles documentation

=cut
sub doc : Regex('/doc$') {
  my $self = shift;

  print "\n---------------My Supported Methods---------------\n";
  my $handlers = $self->_get_handler_paths();
  foreach my $path (keys %{$handlers}) {
    my $methods = $handlers->{$path}{'methods'};
    if ($path eq '') {
      $path = 'GLOBAL';
    }
    print "\n$path\n";
    foreach my $method (@{$methods}) {
      print "\t$method\n";
    }
  }
  print "---------------------------------------------------\n";
}

=head2 get_pod
 
  gets pod for a function

=cut


=head2 _init
 
  Override in modules for extra setup needed, ie ldap connection etc.

=cut
sub _init {
}

1;
