package AccessLogModel::Request;

use v5.14;
use warnings;
use strict;

use Time::Piece;
use Text::CSV;
use Moose;
use namespace::autoclean;

has 'ip'         => ( is => 'rw' );
has 'port'       => ( is => 'rw' );
has 'date'       => ( is => 'rw' );
has 'method'     => ( is => 'rw' );
has 'uri'        => ( is => 'rw' );
has 'returnCode' => ( is => 'rw' );
has 'referrer'   => ( is => 'rw' );
has 'userAgent'  => ( is => 'rw' );
has 'time'       => ( is => 'rw' );

our $csvSep = "\t";

sub readFromAccessLog {
	my ( $self, $line ) = @_;

	my $resultOk = $line =~ m/^(?<ip>.*)\s(?<port>\d+)\s\-\s.*\[(?<day>\d\d)\/(?<month>\w\w\w)\/(?<year>\d\d\d\d)\:(?<hour>\d\d)\:(?<minute>\d\d)\:(?<second>\d\d)\s.*?\]\s\"(?<method>\w+?)\s\/(?<uri>.*?)\sHTTP.*?\"\s(?<return>\d+?)\s.*?\"(?<referrer>.*?)\"\s\"(?<userAgent>.*?)\"\s\"(?<uid>.*)\"\s(?<time>\d*)$/;
	if ( !$resultOk ) {
		return 0;
	}

	$self->ip( $+{ip} );
	$self->port( $+{port} );
	$self->date( Time::Piece->strptime( "$+{day}/$+{month}/$+{year} $+{hour}:$+{minute}:$+{second}", "%d/%b/%Y %H:%M:%S" ) );
	$self->method( $+{method} );
	$self->uri( $+{uri} );
	$self->returnCode( $+{return} );
	$self->referrer( $+{referrer} );
	$self->userAgent( $+{userAgent} );
	$self->time( $+{time} );

	return 1;
}

sub readFromCsv {
	my ( $self, $row ) = @_;

	$self->ip( $$row[0] );
	$self->port( $$row[1] );
	$self->date( Time::Piece->strptime( $$row[2], "%a %b  %d %H:%M:%S %Y" ) );
	$self->method( $$row[3] );
	$self->uri( $$row[4] );
	$self->returnCode( $$row[5] );
	$self->referrer( $$row[6] );
	$self->userAgent( $$row[7] );
	$self->time( $$row[8] );
}

sub generateCsvLine {
	my ($self) = @_;
	return "$self->{ip}$csvSep" . "$self->{port}$csvSep" . "$self->{date}$csvSep" . "$self->{method}$csvSep" . "$self->{uri}$csvSep" . "$self->{returnCode}$csvSep" . "$self->{referrer}$csvSep" . "$self->{userAgent}$csvSep" . "$self->{time}" . "\n";
}

sub writeToCsv {
	my ( $self, $fileHandle ) = @_;

	if ( defined $fileHandle ) {
		print $fileHandle $self->generateCsvLine();
	}
	else {
		print $self->generateCsvLine();
	}
}

__PACKAGE__->meta->make_immutable;
1;
