package TR::Context::HTML;
use TR::Standard;
use TR::Pod; # For get_path_to_module :(

use Template;
use Data::Dumper;
use base 'TR::Context';

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

=head2 params

  Grabs params from request

=cut
sub params {
  my $self = shift;

  if (my %params = $self->request->Vars()) {
    delete $params{'method'};
    return \%params;
  }

  return;
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
    if (ref($result) eq 'HASH' && $result->{'error'}) {
      my $tt = Template->new(INCLUDE_PATH => $path);
      $tt->process('html_error.tmpl', $result)
        || warn $tt->error();
    }
    else {
      if ($result->{'doc'}) {
        my $tt = Template->new(INCLUDE_PATH => $path);
        $tt->process('html_doc.tmpl', $result)
          || warn $tt->error();
      }
      else {
        print Dumper $result;
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

