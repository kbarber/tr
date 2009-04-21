package TR::Config;
use TR::Standard;

use Config::Any::JSON;

my %INSTANCES;

sub new {
  my ($proto, $file) = @_;
  my ($class) = ref $proto || $proto;

  # Only instantiate one instance per file.
  return $INSTANCES{$file} if $INSTANCES{$file};

  my $self = Config::Any::JSON->load($file) ;
  bless $self, $class;

  $INSTANCES{$file} = $self;

  return $self;
}

1;
