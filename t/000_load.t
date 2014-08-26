
use warnings;
use strict;
use Carp;
use 5.010;

my @modules;

BEGIN {
	# For this list, consider the results of:
	#	(cd ../lib && find . -name '*.pm') |
	#	perl -p -E 's!/!::!g; s/^\.:://; s/\.pm$//g; s/^/\t\t/' |
	#	sort
	@modules = qw/
		GEDA::Machinery
		GEDA::Machinery::Gschem::Notes
		GEDA::Machinery::Notes
		GEDA::Machinery::PCB::Footprint
		GEDA::Machinery::PCB::Footprint::Dilpad
		GEDA::Machinery::PCB::Footprint::Twopad
		GEDA::Machinery::PCB::Notes
		GEDA::Machinery::PCB::Panelizer
		GEDA::Machinery::Run
		GEDA::Machinery::Temp
		/;
}

use Test::More tests => @modules + 0;

BEGIN {
	use_ok($_) for @modules;
}
