package LWFW::Plugins;
use strict;
use warnings;
use Cwd qw/realpath/;
use File::Find qw/find/;

use base 'Class::Accessor::Fast';

$LWFW::Plugins::Loaded = 0;

=head2 _load_plugins

  Look for modules under the current 
  package ref($self) and load any modules found there automatically.

=cut
sub _load_plugins {
  my $self = shift;

  return if $LWFW::Plugins::Loaded; # Only attempt to load once.
  $LWFW::Plugins::Loaded = 1;

  my $module = shift || ref($self);

  my $module_dir = $self->_get_path_to_module();

  find(sub { _load_module($File::Find::name, $module_dir) }, $module_dir);
}

=head2 _get_path_to_module

  Grab the path to a module and return it's realpath (.. ie get rid 
                                                      of /../../ etc)/.

=cut
sub _get_path_to_module {
  my $self   = shift;
  my $module = shift || ref($self) || $self;

  $module =~ s#::#/#g;
  $module .= '.pm';
  
  if (defined $INC{$module}) {
    my $path = realpath($INC{$module});
    $path =~ s/[^\/]+\.pm//;
    return $path;
  }
  else {
    warn "Couldn't find path for $module\n";
  }
}

=head2 _load_module

  Checks given file to see if it's a module,
  if it is tries to load it. 

=cut
sub _load_module {
  my $file = shift;
  my $base_dir = shift;

  if ($file =~ /\.pm$/) {
    $file =~ s/^$base_dir//;

    # Convert file name into module;
    my $module = $file;
    $module =~ s/\.pm//;
    $module =~ s#/#::#g;
    eval("use $module;");
    if ($@) {
      print "Failed to load module: $@\n";
    }
  }
}

1;
