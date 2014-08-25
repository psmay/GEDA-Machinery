

# Please refer to the copyright notice at the end of this file.

package GEDA::Machinery::Gschem::Notes;

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
		if(/^T\s+.*\s+(\d+)/) {
			my $ntext = $1;
			for my $tn (1 .. $ntext) {
				local $_ = <$fh>;
				next if not /^(\S+?)=(.*)$/;
				my $name = $1;
				my $value = $2;
				if($name =~ /(?:author|email|license|description|documentation)$/) {
					push @notes, { name => $name, value => $value };
				}
			}
		}
	}

	return @notes;
}


##
1;
##

__END__

=head1 NAME

GEDA::Machinery::Gschem::Notes - extract notes and attributes from a Gschem symbol file

=head1 AUTHOR

Peter S. May, L<http://psmay.com/>

Based on symbol.cgi by DJ Delorie.

=head1 COPYRIGHT

GEDA::Machinery::Gschem::Notes, notes extraction for Gschem symbol files

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

