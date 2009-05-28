package TR::Context::HTML;
use TR::Standard;
use TR::Pod; # For get_path_to_module :(
use TR::Exceptions;

use Template;
use Data::Dumper;
use JSON::XS;

use base 'TR::Context';
__PACKAGE__->mk_accessors(qw/_params/);

=head2 new

  Creates new TR::Context::HTML object to handle html requests

=cut
sub new {
  my $proto = shift;
  my($class) = ref $proto || $proto;

  my $self = bless {
    supported => ['Text/HTML'],
  }, $class;

  return $self;
}

=head2 method 

  grab the method from an html request

=cut
sub method {
  my $self = shift;

  if(my $method = $self->request->param('method')) {
    return $method;
  }

  return;
}

=head2 set_params

  Sets a param

=cut
sub set_params {
  my ($self, %new_params) = @_;

  $self->_params(\%new_params);

  return;
}

=head2 params

  Grabs params from request

=cut
sub params {
  my $self = shift;

  if (not $self->_params) {
    my %params = $self->request->params();

    delete $params{'method'}; # remove method as it's not needed/wanted.
    $self->_params(\%params);
  }

  return $self->_params;
}

=head2 view

  Displays view

=cut
sub view {
  my $self = shift;

  print "Content-type: text/html\n\n";

  my $pod = new TR::Pod;
  my $path = $pod->get_path_to_module(ref $self);

  if (my $result = $self->result) {
    $result->{'location'} = $self->request->location();
    if (ref($result) eq 'HASH' && $result->{'error'}) {
      my $tt = Template->new(INCLUDE_PATH => $path);
      $tt->process('html_error.tmpl', $result)
        || E::Fatal->throw('Unable to load Template: ' . $tt->error());
    }
    else {
      if ($result->{'doc'}) {
        my $tt = Template->new(INCLUDE_PATH => $path);
        $tt->process('html_doc.tmpl', $result)
          || E::Fatal->throw('Unable to load Template: ' . $tt->error());
      }
      else {
        print "<html><body><pre>";
        print JSON::XS->new->utf8->pretty(1)->allow_nonref->encode($result);
        print "</pre></body></html>";
      }
    }
  }
  else {
    print "<html><head>\n";
    print "<title>TR</title>\n";
    print "</head>\n";
    print "<body>";

    print "<p>No data to display</p>";

    print "</body>";
  }

  return;
}

1;

