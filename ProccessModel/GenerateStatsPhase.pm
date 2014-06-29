package ProccessModel::GenerateStatsPhase;

use v5.14;
use warnings;
use strict;

use Moose;
#use namespace::autoclean;

use AccessLogModel::Request;
use ProccessModel::ObjectStatsHandler;
use PDL;
use PDL::NiceSlice;
use Time::Piece;
use Time::HiRes;
use Parallel::ForkManager;
use Statistics::Descriptive;

extends 'ProccessModel::MiningPhase';

has 'inputFilePath' => ( is => 'rw', required => 1 );
has 'outputDir'     => ( is => 'rw', required => 1 );
has 'objectHandler' => ( is => 'rw', required => 1, isa => 'ProccessModel::ObjectStatsHandler' );
has 'outlierFilter' => ( is => 'rw', required => 1, isa => 'TrendStats::TrendFilter' );
has 'numProcessors' => ( is => 'rw', required => 0, isa => 'Int', default => 1 );

sub parseAccessLog {
	my ( $self, $attr ) = @_;

	my @periods;                    #todos os períodos de tempo identificados.
	my %attributeOccurrences;       #um hash de hashes, onde as chaves são os atributos sendo analisados, e os valores são hashes cujas chaves são os intervalos de tempo e os valores a quantidade de ocorrências naquele tempo.
	my %attributeTimes;             #um hash de hashes, onde as chaves são os atributos sendo analisados, e os valores são hashes cujas chaves são os intervalos de tempo e os valores uma lista dos tempos das requisições do atributo naquele período.
	my %attributeTotalTimeSpent;    #um hash de hashes, onde as chaves são os atributos sendo analisados, e os valores são hashes cujas chaves são os intervalos de tempo e os valores o tempo total das requisições daquele atributo.
	my %attributeTotalPercTime;     #um hash de hashes, onde as chaves são os atributos sendo analisados, e os valores são hashes cujas chaves são os intervalos de tempo e os valores o percentual do tempo total gasto no atributo atual.
	my @candidates;                 #candidatos a outliers (o critério básico é ter pelo menos uma ocorrência por minuto)

	my %totalTimePerPeriod;

	my $inputCsv = Text::CSV->new( { sep_char => $AccessLogModel::Request::csvSep, quote_char => undef, allow_whitespace => 0, binary => 1, eol => $/ } );
	open my $inputFile, "<", $self->inputFilePath() or die $!;

	while ( my $line = $inputCsv->getline($inputFile) ) {
		my $request = AccessLogModel::Request->new;
		$request->readFromCsv($line);

		#identifica o período, atualiza a lista de períodos e, se necessário, inicializa o tempo gasto no período.
		my $period = $self->objectHandler->getTimeWindowIntervalFromRequest($request);
		push( @periods, $period );
		if ( !exists( $totalTimePerPeriod{$period} ) ) {
			$totalTimePerPeriod{$period} = 0;
		}

		my $value = $self->objectHandler->getAttributeValueFromObject( $request, $attr );

		#Se foi a primeira ocorrência do hash, cria uma entrada pra ele com um hash de tempo vazio.
		if ( !exists( $attributeOccurrences{$value} ) ) {
			$attributeOccurrences{$value}    = {};
			$attributeTimes{$value}          = {};
			$attributeTotalTimeSpent{$value} = {};
		}

		#Verifica se o valor do atributo sendo analisado já ocorreu naquele período.
		if ( !exists( $attributeOccurrences{$value}{$period} ) ) {
			$attributeOccurrences{$value}{$period}    = 0;
			$attributeTimes{$value}{$period}          = [];
			$attributeTotalTimeSpent{$value}{$period} = 0;
		}

		#insere o atributo nos hashes de contagem de ocorrência e de análise de tempo
		$attributeOccurrences{$value}{$period} += 1;
		push( @{ $attributeTimes{$value}{$period} }, $request->time() );
		$attributeTotalTimeSpent{$value}{$period} += $request->time();

		#atualiza o tempo total gasto no período
		$totalTimePerPeriod{$period} += $request->time();

		#Para ser um candidato a outlier, deve ter pelo menos uma ocorrência por minuto.
		if ( List::Util::max( values %{ $attributeOccurrences{$value} } ) >= $self->objectHandler->timeWindowSize ) {
			push @candidates, $value;
		}
	}

	@candidates = List::MoreUtils::uniq(@candidates);
	@periods    = sort( List::MoreUtils::uniq(@periods) );

	# Calcula a média dos tempos para a análise de tempo por requisição e o percentual de tempo gasto por período.
	foreach my $candidate (@candidates) {

		#Tempo médio
		foreach my $period ( keys $attributeTimes{$candidate} ) {
			my $stat = Statistics::Descriptive::Full->new();
			$stat->add_data( @{ $attributeTimes{$candidate}{$period} } );
			$attributeTimes{$candidate}{$period} = $stat->mean();
		}

		#Percentual do tempo
		$attributeTotalPercTime{$candidate} = {};
		foreach my $period ( keys $attributeTotalTimeSpent{$candidate} ) {
			$attributeTotalPercTime{$candidate}{$period} = 100 * $attributeTotalTimeSpent{$candidate}{$period} / ($totalTimePerPeriod{$period});
		}

	}

	return ( \@periods, \@candidates, \%attributeOccurrences, \%attributeTimes, \%attributeTotalTimeSpent, \%attributeTotalPercTime );
}

sub createPiddle {
	my $self         = shift;
	my $attr         = shift;
	my @periods      = @{ shift() };
	my @candidates   = @{ shift() };
	my %originalData = %{ shift() };

	my %piddleMapping;    #o mapeamento para os dois piddles (de ocorrências e de tempo) é o mesmo.
	my $dataQty   = keys %originalData;
	my $timeQty   = @periods;
	my $piddle    = zeroes( $dataQty, $timeQty + 1 );    #a primeira linha do piddle é utilizado para fazer o de-para através do %piddleMapping
	my $dataIndex = 0;
	foreach my $candidate (@candidates) {
		$piddleMapping{$dataIndex} = $candidate;
		$piddle ( $dataIndex, 0 ) .= $dataIndex;

		my $timeIndex = 1;
		foreach my $p (@periods) {
			if ( defined( $originalData{$candidate}{$p} ) ) {
				$piddle ( $dataIndex, $timeIndex ) .= $originalData{$candidate}{$p};
			}                                            # else, do nothing (já está com 0 por default)                                                                # else, do nothing (já está com 0 por default)

			$timeIndex += 1;
		}
		$dataIndex += 1;
	}

	return ( \%piddleMapping, $piddle );
}

sub printOutliers {
	my $self               = shift;
	my $fileName           = shift;
	my %outliers           = %{ shift() };
	my %data               = %{ shift() };
	my %piddleMapping      = %{ shift() };
	my @periods            = @{ shift() };
	my $formattingFunction = shift;

	my $request = AccessLogModel::Request->new();

	say "Generating output to file $fileName";
	open my $outputFile, ">", $fileName or die $!;

	#	Gera o cabeçalho do arquivo
	print $outputFile "Data" . $AccessLogModel::Request::csvSep;
	foreach my $p (@periods) {
		print $outputFile $p . $AccessLogModel::Request::csvSep;
	}
	print $outputFile "\n";

	#Imprime os dados
	foreach my $k ( sort { $outliers{$b} <=> $outliers{$a} } keys %outliers ) {
		print $outputFile $piddleMapping{$k} . $AccessLogModel::Request::csvSep;
		foreach my $p (@periods) {
			my $valueToPrint = &$formattingFunction( defined( $data{ $piddleMapping{$k} }{$p} ) ? $data{ $piddleMapping{$k} }{$p} : 0 );
			print $outputFile $valueToPrint . $AccessLogModel::Request::csvSep;
		}
		print $outputFile "\n";
	}
	close($outputFile);
}

sub execute() {
	my $self = shift;

	my $pm = new Parallel::ForkManager( $self->numProcessors );

	foreach my $attr ( @{ $self->objectHandler->attributes } ) {

		$pm->start and next;    # do the fork

		say "Parsing access log for attribute $attr ...";
		my $t0 = [ Time::HiRes::gettimeofday() ];
		my ( $periods, $candidates, $attributeOccurrences, $attributeMeanTimes, $attributeTotalTimeSpent, $attributeTotalPercTime ) = parseAccessLog( $self, $attr );
		say "Access log for attribute $attr parsed in " . Time::HiRes::tv_interval($t0) . "s";

		say "Creating piddle for attribute $attr ...";
		$t0 = [ Time::HiRes::gettimeofday() ];
		my ( $occurrencePiddleMapping,     $occurrenceCounterPiddle ) = createPiddle( $self, $attr, $periods, $candidates, $attributeOccurrences );
		my ( $meanTimesPiddleMapping,      $meanTimesPiddle )         = createPiddle( $self, $attr, $periods, $candidates, $attributeMeanTimes );
		my ( $totalTimeSpentPiddleMapping, $totalTimeSpentPiddle )    = createPiddle( $self, $attr, $periods, $candidates, $attributeTotalTimeSpent );
		my ( $totalPercTimePiddleMapping,  $totalPercTimePiddle )     = createPiddle( $self, $attr, $periods, $candidates, $attributeTotalPercTime );
		say "Piddle for attribute $attr created in " . Time::HiRes::tv_interval($t0) . "s";

		say "Filtering outliers for attribute $attr ...";
		$t0 = [ Time::HiRes::gettimeofday() ];
		my %occurrenceCounterOutliers = $self->outlierFilter->filter( $occurrenceCounterPiddle, $self->objectHandler->identifyPeriodsToAnalyse($periods));
		my %meanTimesOutliers         = $self->outlierFilter->filter( $meanTimesPiddle,         $self->objectHandler->identifyPeriodsToAnalyse($periods));
		my %totalTimeSpentOutliers    = $self->outlierFilter->filter( $totalTimeSpentPiddle,    $self->objectHandler->identifyPeriodsToAnalyse($periods));
		my %totalPercTimeOutliers     = $self->outlierFilter->filter( $totalPercTimePiddle,     $self->objectHandler->identifyPeriodsToAnalyse($periods));
		say "Outliers for attribute $attr filtered in " . Time::HiRes::tv_interval($t0) . "s";

		say "Printing outliers for attribute $attr ... ";
		my $fileName = $self->outputDir() . "/outliers_count_" . $attr . ".csv";
		printOutliers( $self, $fileName, \%occurrenceCounterOutliers, $attributeOccurrences, $occurrencePiddleMapping, $periods, sub { return $_[0]; } );
		$fileName = $self->outputDir() . "/outliers_meantime_" . $attr . ".csv";
		printOutliers( $self, $fileName, \%meanTimesOutliers, $attributeMeanTimes, $meanTimesPiddleMapping, $periods, sub { return $_[0] / 1000000; } );
		$fileName = $self->outputDir() . "/outliers_totaltimespent_" . $attr . ".csv";
		printOutliers( $self, $fileName, \%totalTimeSpentOutliers, $attributeTotalTimeSpent, $totalTimeSpentPiddleMapping, $periods, sub { return $_[0] / 1000000; } );
		$fileName = $self->outputDir() . "/outliers_totalperctime_" . $attr . ".csv";
		printOutliers( $self, $fileName, \%totalPercTimeOutliers, $attributeTotalPercTime, $totalPercTimePiddleMapping, $periods, sub { return $_[0]; } );
		say "Done with attribute $attr.";

		$pm->finish;    # do the exit in the child process
	}

	$pm->wait_all_children;
}

__PACKAGE__->meta->make_immutable;
1;
