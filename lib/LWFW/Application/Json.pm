package LWFW::Application::Json;
use strict;
use warnings;
use utf8;
use feature ":5.10";

use JSON::XS;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_ro_accessors(qw/framework coder json_request/);

=head2 new

  Creates new LWFW::Application::Json object to handle application/json

=cut
sub new {
  my $proto = shift;
  my($class) = ref $proto || $proto;

  my $framework = shift or die 'No framework object passed';
  my $coder = JSON::XS->new->utf8->pretty(1)->allow_nonref;

  my $self = bless {
               framework => $framework,
               coder     => $coder,
             }, $class;

  $self->_init();

  return $self;
}

=head2 _init

  Basic JSON RPC setup stuff.

=cut
sub _init {
  my $self  = shift;

  my $request = $self->framework->request;

  my $content;
  given ($request->request_method()) {
    when ('POST') {
      $content = $self->retrieve_json_from_post()
    }
    when ('GET') {
      $content = $self->retrieve_json_from_get()
    }
    default {
      # TODO die and exception handling
      warn ("Unable to handle request method '$_'");
    }
  }
  if ($content) {
    if (my $json_request = $self->coder->decode($content)) {
     # TODO Need to implement full validation.
      return if not $json_request->{'jsonrpc'} eq '2.0';
      $self->{'json_request'} = $json_request;
    }
  }
  else {
    # TODO die die die my darling. http://www.youtube.com/watch?v=4GIisWJJG28
  }

}

=head2 method 

  simple accessor to method called in JSON RPC.

=cut
sub method {
  my $self = shift;

  if (my $json_request = $self->json_request()) {
    if (exists($json_request->{'method'})) {
      return $json_request->{'method'};
    }
  }

  return;
}

=head2 params

  simple accessor to params called in JSON RPC.

=cut
sub params {
  my $self = shift;

  if (my $json_request = $self->json_request()) {
    if (exists($json_request->{'params'})) {
      return $json_request->{'params'};
    }
  }

  return;
}

=head2 set_params

  Work around for setting params for others.  TODO - do in a better way?

=cut
sub set_params {
  my $self   = shift;
  my %params = @_;

  $self->{'json_request'}{'params'} = \%params;

  return;
}


=head2 retrieve_json_from_post

  Grabs POST data 

=cut
sub retrieve_json_from_post {
  my $self = shift;

  my $request = $self->framework->request();
  if (my $content = $request->param('POSTDATA')) {
    return $content;
  }
  return;
}


=head2 retrieve_json_from_get

  Unimplemented

=cut
sub retrieve_json_from_get {
  my $self = shift;
  # TODO
}

=head2 view

  Displays stash

=cut
sub view {
  my $self = shift;

  print "Content-type: application/json\n\n";

  my %rpcdata;
  $rpcdata{'jsonrpc'} = '2.0';

  if (my $error = $self->framework->stash->{'error'}) {
    $rpcdata{'error'} = {
      name    => "JSONRPCError",
      code    => "1000", # TODO
      message => $error
    };
  }
  else {
    my $result = $self->framework->stash->{'result'};
    $rpcdata{'result'} = $result;  
  }
  
  if (my $id = $self->json_request->{'id'}) {
    $rpcdata{'id'} = $id;
  }

  print $self->coder->encode(\%rpcdata);
}

1;
