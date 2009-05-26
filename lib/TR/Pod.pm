package TR::Pod;
use TR::Standard;

use PPI;
use Cache::FastMmap;
use Cwd qw/realpath/;

use base 'Class::Accessor::Fast';

__PACKAGE__->mk_accessors(qw/schema_cache rschema_cache/);

my $SINGLETON;

=head2 new

  Init pod module

=cut
sub new {
  return $SINGLETON if $SINGLETON;

  my $proto = shift;
  my($class) = ref $proto || $proto;

  my $self = bless {}, $class;

  my $schema_cache =  new Cache::FastMmap(share_file      => '/var/cache/tr/TR_schema.cache.' . $<,
                                          cache_not_found => 1,
                                          page_size       => '4k',  # Most schemas are smaller than 1k
                                          num_pages       => '157', # Max pages, should be prime.
                                          context         => $self,
                                          read_cb         => sub { $_[0]->_get_schema($_[1]) }, # Fetch schema on cache miss
                                          expire_time     => '1h',
                                         );
  my $rschema_cache = new Cache::FastMmap(share_file      => '/var/cache/tr/TR_rschema.cache.' . $<,
                                          cache_not_found => 1,
                                          page_size       => '4k',  # Most schemas are smaller than 1k
                                          num_pages       => '157', # Max pages, should be prime.
                                          context         => $self,
                                          read_cb         => sub { $_[0]->_get_result_schema($_[1]) }, # Fetch schema on cache miss
                                          expire_time     => '1h',
                                         );

  $self->schema_cache($schema_cache);
  $self->rschema_cache($rschema_cache);

  $SINGLETON = $self;

  return $self;
}

=head2 _fetch 

  Returns PPI::Document object for a module if it's already been loaded, 
  else loads up a PPI::Document object for the module.

=cut
sub _fetch {
  my ($self, %args) = @_;

  my $module = $args{'module_file'} or die 'Need to pass module_file';

  my $document = PPI::Document->new($module) or die $!;

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

=head2 _get_from_pod
  
  Looks for through pod for given "match" for method.
  TODO: lots of overlap with get_documentation need to refactor

=cut
sub _get_from_pod {
  my ($self, %args) = @_;

  return unless $args{'package'};
  return unless $args{'method'};
  return unless $args{'match'};

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
                                  and ($_[1]->content =~ /$args{'match'}/) 
                                  })) {
        my ($schema) = @$children[0]->content() =~ /$args{'match'}(.+)=cut/ms;
        return $schema;
      }
    }
  }

  return;
}


=head2 get_schema
 
  Grab the schema for a method from cache

=cut
sub get_schema {
  my ($self, %args) = @_;

  return unless $args{'package'};
  return unless $args{'method'};

  return $self->schema_cache->get(join(':', $args{'package'}, $args{'method'}));
}

=head2 _get_schema 

  Call on cache miss to fetch schema from perl module.

=cut
sub _get_schema {
  my ($self, $key) = @_;

  $key =~ /^(.*):([^:]+$)/;

  return $self->_get_from_pod(package => $1, method => $2, match => '=begin schema');
}

=head2 get_result_schema
 
  Grab the result schema for a method.

=cut
sub get_result_schema {
  my ($self, %args) = @_;

  return unless $args{'package'};
  return unless $args{'method'};

  return $self->rschema_cache->get(join(':', $args{'package'}, $args{'method'}));
}

=head2 _get_result_schema 

  Call on cache miss to fetch result schema from perl module.

=cut
sub _get_result_schema {
  my ($self, $key) = @_;

  $key =~ /^(.*):([^:]+$)/;

  return $self->_get_from_pod(package => $1, method => $2, match => '=begin result_schema');
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
