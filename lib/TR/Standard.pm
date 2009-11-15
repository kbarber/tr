package TR::Standard;
use strict;
use warnings;
use utf8;
use attributes;
use Log::Log4perl;

use vars qw($VERSION);
use version; $VERSION = qv('1.0');

=head1 NAME

TR::Standard - import standard options to TR modules.

=head1 VERSION

See $VERSION

=head1 SYNOPSIS

  use TR::Standard;

=head1 DESCRIPTION

This provides a convenient way to enable strict, warnings, and utf8.

=head1 SUBROUTINES/METHODS

=cut

=over 4

=item import 

Set up default options to be used by all modules.

ie:

  use strict;
  use warnings;
  use utf8;

=cut

sub import {
    warnings->import();
    strict->import();
    utf8->import();
    Log::Log4perl->import();

    return;
}

=back

=head1 AUTHOR

Craig Knox

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2009 Alfresco Software Ltd <http://www.alfresco.com>

  This file is part of TR.
    
  TR is free software: you can redistribute it and/or modify
  it under the terms of the GNU Affero General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
    
  TR is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU Affero General Public License
  along with TR.  If not, see <http://www.gnu.org/licenses/>.

=cut

1;
