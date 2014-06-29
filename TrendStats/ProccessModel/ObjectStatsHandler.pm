package ProccessModel::ObjectStatsHandler;

use v5.14;
use warnings;
use strict;

use Moose;
use POSIX;
use namespace::autoclean;

has 'attributes' => (
	is  => 'rw',
	isa => 'ArrayRef[Str]'
);
has 'timeWindowSize' => ( is => 'rw', required => 1, isa => 'Int' );
has 'analysisInitialTime' => ( is => 'rw', required => 0 );
has 'analysisFinalTime'   => ( is => 'rw', required => 0 );

sub getValueFromObject() {
	my $self   = shift;
	my $object = shift;

	my $value = "";
	foreach my $att ( @{ $self->attributes() } ) {
		$value .= $object->{$att} . "_";
	}
	chop($value);    #remove o último caracter "_"
	return $value;
}

sub getAttributeValueFromObject() {
	my $self   = shift;
	my $object = shift;
	my $att    = shift;

	if ( index( $att, '_' ) == -1 ) {
		return $object->{$att};
	}
	else {
		my $value = "";
		foreach my $s ( split( '\_', $att ) ) {
			$value .= $object->{$s} . "_";
		}
		chop($value);    #remove o último caracter "|"
		return $value;
	}
}

sub getTimeWindowIntervalFromDate {
	my ( $self, $date ) = @_;

	my $hour   = $date->hour() < 10                                    ? '0' . $date->hour()                                    : $date->hour();
	my $day    = $date->day_of_month() < 10                            ? '0' . $date->day_of_month()                            : $date->day_of_month();
	my $month  = $date->mon() < 10                                     ? '0' . $date->mon()                                     : $date->mon();
	my $minute = floor( $date->minute() / $self->timeWindowSize ) < 10 ? '0' . floor( $date->minute() / $self->timeWindowSize ) : floor( $date->minute() / $self->timeWindowSize );

	return $date->year() . $month . $day . $hour . $minute;
}

sub getTimeWindowIntervalFromRequest {
	my ( $self, $request ) = @_;
	return getTimeWindowIntervalFromDate( $self, $request->date );
}

sub identifyPeriodsToAnalyse {
	my $self       = shift;
	my @allPeriods = @{ shift() };

	my $startInterval = getTimeWindowIntervalFromDate( $self, Time::Piece->strptime( $self->analysisInitialTime, "%d/%m/%Y %H:%M" ) );
	my $endInterval   = getTimeWindowIntervalFromDate( $self, Time::Piece->strptime( $self->analysisFinalTime,   "%d/%m/%Y %H:%M" ) );

	my @selectedIntervals;
	my $index = 0;
	while ( $allPeriods[$index] < $startInterval ) {
		$index += 1;
	}
	while ( defined( $allPeriods[$index] ) && $allPeriods[$index] <= $endInterval ) {
		push( @selectedIntervals, $index+1 );#a indexação dos perídos, para efeitos da nossa análise, começa em 1;
		$index += 1;
	}

	return @selectedIntervals;
}

__PACKAGE__->meta->make_immutable;
1
