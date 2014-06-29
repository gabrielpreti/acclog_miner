package TrendStats::MovingMeanBasedOutlier;

use v5.14;
use warnings;
use strict;

use Moose;
use namespace::autoclean;

use Statistics::Descriptive;
use PDL;
use PDL::NiceSlice;
use PDL::Core;

extends 'TrendStats::TrendFilter';

has 'windowSize' => ( is => 'rw', required => 1 );
has 'coeficient' => ( is => 'rw', required => 1 );

sub normalize {
	my ($input_data) = shift;
	my ( $mean, $stdev, $median, $min, $max, $adev ) = $input_data->stats();
	$input_data .= ( $input_data - $mean ) / $stdev;

	return $input_data;
}

sub filter {
	my $self               = shift;
	my $data               = shift;          #um piddle;
	my @intervalsToAnalize = shift;

	normalize( $data ( , 1 : -1 ) );

	my %outliers = ();
	my ( $nColumns, $nLines ) = $data->dims();

	foreach my $l (@intervalsToAnalize) {
		my ( $meanAll, $stdevAll, $medianAll, $minAll, $maxAll, $adevAll ) = $data ( , ( $l - $self->windowSize() ) : ( $l - 1 ) )->stats();
		foreach my $c ( 0 .. ( $nColumns - 1 ) ) {
			my ( $mean, $stdev, $median, $min, $max, $adev ) = $data ( $c, ( $l - $self->windowSize() ) : ( $l - 1 ) )->stats();
			my $piddleMapping = $data ( $c, 0 )->sclr;

			my $v              = $data ( $c, $l )->sclr;
			my $upperThreshold = $mean + $self->coeficient * $stdevAll;
			my $lowerThreshold = $mean - $self->coeficient * $stdevAll;

			if ( $v > $upperThreshold || $v < $lowerThreshold ) {
				if ( defined( $outliers{$piddleMapping} ) ) {
					$outliers{$piddleMapping} = List::Util::max( $outliers{$piddleMapping}, ( $v - $upperThreshold ) / $mean, ( $lowerThreshold - $v ) / $mean );
				}
				else {
					$outliers{$piddleMapping} = List::Util::max( ( $v - $upperThreshold ) / $mean, ( $lowerThreshold - $v ) / $mean );
				}

			}
		}
	}

	return %outliers;

}

__PACKAGE__->meta->make_immutable;
1;
