#!/usr/bin/perl
use strict;
use warnings;
use vars qw($VERSION);
use version; $VERSION = qv('1.1');

=head1 NAME

E - TR Exceptions

=head1 VERSION

See $VERSION

=head1 SYNOPSIS

  use TR::Exceptions;

  E::Fatal->throw("Some issue");
  E::Invalid->throw("Some issue");
  E::Invalid::Config->throw("Some issue");
  E::Invalid::Params->throw("Some issue");

=head1 DESCRIPTION 

TR Exceptions.

=head1 SUBROUTINES/METHODS

See <Exception::Class>

=cut

use Exception::Class (
    'E' => { fields => ['err_code'], }
    ,    # 'E' is quick to type and shouldn't have any name space clashes.
    'E::Fatal' => {
        isa         => 'E',
        description => 'Time to give up and go home',
    },
    'E::Invalid' => {
        isa         => 'E',
        description => 'Something was done wrong',
    },
    'E::Invalid::Config' => {
        isa         => 'E::Invalid',
        description => 'Something is wrong with the configuration',
    },
    'E::Invalid::Params' => {
        isa         => 'E::Invalid',
        description => 'Method was passed wrong params',
    },
    'E::Invalid::Method' => {
        isa         => 'E::Invalid',
        description => 'Method is unsupported',
    },
    'E::Invalid::Result' => {
        isa         => 'E::Invalid',
        description => 'Method returned unexpected result',
    },
    'E::Invalid::ContentType' => {
        isa         => 'E::Invalid',
        description => 'Unhandled content-type',
    },

    'E::Invalid::EmptyResults' => {
        isa         => 'E::Invalid',
        description => 'Empty results',
    },

    'E::Service' => {
        isa         => 'E',
        description => 'Problem with talking to a remote service',
    },

    'E::Redirect' => {
        isa         => 'E',
        description => 'Handled by another controller.',
        fields      => [ 'newpath', 'method' ],
    },
);

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
