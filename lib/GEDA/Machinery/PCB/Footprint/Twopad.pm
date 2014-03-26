
# Please refer to the copyright notice at the end of this file.

package GEDA::Machinery::PCB::Footprint::Twopad;

use warnings;
use strict;
use Carp;
use 5.010;

use base 'GEDA::Machinery::PCB::Footprint';


sub _get_magnitude_variable_names {
	return qw/c cl cw g m pl plc ple pt pw pwe so soc sw/;
}

sub _fp(@) {
	my $mag = shift;
	GEDA::Machinery::PCB::Footprint::_fill_in_ratio($mag, @_);
}

sub _fc(&@) {
	my $fn = shift;
	my $mag = shift;
	GEDA::Machinery::PCB::Footprint::_fill_in_calculation($mag, $fn, @_);
}

sub _fill_in_missing_magnitudes {
	my $self = shift;
	my $mag = shift;

	FILL_IN_BLANKS: {
		my $again = 0;

		$again |= _fp $mag, 'g', 'cl';
		$again |= _fp $mag, 'pwe', 'cw';
		$again |= _fp $mag, 'ple', 'cl';

		$again |= _fc { my ($pl, $ple) = @_; $pl - 2 * $ple } $mag, qw/cl pl ple/;
		$again |= _fc { my ($pl, $pt) = @_; $pl - 2 * $pt } $mag, qw/g pl pt/;
		$again |= _fc { my ($plc, $pt) = @_; $plc - $pt } $mag, qw/g plc pt/;
		$again |= _fc { my ($plc, $pt) = @_; $plc + $pt } $mag, qw/pl plc pt/;
		$again |= _fc { my ($g, $pt) = @_; $g + 2 * $pt } $mag, qw/pl g pt/;
		$again |= _fc { my ($plc, $pt) = @_; $plc + $pt } $mag, qw/pl plc pt/;
		$again |= _fc { my ($cl, $ple) = @_; $cl + 2 * $ple } $mag, qw/pl cl ple/;
		$again |= _fc { my ($pl, $plc) = @_; ($pl - $plc)/2 } $mag, qw/ple pl plc/;
		$again |= _fc { my ($soc, $sw) = @_; $soc - $sw/2 } $mag, qw/so soc sw/;

		$again |= _fc { my ($pw, $pwe) = @_; $pw - 2 * $pwe } $mag, qw/cw pw pwe/;
		$again |= _fc { my ($pw, $cw) = @_; ($pw - $cw)/2 } $mag, qw/pwe pw cw/;
		$again |= _fc { my ($cw, $pwe) = @_; $cw + 2 * $pwe } $mag, qw/pw cw pwe/;

		$again |= _fc { my ($pl, $pt) = @_; $pl - $pt } $mag, qw/plc pl pt/;
		$again |= _fc { my ($g, $pt) = @_; $g + $pt } $mag, qw/plc g pt/;
		$again |= _fc { my ($cl, $pe, $pt) = @_; $cl + 2 * $pe - $pt } $mag, qw/plc cl pe pt/;
		$again |= _fc { my ($pl, $g) = @_; ($pl - $g)/2 } $mag, qw/pt pl g/;
		$again |= _fc { my ($plc, $g) = @_; $plc - $g } $mag, qw/pt plc g/;
		$again |= _fc { my ($cl, $ple, $g) = @_; ($cl + $ple*2 - $g)/2 } $mag, qw/pt cl ple g/;

		$again |= _fc { my ($so, $sw) = @_; $so + $sw/2 } $mag, qw/soc so sw/;
		$again |= _fc { my ($soc, $so) = @_; ($soc - $so)*2 } $mag, qw/sw soc so/;

		redo FILL_IN_BLANKS if $again;
	}

	_fp $mag, 'c'. 'g';
	_fp $mag, 'm', 'g';
}

sub _fill_in_additional_parameters {
	my $self = shift;
	my $mag = shift;
	my $in = shift;

	my $pol = $in->{pol};

	my %pinnames = ();
	my %pinnumbers = ();
	for(1 .. 2) {
		$pinnames{$_} = $in->{"name$_"} // $_;
		$pinnumbers{$_} = $in->{$_} // $_;
	}

	my $description = $in->{description} // "";
	my $refdes = $in->{refdes} // "X?";
	my $id = $in->{id} // "";

	my $mv = $mag->{V};

	my $px = $mv->{plc} / 2;
	my $dx = 0;
	my $dy = 0;
	my $pt;

	if($mv->{pt} > $mv->{pw}) {
		$dx = ($mv->{pt} - $mv->{pw}) / 2;
		$pt = $mv->{pw};
	} else {
		$dy = ($mv->{pw} - $mv->{pt}) / 2;
		$pt = $mv->{pt};
	}

	my $l = $mv->{pl}/2;
	my $w = $mv->{pw}/2;
	my $s = $mv->{soc};
	my $t = $mv->{sw};

	$self->{generation_parameters} = {
		description => $description,
		refdes => $refdes,
		id => $id,
		pinnames => \%pinnames,
		pinnumbers => \%pinnumbers,
		pol => $pol,
		px => $px,
		dx => $dx,
		dy => $dy,
		pt => $pt,
		l => $l,
		w => $w,
		t => $t,
		s => $s,
	};

	for(qw/c cl cw m/) {
		$self->{generation_parameters}{$_} = $mv->{$_};
	}
}

sub _element {
	my $self = shift;
	my %q = @_;

	my @output = ();

	my $c = $q{c};
	my $dx = $q{dx};
	my $dy = $q{dy};
	my $l = $q{l};
	my $m = $q{m};
	my $pt = $q{pt};
	my $px = $q{px};
	my $s = $q{s};
	my $t = $q{t};
	my $w = $q{w};

	push @output, $self->_element_head("", $q{description}, $q{refdes}, $q{id}, 0, 0, 0, 0, 0, 100, "");

	push @output, $self->_pad(-$px+$dx, $dy, -$px-$dx, -$dy, $pt, $c*2, $m*2 + $pt, $q{pinnames}{1}, $q{pinnumbers}{1}, "square");
	push @output, $self->_pad($px+$dx, $dy, $px-$dx, -$dy, $pt, $c*2, $m*2 + $pt, $q{pinnames}{2}, $q{pinnumbers}{2}, "square");

	if ($q{pol}) {
		push @output, $self->_box($q{cl}, $q{cw}, 1);
	}

	# Actual box
	my $xr = $l;
	my $xl = -$xr;
	my $yb = $w;
	my $yt = -$yb;
	# Box extended by silk clearance
	my $ybr = $yb + $s;
	my $xrr = $xr + $s;
	my $ytr = -$ybr;
	my $xlr = -$xrr;

	push @output, $self->_box_round_corners($xlr, $ytr, $xrr, $ybr, $s, 0, 0, $s, $t);

	push @output, $self->_element_tail();

	return join('', @output);
}


##
1;
##

__END__

=head1 NAME

GEDA::Machinery::PCB::Footprint::Twopad - a footprint generator for surface-mount DIL parts in gEDA pcb

=head1 SYNOPSIS

	use GEDA::Machinery::PCB::Footprint::Twopad;
	
	my $gen = new GEDA::Machinery::PCB::Footprint::Twopad (
		key1 => value1,
		...
		keyN => valueN
	);
	# Optionally, supply filehandle to any of these.
	# If omitted, the currently selected handle is used.
	$gen->write_footprint_to_handle($fp_fh);
	$gen->write_eps_to_handle($eps_fh); # binmode handle first
	$gen->write_png_to_handle($png_fh); # binmode handle first

	# Example
	my $gen = new GEDA::Machinery::PCB::Footprint::Twopad (
		id => 'TWOPIN_EXAMPLE',
		description => 'Example two-pin device',
		units => 'mm',
		c => 0.127,
		m => 0.3,
		plc => 1.9,
		pt => 0.3,
		pw => 1.6,
		so => 0.2,
		sw => 0.2,
	);

=head1 METHODS

=over 4

=item $gen = GEDA::Machinery::PCB::Footprint::Twopad->new(I<%parameters>)

Creates a new generator object using the given parameters (see L<"PARAMETERS">);

=item $gen->write_footprint_to_handle([I<handle>])

Generates the element and writes it out to the given handle. If no handle is
given, the currently selected handle (by default, C<STDOUT>) is used.

=item $gen->write_eps_to_handle([I<handle>])

Generates the element, converts it to a vector graphic in EPS format, and
writes the result out to the given handle. If no handle is given, the currently
selected handle (by default, C<STDOUT>) is used.

Call C<binmode> on the destination handle before writing.

This conversion requires the program C<pcb> to be installed and in the path to
perform the conversion to a vector graphic.

=item $gen->write_png_to_handle([I<handle>])

Generates the element, converts it to a raster graphic in PNG format, and
writes the result out to the given handle. If no handle is given, the currently
selected handle (by default, C<STDOUT>) is used.

Call C<binmode> on the destination handle before writing.

This conversion requires the program C<pcb> to be installed and in the path to
perform the conversion to a vector graphic, and also requires Image::Magick to
convert the vector graphic to PNG.

The scale of the PNG is set to approximate the size produced by the original
dilpad.cgi script, which isn't necessarily useful. For more flexibility,
generate the EPS instead and then run your own conversions.

=back

=head1 PARAMETERS

Note that parameter names are case-sensitive.

=head2 Dimensions

Dimensions are given as numbers optionally followed by a unit C<mm>, C<mil>, or
(where applicable) C<%> or C<x>. If no unit is given, the default unit (set by
the C<units> parameter). Unitless values can be supplied as a number (e.g.
C<2.13>) or a string (e.g. C<'2.13'>), but a value with a unit must be a string
with the unit after the number (e.g. C<'2.13mm'>).

Some parameters can be supplied as a percentage (C<%>) or ratio (C<x>) of some
other value; these are indicated below as C<can be % of>. For example, if
C<ple> is defined as C<213%> (or, equivalently, C<2.13x>), its value will be
defined as 2.13 times the defined value for C<cl>.

In the following descriptions,

=over 4

=item *

An B<end> of a pad is a side that is facing toward or away from the other pad.
An end of a component is a side of the component that is parallel with the ends
of its pads.

=item *

An B<edge> of a pad is a side either of the two sides that is equidistant from
the other pad; it is a side of the pad that is not an end. An edge of a
componen is a side of the component that is parallel with the edges of its
pads.

=item *

The B<physical bound> is the smallest rectangle containing (the body and) all
pads.

=back

	c = clearance (between copper and polygon fill, can be % of g)
	cl = component length (end to end)
	cw = component width (edge to edge)
	g = gap (between facing ends of pads)
	m = mask (between copper and mask, can be % of g)
	pl = pad length (between outer ends of pads)
	plc = pad length, center-to-center (between centers of pads)
	ple = pad length extension (between end of component and
		matching end of pad, can be % of cl)
	pt = pad thickness (between ends of single pad)
	pw = pad width (between edges of single pad)
	pwe = pad width extension (between edge of component and
		matching edge of pad, can be % of cw)
	so = silk offset (between physical bound and near edge of silk line)
	soc = silk offset to center (between physical bound and
		center of silk line)
	sw = silk width (thickness of silk line)

=head2 Pin names and numbers

The B<name> of a pin is simply arbitrary descriptive text.

The B<number> of a pin is the index by which nets are connected (corresponding
to the C<pinnumber> attribute in the schematic). Despite the name, this can be
alphanumeric.

Neither name nor number need be unique. Pads that are internally connected
might be given the same number in order to simplify the schematic symbol.

	1 = number for pin 1 (default 1)
	name1 = name for pin 1 (default 1)
	2 = number for pin 2 (default 2)
	name2 = name for pin 2 (default 2)

=head2 Other

	id = the value parameter for the element
	description = the description parameter for the element
	
	pol = draw physical outline (tested as boolean)

Keys not used in constructing elements are ignored; in the example script, they
are included in the output as comments, allowing additional text to be injected
into the file. At least the following keys are reserved to only have this
understood meaning:

	dimensions-based-on
	url
	author
	copyright
	license

=head1 AUTHOR

Peter S. May, L<http://psmay.com/>

Based, by way of substantial refactoring, on 2pad.cgi by DJ Delorie.

=head1 COPYRIGHT

GEDA::Machinery::PCB::Footprint::Twopad, a footprint generator for 2-pin surface-mount parts in gEDA pcb

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
