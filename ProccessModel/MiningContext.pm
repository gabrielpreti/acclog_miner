package ProccessModel::MiningContext;

use v5.14;
use warnings;
use strict;

use Moose;
use namespace::autoclean;

has 'context' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
	traits  => ['Hash'],
	handles => {
		exists => 'exists',
		ids    => 'keys',
		get    => 'get',
		set    => 'set'
	}
);

__PACKAGE__->meta->make_immutable;
1;
