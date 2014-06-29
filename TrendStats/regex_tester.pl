use v5.14;
use warnings;
use strict;


#use ProccessModel::ObjectStatsHandler;
#use Time::Piece;
#my @periods = ('201405300200', '201405300300', '201405300400', '201405300500', '201405300600', '201405300700', '201405300800', '201405300900', '201405301000', '201405301100', '201405301200', '201405301300', '201405301400');
#my $handler = ProccessModel::ObjectStatsHandler->new();
#$handler->timeWindowSize(60);
#$handler->analysisInitialTime('30/05/2014 13:00');
#$handler->analysisFinalTime('30/05/2014 13:00');
#say $handler->identifyPeriodsToAnalyse(\@periods);

use Statistics::Descriptive;
my $stat = Statistics::Descriptive::Full->new();
$stat->add_data((0.0374155290355137, 0.00400919639580879, 0.0241573901013052, 0.03014380541630));
say $stat->mean();