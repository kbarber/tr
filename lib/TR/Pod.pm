package TR::Pod;
use TR::Global;

use PPI();
# use PPI::Cache path => '/var/cache/ppi-cache';
use Cwd qw/realpath/;

use base 'Class::Accessor::Fast';
__PACKAGE__->mk_ro_accessors(qw/cached/);

our $SINGLETON;

=head2 new

  Init pod module

=cut
sub new {
  my $proto = shift;
  my($class) = ref $proto || $proto;

  return $SINGLETON if defined $SINGLETON;

  $SINGLETON = bless {
               cached => {},
             }, $class;


  return $SINGLETON;
}

=head2 _fetch 

  Returns PPI::Document object for a module if it's already been loaded, 
  else loads up a PPI::Document object for the module.

=cut
sub _fetch {
  my ($self, %args) = @_;

  my $module = $args{'module_file'} or die 'Need to pass module_file';

  return $self->cached->{$module} if $self->cached->{$module};

  my $document = PPI::Document->new($module) or die $!;

  $self->cached->{$module} = $document;

  return $document;
}

=head2 get_documentation
 
  Grabs pod documentation for a given package/method.
  Need to standardise on format so that it can be passed back
  to a caller,
  and that caller be able to present it any way it wants.

  ie maybe pod like this:

  head2 asub

    Description:
      blah

    Example:
      blah

  cut

  Could be returned as:

  {
    method      => asub,
    params      => [a, b, c,],  # (From params attribute)
    description => 'blah',
    example     => 'blah',
  }

=cut
sub get_documentation {
  my ($self, %args) = @_;

  return unless $args{'package'};
  return unless $args{'method'};

  my $module_dir = $self->get_path_to_module($args{'package'});

  if ($args{'package'} =~ /([^:]+)$/) {
    my $document = $self->_fetch(module_file => $module_dir . $1 . '.pm');

    if (my $results = $document->find(sub {
                                   $_[1]->isa('PPI::Token::Pod')
                                   and ($_[1]->content =~ /=head2 $args{'method'}/) 
                                 })) {
      my $content = @$results[0]->content();
      $content =~ s/=head2 $args{'method'}//m;
      $content =~ s/=cut//m;
      return $content;
    }
  }

  return;
}

=head2 get_schema
 
  Grab the schema for a method, lots of overlap with get_pod.
  TODO: cleanup.

=cut
sub get_schema {
  my ($self, %args) = @_;

  return unless $args{'package'};
  return unless $args{'method'};

  my $module_dir = $self->get_path_to_module($args{'package'});

  if ($args{'package'} =~ /([^:]+)$/) {
    my $document = $self->_fetch(module_file => $module_dir . $1 . '.pm');

    if (my $results = $document->find(sub {
                               $_[1]->isa('PPI::Statement::Sub')
                               and ($_[1]->content =~ /sub $args{'method'}/) 
                             })) {
      my $method = @$results[0];
      if (my $children = $method->find(sub {
                                  $_[1]->isa('PPI::Token::Pod')
                                  and ($_[1]->content =~ /=begin schema/) 
                                  })) {
        my ($schema) = @$children[0]->content() =~ /=begin schema(.+)=cut/ms;
        return $schema;
      }
    }
  }

  return;
}

=head2 get_path_to_module

  Grab the path to a module and return it's realpath (.. ie get rid 
                                                      of /../../ etc)/.

=cut
sub get_path_to_module {
  my $self   = shift;
  my $module = shift || ref($self) || $self;

  $module =~ s#::#/#g;
  $module .= '.pm';
  
  if (defined $INC{$module}) {
    my $path = realpath($INC{$module});
    $path =~ s/[^\/]+\.pm//;
    return $path;
  }
  else {
    warn "Couldn't find path for $module\n";
  }
}


1;
