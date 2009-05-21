package TR::Config;
use TR::Standard;
use TR::Exceptions;

use Config::Any::JSON;
# use Config::Multi; Should split the config into multi files and use this

my %INSTANCES;

sub new {
  my ($proto, $file) = @_;
  my ($class) = ref $proto || $proto;

  # Only instantiate one instance per file.
  return $INSTANCES{$file} if $INSTANCES{$file};

  my $self;
  eval {
    $self = Config::Any::JSON->load($file);
  };
  if ($@) {
    E::Invalid::Config->throw($@);
  }

  bless $self, $class;

  $INSTANCES{$file} = $self;

  return $self;
}

1;
