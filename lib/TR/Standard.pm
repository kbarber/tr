package TR::Standard;
use strict;
use warnings;
use utf8;
use attributes;
use Log::Log4perl;

=head2 import 

  Set up default options to be used by all modules.

  ie:
  use strict;
  use warnings;
  use utf8;
  use decent method resolving.

=cut
sub import {
  warnings->import();
  strict->import();
  utf8->import();
  Log::Log4perl->import();
}

1;
