package TR::Standard;
use strict;
use warnings;
use utf8;
use attributes;

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
}

1;
