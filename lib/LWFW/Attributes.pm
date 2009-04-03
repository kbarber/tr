package LWFW::Attributes;
use strict;
use warnings;
use Attribute::Handlers;
use Kwalify;
use Data::Dumper;

=head2 UNIVERSAL::Local

  Handles the Local attribute given to methods and matches
  paths to handle base on Module and method name.

=cut
sub UNIVERSAL::Local : ATTR(CODE, BEGIN) {
  my ($package, $symbol, $referent, $attr, $data) = @_;
  push @{$LWFW::attribute_cache{$package}{$referent}}, $attr;
}

=head2 UNIVERSAL::Regex

  Handles the Regex attribute given to methods and matches
  paths to handle with a regex

=cut
sub UNIVERSAL::Regex : ATTR(CODE, BEGIN) {
  my ($package, $symbol, $referent, $attr, $data) = @_;
  push @{$LWFW::attribute_cache{$package}{$referent}}, $attr;
}

=head2 UNIVERSAL::Params

  Handles the Params attribute when given to methods
  and checks parameters passed before running method.

=cut
sub UNIVERSAL::Params : ATTR(CODE) {
  print Dumper @_;
}

=head2 _get_handler_paths

  Returns list of handlers registered with attributes

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
      push @{$handlers{$path}{'methods'}}, $method_name;
    }
  }

  return \%handlers;
}

=head2 _get_name_by_code_ref

  Resolves a code ref to sub name, a bit ugly but attributes pass
  symbols and not method names.

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

1;
