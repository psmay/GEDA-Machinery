
# Please refer to the copyright notice at the end of this file.

package GEDA::Machinery::PCB::Footprint::Dilpad;

use warnings;
use strict;
use Carp;
use 5.010;

use List::Util qw/first min max/;

use base 'GEDA::Machinery::PCB::Footprint::Generator';


sub _get_magnitude_variable_names {
	return (qw/bl bw c cw e g ll lw m pg pl plc ple pw pwe pxl so soc sw/);
}

sub _firstz {
	# Returns first true argument, or 0.
	return +(first { $_ } @_) or 0;
}

sub _fp(@) {
	my $mag = shift;
	GEDA::Machinery::PCB::Footprint::Generator::_fill_in_ratio($mag, @_);
}

sub _fc(&@) {
	my $fn = shift;
	my $mag = shift;
	GEDA::Machinery::PCB::Footprint::Generator::_fill_in_calculation($mag, $fn, @_);
}

sub _fill_in_missing_magnitudes {
	my $self = shift;
	my $mag = shift;

	FILL_IN_BLANKS: {
		my $again = 0;

		$again |= _fp $mag, 'g', 'bw';
		$again |= _fp $mag, 'pwe', 'lw';
		$again |= _fp $mag, 'ple', 'll';

		$again |= _fc { my ($bw, $ll) = @_; $bw + 2 + $ll } $mag, qw/cw bw ll/;
		$again |= _fc { my ($bw, $ll) = @_; $bw + 2 * $ll } $mag, qw/cw bw ll/;
		$again |= _fc { my ($pxl, $ll) = @_; $pxl - 2 * $ll } $mag, qw/cw pxl ll/;
		$again |= _fc { my ($pxl, $pl) = @_; $pxl - 2 * $pl } $mag, qw/g pxl pl/;
		$again |= _fc { my ($plc, $pl) = @_; $plc - $pl } $mag, qw/g plc pl/;
		$again |= _fc { my ($plc, $pl) = @_; $plc + $pl } $mag, qw/pxl plc pl/;
		$again |= _fc { my ($g, $pl) = @_; $g + 2 * $pl } $mag, qw/pxl g pl/;
		$again |= _fc { my ($plc, $pl) = @_; $plc + $pl } $mag, qw/pxl plc pl/;
		$again |= _fc { my ($cw, $ple) = @_; $cw + 2 * $ple } $mag, qw/pxl cw ple/;
		$again |= _fc { my ($pxl, $cw) = @_; ($pxl - $cw)/2 } $mag, qw/ple pxl cw/;

		$again |= _fc { my ($pw, $pwe) = @_; $pw - 2 * $pwe } $mag, qw/lw pw pwe/;
		$again |= _fc { my ($pw, $lw) = @_; ($pw - $lw)/2 } $mag, qw/pwe pw lw/;
		$again |= _fc { my ($lw, $pwe) = @_; $lw + 2 * $pwe } $mag, qw/pw lw pwe/;
		$again |= _fc { my ($e, $pg) = @_; $e - $pg } $mag, qw/pw e pg/;
		$again |= _fc { my ($e, $pw) = @_; $e - $pw } $mag, qw/pg e pw/;
		$again |= _fc { my ($pw, $pg) = @_; $pw + $pg } $mag, qw/e pw pg/;

		$again |= _fc { my ($pxl, $pl) = @_; $pxl - $pl } $mag, qw/plc pxl pl/;
		$again |= _fc { my ($g, $pl) = @_; $g + $pl } $mag, qw/plc g pl/;
		$again |= _fc { my ($cw, $ple, $pl) = @_; $cw + 2 * $ple - $pl } $mag, qw/plc cw ple pl/;
		$again |= _fc { my ($pxl, $g) = @_; ($pxl - $g)/2 } $mag, qw/pl pxl g/;
		$again |= _fc { my ($plc, $g) = @_; $plc - $g } $mag, qw/pl plc g/;
		$again |= _fc { my ($cl, $ple, $g) = @_; ($cl + $ple*2 - $g)/2 } $mag, qw/pl cl ple g/;

		$again |= _fc { my ($soc, $sw) = @_; $soc - $sw/2 } $mag, qw/so soc sw/;
		$again |= _fc { my ($so, $sw) = @_; $so + $sw/2 } $mag, qw/soc so sw/;
		$again |= _fc { my ($soc, $so) = @_; ($soc - $so)*2 } $mag, qw/sw soc so/;

		redo FILL_IN_BLANKS if $again;
	}

	_fp $mag, 'c', 'pg';
	_fp $mag, 'm', 'pg';
}

sub _fill_in_additional_parameters {
	my $self = shift;
	my $mag = shift;
	my $in = shift;

	# variables based on $in
	my $seq = $in->{seq};
	my $pol = $in->{pol};

	my $np = $in->{np};
	croak "Number of pins (np) is not defined" unless defined $np;
	my $np2 = $np/2;

	my %pinnames = ();
	my %pinnumbers = ();
	for(1 .. $np) {
		$pinnames{$_} = $in->{"name$_"} // $_;
		$pinnumbers{$_} = $in->{$_} // $_;
	}

	my $description = $in->{description} // "dil-$np";
	my $refdes = $in->{refdes} // "U?";
	my $id = $in->{id};

	# variables based on $mag
	my $mv = $mag->{V};


	my $dx = 0;
	my $dy = 0;
	my $px = $mv->{plc} / 2;
	my $pt;

	if ($mv->{pl} > $mv->{pw}) {
		$dx = ($mv->{pl} - $mv->{pw}) / 2;
		$pt = $mv->{pw};
	} else {
		$dy = ($mv->{pw} - $mv->{pl}) / 2;
		$pt = $mv->{pl};
	}

	my $s = $mv->{soc} * 2;
	my $t = $mv->{sw};
	my $l = max($mv->{bl}, $mv->{e}*($np2-1)+$mv->{pw}+$s)/2;

	# footprint generation parameters
	$self->{generation_parameters} = {
		description => $description,
		refdes => $refdes,
		id => $id,
		pinnames => \%pinnames,
		pinnumbers => \%pinnumbers,
		np2 => $np2,
		np => $np,
		seq => $seq,
		pol => $pol,
		px => $px,
		dx => $dx,
		dy => $dy,
		pt => $pt,
		l => $l,
		t => $t,
		s => $s,
	};

	for(qw/bl bw c cw e g lw m pw pxl soc so sw/) {
		$self->{generation_parameters}{$_} = $mv->{$_};
	}
}

sub _element {
	my $self = shift;
	my %q = @_;

	my @output = ();

	#push @output, get_comments();


	push @output, $self->_element_head("", $q{description}, $q{refdes}, $q{id}, 0, 0, 0, 0, 0, 100, "");

	# $ix and $iy are 0 for the upper left pad.
	my ($ix, $iy);

	my $pad1y = - ($q{np2}-1) * $q{e} / 2;

	for my $pad (1..$q{np}) {
		($ix, $iy) = _seq_pin_location($pad, $q{np2}, $q{seq});

		my $x = $ix ? 1 : -1;
		my $y = $pad1y + $q{e} * $iy;

		my $pinname = $q{pinnames}{$pad};
		my $pinnumber = $q{pinnumbers}{$pad};

		#push @output, $self->_pad_center(
		#	$x, $y, 2*$q{dx}, 2*$q{dy},
		#	$q{c}, $q{m}, $pinname, $pinnumber, "square");
		push @output, $self->_pad($x*($q{px}+$q{dx}), $y+$q{dy}, $x*($q{px}-$q{dx}),
			$y-$q{dy}, $q{pt}, $q{c}*2, $q{m}*2 + $q{pt}, $pinname, $pinnumber, "square");
	}

	if ($q{pol}) {
		push @output, $self->_package_outline(pad1y => $pad1y, %q);
	}

	if ($q{g} < 3 * $q{so} + 2 * $q{sw} || $q{bw} == 0 || $q{bl} == 0) {
		push @output, $self->_with_silk_around_footprint(%q);
	} else {
		push @output, $self->_with_silk_between_pads(%q);
	}

	push @output, $self->_element_tail();

	return join('', @output);
}

sub _seq_pin_location {
	my $pad_number = shift;
	my $pad_count_half = shift;
	my $seq = uc(shift // '');
	if($seq eq '') {
		$seq = "A";
		carp "No seq provided; reverting to $seq";
	}
	if($seq !~ /^[A-F]$/) {
		croak "Unknown sequence type $seq";
	}

	my $pad_count = $pad_count_half * 2;

	my $left = ($pad_number <= $pad_count_half);

	my ($ix, $iy);

	if ($seq =~ /A/i) {
		$ix = $left ? 0 : 1;
		$iy = $left ? $pad_number-1 : $pad_count-$pad_number;
	} elsif ($seq =~ /B/i) {
		$ix = $left ? 0 : 1;
		$iy = $left ? $pad_number-1 : $pad_number-$pad_count_half-1;
	} elsif ($seq =~ /C/i) {
		$ix = ($pad_number-1) % 2;
		$iy = int(($pad_number-1) / 2);
	} elsif ($seq =~ /D/i) {
		$ix = $left ? 1 : 0;
		$iy = $left ? $pad_number-1 : $pad_count-$pad_number;
	} elsif ($seq =~ /E/i) {
		$ix = $left ? 1 : 0;
		$iy = $left ? $pad_number-1 : $pad_number-$pad_count_half-1;
	} elsif ($seq =~ /F/i) {
		$ix = 1 - ($pad_number-1) % 2;
		$iy = int(($pad_number-1) / 2);
	} else {
		croak "Invalid sequence type $seq";
	}

	return ($ix, $iy);
}

sub _package_outline {
	my $self = shift;
	my %q = @_;

	my @output;

	if (defined($q{bw}) && defined($q{bl})) {
		push @output, $self->_box($q{bw}, $q{bl}, 1);
	}

	if (defined($q{cw}) && defined($q{lw}) && defined($q{bw})) {
		for my $p (0 .. $q{np2} - 1) {
			push @output, $self->_box(-$q{cw}/2, $q{pad1y}-$q{lw}/2+$q{p}*$q{e}, -$q{bw}/2, $q{pad1y}+$q{lw}/2+$q{p}*$q{e}, 100);
			push @output, $self->_box($q{cw}/2, $q{pad1y}-$q{lw}/2+$q{p}*$q{e}, $q{bw}/2, $q{pad1y}+$q{lw}/2+$q{p}*$q{e}, 100);
		}
	}

	return join('', @output);
}

sub _with_silk_around_footprint {
	my $self = shift;
	my %q = @_;

	# Not enough space for silk in the middle, put it around the whole
	# footprint.
	my $w = max($q{bw}, $q{cw}+$q{s}, $q{pxl}+$q{s})/2;
	my $r = max($q{soc}, ($q{bl} - ($q{e}*($q{np2}-1)+$q{pw}))/2);
	my $t = $q{t};
	my $l = $q{l};

	return $self->_box_round_corners(
		-$w, -$l, $w, $l, $r, 0, 0, 0, $t);
}

sub _with_silk_between_pads {
	my $self = shift;
	my %q = @_;

	# Enough space to put the silk between the pads.
	my $w1 = _firstz($q{bw}, $q{cw}+$q{s}, $q{pxl}+$q{s})/2;
	my $w2 = min($q{bw}/2, $q{g}/2-$q{soc});

	my $r;
	$r = $q{g}/6;
	$r = min($r, $q{l}-$q{s});
	$r = min($r, $w2);
	$r = max($r, $q{sw}/2 + $q{so}/2);

	return
		$self->_arc (0, -$q{l}, $r, 0, 180, $q{t}) .

		$self->_line(-$w1, -$q{l}, -$r, -$q{l}, $q{t}) .
		$self->_line($r, -$q{l}, $w1, -$q{l}, $q{t}) .
		$self->_line(-$w1, $q{l}, $w1, $q{l}, $q{t}) .

		$self->_line( $w2, -$q{l}, $w2, $q{l}, $q{t}) .
		$self->_line(-$w2, $q{l}, -$w2, -$q{l}, $q{t});
}


##
1;
##

__END__

=head1 NAME

GEDA::Machinery::PCB::Footprint::Dilpad - a footprint generator for surface-mount DIL parts in gEDA pcb

=head1 SYNOPSIS

	use GEDA::Machinery::PCB::Footprint::Dilpad;
	
	my $gen = new GEDA::Machinery::PCB::Footprint::Dilpad (
		key1 => value1,
		...
		keyN => valueN
	);
	# Optionally, supply filehandle to any of these.
	# If omitted, the currently selected handle is used.
	$gen->write_footprint_to_handle($fp_fh);
	$gen->write_eps_to_handle($eps_fh); # binmode handle first
	$gen->write_png_to_handle($png_fh); # binmode handle first

	# Example: One possibility for SSOP-28
	my $gen = new GEDA::Machinery::PCB::Footprint::Dilpad (
		id => 'SSOP28',
		description => 'SSOP-28 (JEDEC MP-150-AH)',
		units => 'mm',
		seq => 'A',
		c => 0.127,
		m => 0.3,
		so => 0.2,
		sw => 0.6,
		bw => 5.3,
		cw => 7.8,
		e => 0.65,
		pl => 2.25,
		plc => 6.55,
		pw => 0.43,
		np => 28,
		bl => 10.2,
	);

=head1 METHODS

=over 4

=item $gen = GEDA::Machinery::PCB::Footprint::Dilpad->new(I<%parameters>)

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
defined as 2.13 times the defined value for C<ll>.

In the following descriptions,

=over 4

=item *

The B<end> of a pin or pad is a side that is facing toward or away from the
body of the device. (Two opposite pads have facing ends.)

=item *

The B<edge> of a pin or pad is a side that is perpendicular to the body of the
device. (Two adjacent pads have facing edges.)

=item *

The B<physical bound> is the smallest rectangle containing both the body and
all of the pads.

=back

	bl = body length
	bw = body width
	np = number of pins (required)

	cw = component width (between opposing ends of opposite pins)
	pxl = pad extents length (between opposing ends of opposite pads)
	g = gap (between facing ends of opposite pads, can be % of bw)
	plc = pad length, center-to-center (between centers of opposite pads)

	e = pitch (between centers of adjacent pads)
	pg = pad gap (between facing edges of adjacent pads)
	pw = pad width (between edges of single pad)
	lw = lead width (between edges of single pin)

	ll = lead length (between ends of single pin)
	pl = pad length (inner to outer end of a pad)
	ple = pad length extension (between end of pin and matching end of pad,
		can be % of ll)
	pwe = pad width extension (between edge of pin and matching edge of pad,
		can be % of lw)

	so = silk offset (between physical bound and near edge of silk line)
	soc = silk offset to center (between physical bound and
		center of silk line)
	sw = silk width (thickness of silk line)

	c = clearance (between copper and polygon fill, can be % of pg)
	m = mask (between copper and mask, can be % of pg)

=head2 Sequence

	seq = numbering sequence type A-F, as follows:

		 A      B      C      D      E      F 
		1 8    1 5    1 2    8 1    5 1    2 1
		2 7    2 6    3 4    7 2    6 2    4 3
		3 6    3 7    5 6    6 3    7 3    6 5
		4 5    4 8    7 8    5 4    8 4    8 7

C<A> is the correct value for most ICs.

=head2 Pin names and numbers

The B<name> of a pin is simply arbitrary descriptive text.

The B<number> of a pin is the index by which nets are connected (corresponding
to the C<pinnumber> attribute in the schematic). Despite the name, this can be
alphanumeric.

Neither name nor number need be unique. Pads that are internally connected
might be given the same number in order to simplify the schematic symbol. For
example, one common 6-pin MOSFET pinout has 4 pins all connected to the drain,
so it might make sense to number all four of those pins as C<D>, and then
number the gate and source as C<G> and C<S> respectively. Some schematic
symbols already have pinnumbers compatible with this.

	1 = number for pin 1 (default 1)
	name1 = name for pin 1 (default 1)
	2 = number for pin 2 (default 2)
	name2 = name for pin 2 (default 2)
	... and so forth for any base-10
	    natural number without leading 0s ...

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

Based, by way of substantial refactoring, on dilpad.cgi by DJ Delorie.

=head1 COPYRIGHT

GEDA::Machinery::PCB::Footprint::Dilpad, a footprint generator for surface-mount DIL parts in gEDA pcb

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
