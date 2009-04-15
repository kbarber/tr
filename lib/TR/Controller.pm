package TR::Controller;
use TR::Global;
use base 'TR::Attributes';
__PACKAGE__->mk_ro_accessors(qw/context config/);

sub new {
  my ($proto, %args) = @_;
  my ($class) = ref $proto || $proto;

  my $self = bless \%args, $class;
  $self->_init();

  return $self;
}

sub _init {
}

1;
