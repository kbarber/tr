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
    my $path = shift;
    
    if ((not defined $path) or ($path eq '')) {
      $path = '/';
    }
 
    if ($path =~ s#(/[^/]+)##) {
      # work out the module to pass request onto.
      my $new_module = lc($1);
      $new_module =~ s#/#::#;
      $new_module = ref($self) . $new_module;
      
      my $new_handler;
      eval("\$new_handler = new $new_module(\$self->request())");
      if ($@) {
        warn "Unable to handle request $@\n";
      }
      if ($new_handler) {
        return $new_handler->dispatch($path);
      }
    }
    elsif(my $method = $self->context->method()) {
      if ($self->_is_public_method($method)) {
        return $self->$method();    
      }
      else {
        warn "Don't know how to handle $method\n"; 
      }
    }
    else {
      warn "Docs.....\n";
      $self->doc();
    }
 
    return 1;
}

=head2 doc
 
  Handles documentation

=cut
sub doc : Regex('/doc$') {
  print "\n---------------MY LIST OF FUNCTIONS---------------\n";
  LWFW::Attributes->_get_handler_list();
  print "--------------------------------------------------\n";
}

=head2 get_pod
 
  gets pod for a function

=cut
1;
