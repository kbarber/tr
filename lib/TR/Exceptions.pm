#!/usr/bin/perl
use strict;
use warnings;
use vars qw($VERSION);
use version; $VERSION = qv('1.1');

=head1 NAME

  E - TR Exceptions

=head1 VERSION

  See $VERSION

=head1 LICENSE AND COPYRIGHT

  GNU GENERAL PUBLIC LICENSE
	Version 3, 29 June 2007

  Copyright (C) 2009 Alfresco Software Ltd <http://www.alfresco.com>

=head1 SYNOPSIS

    use TR::Exceptions;
    E::Fatal->throw("Some issue");
    E::Invalid->throw("Some issue");
    E::Invalid::Config->throw("Some issue");
    E::Invalid::Params->throw("Some issue");

=head1 DESCRIPTION 

    TR Exceptions.

=head1 CONFIGURATION

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 AUTHOR

=head1 DIAGNOSTICS

=head1 BUGS AND LIMITATIONS

=head1 USAGE

=head1 EXIT STATUS

=head1 OPTIONS

    See <Exception::Class>

=head1 REQUIRED ARGUMENTS

    See <Exception::Class>

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

1;
