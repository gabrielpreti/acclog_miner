package ProccessModel::PhaseContainer;

use v5.14;
use warnings;
use strict;

use ProccessModel::MiningPhase;

use Moose;
use namespace::autoclean;



has 'phases' => (
	is      => 'rw',
	isa => 'ArrayRef[ProccessModel::MiningPhase]'
);

sub execute {
	my $self = shift;
	foreach my $p ( @{$self->phases} ) {
		my $fase = $p->desc;
		say "Starting $fase ...";
		$p->execute();
		say "$fase done.";
	}
}

__PACKAGE__->meta->make_immutable;
1;
