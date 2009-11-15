package TR::Attributes;
use strict;
use warnings;
use Attribute::Handlers;

=head1 NAME

TR::Attributes - handles attributes for TR

=head1 VERSION

See $TR::VERSION
   
=head1 SYNOPSIS

See <TR>

=head1 DESCRIPTION 

This module handles a list of attributes control modules can have.
It maintains a list of functions/attributes, and provides methods
to query whether a function handles a given path and is a public method.

=head1 SUBROUTINES/METHODS

=over 4

=cut

use base 'Class::Accessor::Fast';

=item UNIVERSAL::Params

Handles the Params attribute when given to methods
and checks parameters passed before running method.

=cut

sub UNIVERSAL::Params : ATTR(CODE, BEGIN) {
    my ($package, $symbol, $referent, $attr,
        $data,    $phase,  $filename, $linenum) = @_;

    if ( not ref($data) eq 'ARRAY' ) {
        return;    # TODO: Maybe warn
    }
    else {
        push @{ $TR::method_schema{$package}{$referent} }, $data;
    }

    return;
}

=item UNIVERSAL::Local

Handles the Local attribute given to methods and matches
paths to handle base on Module and method name.

=cut

sub UNIVERSAL::Local : ATTR(CODE, BEGIN) {
    my ($package, $symbol, $referent, $attr,
        $data,    $phase,  $filename, $linenum) = @_;

    push @{ $TR::attribute_cache{'Local'}{$package}{$referent} }, $attr;

    return;
}

=item UNIVERSAL::Regex

Handles the Regex attribute given to methods and matches
paths to handle with a regex

=cut

sub UNIVERSAL::Global : ATTR(CODE, BEGIN) {
    my ($package, $symbol, $referent, $attr,
        $data,    $phase,  $filename, $linenum) = @_;

    push @{ $TR::attribute_cache{'Global'}{$package}{$referent} }, $attr;

    return;
}

=item _get_handler_paths

Returns list of handlers registered with attributes

=cut

my %handlers;    # Only generate once.

sub _get_handler_paths {
    return \%handlers if %handlers;

    foreach my $package ( keys %{ $TR::attribute_cache{'Local'} } ) {
        foreach my $code_ref ( keys %{ $TR::attribute_cache{'Local'}{$package} } ) {
            my $method_name = _get_name_by_code_ref( $package, $code_ref );

            # generate a path from package/method
            my $path = lc($package);
            $path =~ s#::#/#g;
            $path =~ s#^[^/]+/c##;    # Remove base package name

            # Not happy about having this here at all, need to sort out
            # Attribute handling to work better.
            my $full_method_name = $package . '::' . $method_name;

            # Store package and method details
            $handlers{$path}{'package'} = $package;
            push @{ $handlers{$path}{'methods'} }, $method_name;
        }
    }

    return \%handlers;
}

=item _get_name_by_code_ref

Resolves a code ref to sub name, a bit ugly but attributes pass
symbols and not method names in BEGIN.

=cut

sub _get_name_by_code_ref {
    my ( $package, $code_ref ) = @_;

    my %symbol_table;

    ## no critic
    eval( '%symbol_table = %' . $package . '::' );
    foreach my $entry ( keys %symbol_table ) {
        my $symbol = $symbol_table{$entry};
        if ( *{$symbol}{'CODE'} ) {
            if ( *{$symbol}{'CODE'} eq $code_ref ) {
                return *{$symbol}{'NAME'};
            }
        }
    }

    return;
}

=item _is_public_method 

Checks to see if a method is allowed.

=cut

sub _is_public_method {
    my $self = shift;
    my $method = shift || return;

    my $package = ref($self);

    if ( my $cv = $self->can($method) ) {

        # Local
        if (    defined $TR::attribute_cache{'Local'}{$package}
            and defined $TR::attribute_cache{'Local'}{$package}{$cv} ) {
            return 1;
        }
        else {

            # Global
            foreach my $pkg ( keys %{ $TR::attribute_cache{'Global'} } ) {
                if ( defined $TR::attribute_cache{'Global'}{$pkg}{$cv} ) {
                    return 1;
                }
            }
        }
    }

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
