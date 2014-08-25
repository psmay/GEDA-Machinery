

# Please refer to the copyright notice at the end of this file.

package GEDA::Machinery::PCB::Notes;

use warnings;
use strict;
use Carp;
use 5.010;

use base 'GEDA::Machinery::Notes';

sub _parse_notes {
	my $self = shift;
	my $fh = shift;

	my @notes = ();

	# Scan initial comments for metadata
	while(<$fh>) {
		next if /^\s*$/;
		last if not /^#/;
		if(/^#\s*(.*?)\s*:\s*(.*?)\s*$/) {
			push @notes, { name => $1, value => $2 };
		}
	}
	# Scan for attributes
	while(<$fh>) {
		if(/\bAttribute\(\s*"(.*?)"\s+"(.*?)"\s*\)/) {
			push @notes, { name => $1, value => $2 };
		}
	}

	return @notes;
}


##
1;
##

__END__

=head1 NAME

GEDA::Machinery::PCB::Notes - extract notes and attributes from a PCB footprint file

=head1 AUTHOR

Peter S. May, L<http://psmay.com/>

Based on footprint.cgi by DJ Delorie.

=head1 COPYRIGHT

GEDA::Machinery::PCB::Notes, notes extraction for PCB footprint files

Copyright (C) 2008-2014 DJ Delorie, Peter S. May

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see L<http://www.gnu.org/licenses/>.

=cut

