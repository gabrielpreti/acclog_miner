package ProccessModel::MiningPhase;

use v5.14;
use warnings;
use strict;

use Moose;
use namespace::autoclean;

has 'desc' => (is => 'rw', required => 0);
has 'context' => (is => 'rw', required => 0);

sub execute() {
	die 'You must define execute() in a subclass';
}

__PACKAGE__->meta->make_immutable;
1;