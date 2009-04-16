package TR::Context::HTML;
use TR::Global;

use Template;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_accessors(qw/request/);

=head2 new

  Creates new TR::Context::HTML object to handle html requests

=cut
sub new {
  my $proto = shift;
  my($class) = ref $proto || $proto;

  my $self = bless {}, $class;

  return $self;
}

=head2 handles

 Called by TR to see if this module handles the current contact type.

=cut
sub handles {
  my ($self, %args) = @_;

  my @SUPPORTED_TYPES = ('Text/HTML');

  my $request      = $args{'request'};
  my $content_type = $request->content_type();

  foreach my $type (@SUPPORTED_TYPES) {
    if ( lc($content_type) eq lc($type)) {
      $self->request($request);
      return $self;
    }
  }

  return;
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

=head2 params

  Grabs params from request

=cut
sub params {
  my $self = shift;

  if (my $params = $self->request->Vars()) {
    my %data = %{$params};  # make a copy.
    delete $data{'method'}; # Remove method
    return \%data;
  }

  return;
}

=head2 view

  Displays view

=cut
sub view {
  my $self = shift;

  print "Content-type: text/html\n\n";

  if (my $result = $self->result) {
    my $path = $self->framework->_get_path_to_module(ref $self);
    if ($result->{'doc'}) {
      my $tt = Template->new(INCLUDE_PATH => $path);
      $tt->process('html_doc.tmpl', $result)
        || warn $tt->error();
    }
    else {
      print Dumper $result;
    }
  }
  elsif (my $error = $self->framework->stash->{'error'}) {
    my $path = $self->framework->_get_path_to_module(ref $self);
    my $tt = Template->new(INCLUDE_PATH => $path);
    $tt->process('html_error.tmpl', $error)
      || warn $tt->error();
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

