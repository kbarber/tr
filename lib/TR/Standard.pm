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

=head1 LICENSE AND COPYRIGHT

  GNU GENERAL PUBLIC LICENSE
	Version 3, 29 June 2007

  Copyright (C) 2009 Alfresco Software Ltd <http://www.alfresco.com>

=head1 SYNOPSIS

    use TR::Standard;

=head1 DESCRIPTION

    enables strict, warnings, and utf8.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=head1 SUBROUTINES/METHODS

=cut

=head2 import 

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

1;
