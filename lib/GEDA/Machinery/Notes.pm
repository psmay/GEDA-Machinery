

# Please refer to the copyright notice at the end of this file.

package GEDA::Machinery::Notes;

use warnings;
use strict;
use Carp;
use 5.010;


sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = bless {}, $class;
	$self->_initialize(@_);
	return $self;
}

sub _initialize {
	my $self = shift;
	# nothing
}


sub scan {
	my $self = shift;
	my $fh = shift;
	my @initial = $self->_parse_notes($fh);
	use Data::Dumper; print Dumper \@initial;
	my @output = $self->_add_content_information_to_notes(@initial);
	return @output;
}

sub is_important_name {
	my $self = shift;
	my $name = shift;
	return $name =~ /(?:author|email|license|description|documentation)$/;
}

sub _parse_notes {
	my $self = shift;
	my $fh = shift;
	# nothing
}

sub _add_content_information_to_notes {
	my $self = shift;
	for(@_) {
		my $name = $_->{name};
		my $value = $_->{value};
		if($name =~ /email$/) {
			$_->{type} = 'email';
		}
		if($name =~ /licen[cs]e$/) {
			$_->{type} = 'license';
		}
		if($value =~ m|^((?i:https?://)\S+)$|) {
			$_->{type} = 'url';
		}
	}
	return @_;
}

##
1;
##

__END__

=head1 NAME

GEDA::Machinery::Notes - extract notes/attributes/annotations from file

=head1 AUTHOR

Peter S. May, L<http://psmay.com/>

Based on footprint.cgi and symbol.cgi by DJ Delorie.

=head1 COPYRIGHT

GEDA::Machinery::Notes, notes extraction for gEDA files

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


