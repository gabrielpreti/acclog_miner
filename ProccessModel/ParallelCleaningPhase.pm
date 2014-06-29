package ProccessModel::ParallelCleaningPhase;

use v5.14;
use warnings;
use strict;

use AccessLogModel::Request;

use Try::Tiny;
use Moose;
use MCE;
use namespace::autoclean;

extends 'ProccessModel::MiningPhase';

has 'inputFilePath'   => ( is => 'rw', required => 1 );
has 'cleanedFilePath' => ( is => 'rw', required => 1 );

my $cleanedFile;
my %output;
my $chunkToPrint = 1;

sub execute() {
	my $self = shift;

	open $cleanedFile, ">", $self->cleanedFilePath or die $!;
	my $mce = MCE->new(
		chunk_size  => 200,
		max_workers => 10,
		input_data  => $self->inputFilePath,
		use_slurpio => 0,
		user_func   => \&cleanChunck,
		on_post_run => \&postRun,
		gather      => \%output
	);
	$mce->run();
	close($cleanedFile);

}

sub cleanChunck {
	my ( $mce, $chunk_ref, $chunk_id ) = @_;

	my @workerOutput = ();
	my $lineCounter  = 0;

	for my $line ( @{$chunk_ref} ) {
		my $request = AccessLogModel::Request->new;

		try {
			no warnings 'exiting';

			$lineCounter += 1;

			if(!$request->readFromAccessLog($line)) {
				warn "Could not parse line $line $!";
				next;
			}

			if (   ( $request->uri =~ m/\/stc.*/ )
				|| ( $request->uri =~ m/.*ws.acesso.intranet\/cryptologin.*/ )
				|| ( $request->uri =~ m/.*\.(jpg|gif|png)/ )
				|| ( $request->uri =~ m/.*hc\.html/ )
				|| ( $request->uri =~ m/.*server-status*/ )
				|| ( $request->uri =~ m/.*favicon\.ico/ )
				|| ( $request->uri =~ m/.*robots.txt/ )
				|| ( $request->uri =~ m/.*checkout\/metrics\/(info|save)\.jhtml/ )
				|| ( $request->uri =~ m/.*\;.*/ ) )
			{
				next;
			}

			if ( $request->returnCode() =~ m/30\d/ ) {
				next;
			}

			if ( ( $request->uri =~ m/(.*?)\?.*/ ) ) {
				$request->uri($1);
			}

			if ( ( $request->uri =~ m/ws.pagseguro.uol.com.br\/v2\/transactions\/.*/ ) ) {
				$request->uri('ws.pagseguro.uol.com.br/v2/transactions/');
			}
			
			if ( $request->referrer =~ m/(?<ref>http(s?)\:\/\/.*?)\?.*/ ) {
				$request->referrer($+{ref});
			}

			push @workerOutput, $request->generateCsvLine();

		  }
		  catch {
			warn "Could not parse line $line $!";
			next;
		  };
	}
	MCE->gather( $chunk_id, \@workerOutput );
}

sub postRun {
	foreach my $currentChunk ( sort( { $a <=> $b } keys %output ) ) {
		my @lines = @{ $output{$currentChunk} };
		for my $line (@lines) {
			print $cleanedFile $line;
		}
	}
}

__PACKAGE__->meta->make_immutable;
1;
