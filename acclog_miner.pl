use v5.14;
use warnings;
use strict;

use PadWalker;
use Beam::Wire;

#my $phase1 = ProccessModel::InitialPhase->new();
#$phase1->execute();
#
#my $phase2 = ProccessModel::SecondPhase->new($phase1->context);
#$phase2->execute();

my $wire = Beam::Wire->new(file => 'context.yml');
my $phasesContainer = $wire->get('phaseContainer');
$phasesContainer->execute();
