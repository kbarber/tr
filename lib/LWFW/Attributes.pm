package LWFW::Attributes;
use strict;
use warnings;
use Attribute::Handlers;
use Data::Dumper;

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
    push @{$LWFW::method_schema{$package}{$referent}}, $data;
  }
}

=head2 UNIVERSAL::Local

  Handles the Local attribute given to methods and matches
  paths to handle base on Module and method name.

=cut
sub UNIVERSAL::Local :ATTR(CODE, BEGIN) {
  my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
  push @{$LWFW::attribute_cache{$package}{$referent}}, $attr;
}

=head2 UNIVERSAL::Regex

  Handles the Regex attribute given to methods and matches
  paths to handle with a regex

=cut
sub UNIVERSAL::Regex :ATTR(CODE, BEGIN) {
  my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
  push @{$LWFW::attribute_cache{$package}{$referent}}, $attr;
}

=head2 _get_handler_paths

  Returns list of handlers registered with attributes

=cut
my %handlers;  # Only generate once.
sub _get_handler_paths {
  return \%handlers if %handlers;
  foreach my $package  (keys %LWFW::attribute_cache) {
    foreach my $code_ref (keys %{$LWFW::attribute_cache{$package}}) {
      my $method_name = _get_name_by_code_ref($package, $code_ref);

      # generate a path from package/method
      my $path = lc($package);
      $path =~ s#::#/#g;
      $path =~ s#^[^/]+##; # Remove base package name

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

  my $package = ref($self);

  if (my $cv = $self->can($method)) {
    if (defined $LWFW::attribute_cache{$package} and
        defined $LWFW::attribute_cache{$package}{$cv}) {
      my @attributes = @{$LWFW::attribute_cache{$package}{$cv}};
      if (@attributes ~~ /Local/) {
        return 1;
      }
    }
  }

  return;
}

1;
