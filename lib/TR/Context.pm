package TR::Context;
use TR::Global;

use base 'Class::Accessor::Fast';
__PACKAGE__->mk_accessors(qw/supported request/);

=head2 handles

 Called by TR to see if this module handles the current contact type.

=cut
sub handles {
  my ($self, %args) = @_;

  my $supported_types = $self->supported;

  return unless $supported_types;

  my $request      = $args{'request'};
  my $content_type = $request->content_type() || 'text/html';

  foreach my $type (@{$supported_types}) {
    if ( lc($content_type) eq lc($type)) {
      $self->request($request);
      $self->_init();
      return $self;
    }
  }

  return;
}

=head2 result

  Results accessor:
    Stores/merges results given or return results stored.
  
=cut
sub result {
  my $self = shift;

  if (@_) {
    my $result = @_ > 1 ? {@_} : $_[0];
    croak('result takes a hash or hashref') unless ref $result;
    $self->{'result'} = {} if not $self->{'result'};
    _merge_hash($self->{'result'}, $result);
  }

  return $self->{'result'};
}

=head2 _merge_hash

  Simply and recursively merges any hashes.

=cut 
sub _merge_hash {
  my ($a, $b) = @_;

  foreach my $key ( keys %$b ) {
    if ($a->{$key} &&
        ref $a->{$key} eq 'HASH') {
      _merge_hash($a->{$key}, $b->{$key});
    }
    else {
      $a->{$key} = $b->{$key};
    }
  }
}

sub _init {
}

1;
