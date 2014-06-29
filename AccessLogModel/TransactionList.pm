package AccessLogModel::TransactionList;

use v5.14;
use warnings;
use strict;

use Moose;
use namespace::autoclean;

use AccessLogModel::Transaction;

has 'transactions' => ( is => 'rw', isa => 'ArrayRef[Transaction]', default => sub { [] } );
has 'startWindowIndex' => ( is => 'rw', default => 0 );

has 'transactionDurationInSeconds' => ( is => 'ro', default => 300 );

sub isRequestInsideTransactionWindow {
	my ( $self, $transaction, $request ) = @_;

	my $diff = $request->date - $transaction->startTime;
	$diff>=0 && $diff<=$self->transactionDurationInSeconds;
}

sub isRequestFromTransactionUser {
	my ( $transaction, $request ) = @_;

	$transaction->userId eq $request->ip;
}

sub analyzeRequest {
	my ( $self, $request ) = @_;

	my $size  = @{ $self->transactions };
	my $found = 0;
	for ( my $i = $self->startWindowIndex ; $i < $size ; $i++ ) {
		if ( !isRequestInsideTransactionWindow( $self, @{ $self->transactions }[$i], $request ) ) {
			$self->startWindowIndex( $self->startWindowIndex + 1 );
			next;
		}

		if ( isRequestFromTransactionUser( @{ $self->transactions }[$i], $request ) ) {
			@{ $self->transactions }[$i]->addRequestToTransaction($request);
			$found = 1;
			last;
		}
	}

	if ( !$found ) {
		my $transaction = AccessLogModel::Transaction->new;
		$transaction->startTransaction($request);
		push @{ $self->transactions }, $transaction;
	}
}

sub addTransaction {
	my ( $self, $transaction ) = @_;
	push @{ $self->transactions }, $transaction;
}

sub printTransactions {
	my ( $self, $transactionsOutput ) = @_;

	say "\n\n Imprimindo transacoes";
	foreach my $t ( @{ $self->transactions } ) {
		$t->write($transactionsOutput);
	}
	close($transactionsOutput);
}

__PACKAGE__->meta->make_immutable;
1;