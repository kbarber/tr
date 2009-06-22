package TR::Context;
use TR::Standard;

use vars qw($VERSION);
use version; $VERSION = qv('1.1');

=head1 NAME

    TR::Context - Base class for TR::Context::* modules.

=head1 VERSION

    See $VERSION

=head1 LICENSE AND COPYRIGHT

    GNU GENERAL PUBLIC LICENSE
	  Version 3, 29 June 2007

    Copyright (C) 2009 Alfresco Software Ltd <http://www.alfresco.com>

=head1 SYNOPSIS

    See <TR::Context::JSON>

=head1 DESCRIPTION 

    Basic methods etc for all TR::Context modules

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

use base 'Class::Accessor::Fast';
__PACKAGE__->mk_accessors(qw/supported request/);

=head2 handles

 Called by TR to see if this module handles the current contact type.

=cut

sub handles {
    my ( $self, %args ) = @_;

    my $supported_types = $self->supported;

    if ( not $supported_types ) {
        return;
    }

    my $request = $args{'request'};

    my $content_type = $request->content_type();

    foreach my $type ( @{$supported_types} ) {
        if ( lc($content_type) eq lc($type) ) {
            $self->request($request);
            return $self;
        }
    }

    return;
}

=head2 result

  Results accessor:
    Stores/merges results given or return results stored.
  
=cut

sub result {
    my ( $self, @args ) = @_;

    if (@args) {
        my $result = @args > 1 ? {@args} : $args[0];

        if ( not ref $result ) {
            croak('result takes a hash or hashref');
        }

        if ( not $self->{'result'} ) {
            $self->{'result'} = {};
        }

        _merge_hash( $self->{'result'}, $result );
    }

    return $self->{'result'};
}

=head2 _merge_hash

  Simply and recursively merges any hashes.

=cut 

sub _merge_hash {
    my ( $a, $b ) = @_;

    foreach my $key ( keys %{$b} ) {
        if ( $a->{$key}
            && ref $a->{$key} eq 'HASH' )
        {
            _merge_hash( $a->{$key}, $b->{$key} );
        }
        else {
            $a->{$key} = $b->{$key};
        }
    }

    return;
}

sub init {
}

1;
