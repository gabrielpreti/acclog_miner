package AccessLogModel::Transaction;

use v5.14;
use warnings;
use strict;



use Moose;
use namespace::autoclean;

use AccessLogModel::Request;

has 'userId'    => ( is => 'rw' );
has 'startTime' => ( is => 'rw' );
has 'requests'  =>
  ( is => 'rw', isa => 'ArrayRef[Request]', default => sub { [] } );

has 'transactionDurationInSeconds' => ( is => 'ro', default => 300 );

sub startTransaction {
	my ( $self, $request ) = @_;

	$self->userId( $request->ip );
	$self->startTime( $request->date );
	push @{ $self->requests }, $request;
}

sub addRequestToTransaction {
	my ( $self, $request ) = @_;

	my $lastRequest = @{$self->requests}[-1];
	if(!defined($lastRequest) || !($lastRequest->uri eq $request->uri)){
		push @{ $self->requests }, $request;	
	} 
}

sub write {
	my ( $self, $fileHandle ) = @_;
	
	my $csvSep = $AccessLogModel::Request::csvSep;

	my $size = @{ $self->requests };
	if ( $size == 0 ) {
		warn "Array size is 0";
	}
	if ( defined $fileHandle ) {
		print $fileHandle "$self->{userId}$csvSep";
		print $fileHandle "$self->{startTime}$csvSep";
		foreach my $r ( @{ $self->requests } ) {
			print $fileHandle "$r->{uri}$csvSep";
		}
		print $fileHandle "\n";
	}
	else {
		print "$self->{userId}$csvSep";
		print "$self->{startTime}$csvSep";
		foreach my $r ( @{ $self->requests } ) {
			print "$r->{uri}$csvSep";
		}
		print "\n";
	}
}

sub readFromCsv {
	my ( $self, @row ) = @_;
	
	$self->userId($row[0]);
	$self->startTime(Time::Piece->strptime( $row[1], "%a %b  %d %H:%M:%S %Y" ));
	
	my $rowSize = @row;
	for(my $i=2; $i<$rowSize; $i++){
		my $r = AccessLogModel::Request->new();
		$r->uri($row[$i]);
		push @{ $self->requests }, $r;
	}
}


__PACKAGE__->meta->make_immutable;
1;