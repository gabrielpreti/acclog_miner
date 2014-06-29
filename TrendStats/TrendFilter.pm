package TrendStats::TrendFilter;

use v5.14;
use warnings;
use strict;

use Moose;
use namespace::autoclean;

sub filter {
	die 'You must define filter() in a subclass';
}

__PACKAGE__->meta->make_immutable;
1;