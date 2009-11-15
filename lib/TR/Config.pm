package TR::Config;
use TR::Standard;
use English qw(-no_match_vars);
use TR::Exceptions;

use vars qw($VERSION);
use version; $VERSION = qv('1.1');

=head1 NAME

    TR::Config - Handle TR config file/s

=head1 VERSION

    See $VERSION

=head1 SYNOPSIS

    See <TR>

=head1 DESCRIPTION 

    Loads TR config file/s

=head1 CONFIGURATION AND ENVIRONMENT

    See <TR>

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 AUTHOR

=head1 DIAGNOSTICS

=head1 BUGS AND LIMITATIONS

  Probably a few.

=head1 SUBROUTINES/METHODS

=cut

use Config::Any::JSON;

# use Config::Multi; Should split the config into multi files and use this

my %INSTANCES;

sub new {
    my ( $proto, $file ) = @_;
    my ($class) = ref $proto || $proto;

    # Only instantiate one instance per file.
    return $INSTANCES{$file} if $INSTANCES{$file};

    my $self;
    eval {
        $self = Config::Any::JSON->load($file);
        1;
    }
    or do {
        E::Invalid::Config->throw($EVAL_ERROR);
    };

    bless $self, $class;

    $INSTANCES{$file} = $self;

    return $self;
}

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
