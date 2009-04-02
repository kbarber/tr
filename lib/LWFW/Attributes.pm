package LWFW::Attributes;
use strict;
use warnings;
use base 'Class::Accessor::Fast';

my @handler_types = qw/Local Regex/;

=head2 MODIFY_CODE_ATTRIBUTES

  Handles custom code attributes

=cut
sub MODIFY_CODE_ATTRIBUTES {
  my ($package, $code_ref, @attr) = @_;
  # TODO Allow Attribute::Handler type hooks?
  foreach my $attr (@attr) {
    if ($package->can($attr)) {
    }
  }
  
  push @{$LWFW::attribute_cache{$package}{$code_ref}}, @attr;
  return ();
}

=head2 MODIFY_CODE_ATTRIBUTES

  Returns array of attributes for a given code ref

=cut
sub FETCH_CODE_ATTRIBUTES {
  my ($package, $code_ref) = @_;
  if (my $attributes = $LWFW::attribute_cache{$package}{$code_ref}) {
    return @{$attributes};
  }
    
  return ();
}

=head2 _get_handler_paths

  Returns list of handlers registered with attributes in @handler_types

=cut
sub _get_handler_paths {
  my %handlers = ();

  foreach my $package  (keys %LWFW::attribute_cache) {
    foreach my $code_ref (keys %{$LWFW::attribute_cache{$package}}) {
      my $method_name = _get_name_by_code_ref($package, $code_ref);

      # generate a path from package/method
      my $path = lc($package);
      $path =~ s#::#/#g;
      $path =~ s#^[^/]+##; # Remove base package name

      # Store package and method details
      $handlers{$path}{'package'} = $package;
      push @{$handlers{$path}{'methods'}}, lc($method_name);
    }
  }

  return \%handlers;
}

=head2 _get_name_by_code_ref

  Resolves a code ref to sub name

=cut
sub _get_name_by_code_ref {
  my ($package, $code_ref) = @_;

  my %symbol_table;
  eval('%symbol_table = %' . $package . '::'); 
  foreach my $entry (keys %symbol_table) {
    my $symbol = $symbol_table{$entry};
    if (*{$symbol}{'CODE'}) {
      if(*{$symbol}{'CODE'} eq $code_ref) {
        return *{$symbol}{'NAME'};
      }
    }
  }
}

=head2 _is_public_method 

  Checks to see if a method is allowed.

=cut
sub _is_public_method {
  my $self   = shift;
  my $method = shift;

  if (my $cv = $self->can($method)) {
    my @attributes = attributes::get($cv);
    if (@attributes ~~ /Local/) {
      return 1;
    }
  }

  return;
}

1;
