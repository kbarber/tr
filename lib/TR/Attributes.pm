package TR::Attributes;
use strict;
use warnings;
use Attribute::Handlers;

use base 'Class::Accessor::Fast';

=head2 UNIVERSAL::Params

  Handles the Params attribute when given to methods
  and checks parameters passed before running method.

=cut
sub UNIVERSAL::Params :ATTR(CODE, BEGIN) {
  my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
  if (not ref($data) eq 'ARRAY') {
    return; # TODO: Maybe warn
  }
  else {
    push @{$TR::method_schema{$package}{$referent}}, $data;
  }

  return;
}

=head2 UNIVERSAL::Local

  Handles the Local attribute given to methods and matches
  paths to handle base on Module and method name.

=cut
sub UNIVERSAL::Local :ATTR(CODE, BEGIN) {
  my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
  push @{$TR::attribute_cache{'Local'}{$package}{$referent}}, $attr;

  return;
}

=head2 UNIVERSAL::Regex

  Handles the Regex attribute given to methods and matches
  paths to handle with a regex

=cut
sub UNIVERSAL::Global :ATTR(CODE, BEGIN) {
  my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
  push @{$TR::attribute_cache{'Global'}{$package}{$referent}}, $attr;

  return;
}

=head2 _get_handler_paths

  Returns list of handlers registered with attributes

=cut
my %handlers;  # Only generate once.
sub _get_handler_paths {
  return \%handlers if %handlers;
  foreach my $package  (keys %{$TR::attribute_cache{'Local'}}) {
    foreach my $code_ref (keys %{$TR::attribute_cache{'Local'}{$package}}) {
      my $method_name = _get_name_by_code_ref($package, $code_ref);

      # generate a path from package/method
      my $path = lc($package);
      $path =~ s#::#/#g;
      $path =~ s#^[^/]+/c##; # Remove base package name

      # Not happy about having this here at all, need to sort out
      # Attribute handling to work better.
      my $full_method_name = $package . '::' . $method_name;

      # Store package and method details
      $handlers{$path}{'package'} = $package;
      push @{$handlers{$path}{'methods'}}, $method_name;
    }
  }

  return \%handlers;
}

=head2 _get_name_by_code_ref

  Resolves a code ref to sub name, a bit ugly but attributes pass
  symbols and not method names in BEGIN.

=cut
sub _get_name_by_code_ref {
  my ($package, $code_ref) = @_;

  my %symbol_table;

  ## no critic
  eval('%symbol_table = %' . $package . '::'); 
  foreach my $entry (keys %symbol_table) {
    my $symbol = $symbol_table{$entry};
    if (*{$symbol}{'CODE'}) {
      if(*{$symbol}{'CODE'} eq $code_ref) {
        return *{$symbol}{'NAME'};
      }
    }
  }

  return;
}

=head2 _is_public_method 

  Checks to see if a method is allowed.

=cut
sub _is_public_method {
  my $self   = shift;
  my $method = shift || return;

  my $package = ref($self);

  if (my $cv = $self->can($method)) {
    # Local
    if (defined $TR::attribute_cache{'Local'}{$package} and
        defined $TR::attribute_cache{'Local'}{$package}{$cv}) {
      return 1;
    }
    else {
    # Global
      foreach my $pkg (keys %{$TR::attribute_cache{'Global'}}) {
        if (defined $TR::attribute_cache{'Global'}{$pkg}{$cv}) {
          return 1;
        }
      }
    }
  }

  return;
}

1;
