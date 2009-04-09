package LWFW::Text::Html;
use strict;
use warnings;
use Template;
use Data::Dumper;

use base 'Class::Accessor::Fast';
__PACKAGE__->mk_ro_accessors(qw/framework request/);

=head2 new

  Creates new LWFW::Text::Html object to handle html requests

=cut
sub new {
  my $proto = shift;
  my($class) = ref $proto || $proto;

  my $framework = shift or die 'No framework object passed';

  my $self = bless {
               framework => $framework,
               request   => $framework->request(),
             }, $class;

  return $self;
}

=head2 method 

  grab the method from an html request
      $data{$param} = $self->request->param($params);

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

  if (my $result = $self->framework->stash->{'result'}) {
    if ($result->{'doc'}) {
      # Play with the doc or schema text so that it displays nicely.
      if($result->{'doc'}->{'schema'}) {
        $result->{'doc'}->{'schema'} =~ s/ /&nbsp;/g;
        $result->{'doc'}->{'schema'} =~ s/\t/&nbsp;&nbsp;&nbsp;&nbsp;/g;
      }
      if($result->{'doc'}->{'poddoc'}) {
        $result->{'doc'}->{'poddoc'} =~ s/ /&nbsp;/g;
        $result->{'doc'}->{'poddoc'} =~ s/\t/&nbsp;&nbsp;&nbsp;&nbsp;/g;
      }

      my $tt = Template->new(ABSOLUTE => 1);
      $tt->process('/home/knoxc/Projects/TR.perl/engine/lib/LWFW/Text/doc.tmpl', $result)
        || warn $tt->error();
    }
    else {
      print Dumper $result;
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

