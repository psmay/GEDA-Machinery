#!/usr/bin/perl
# -*- perl -*-

# Copyright 2006 DJ Delorie <dj@delorie.com>
# Refactoring work contributed 2014 Peter S. May <http://psmay.com/>
# Released under the terms of the GNU General Public License, version 2

package GEDA::Machinery::PCB::Panelizer;

use warnings;
use strict;
use Carp;
use 5.010;

use base 'GEDA::Machinery::Temp';

use GEDA::Machinery::Run;


sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = bless {}, $class;
	$self->_initialize(@_);
	return $self;
}

sub _initialize {
	my $self = shift;
	$self->{panelvias} = [];
	$self->{panelcopper} = [];
}

sub DESTROY {
	my $self = shift;
	$self->_temp_clear_dir;
}

sub _log {
	my $self = shift;
	say STDERR @_;
}

sub _parse_value {
	my $self = shift;
	my ($v) = @_;
	if ($v =~ s/mil//) {
		$v *= 100;
	}
	elsif ($v =~ s/mm//) {
		$v *= 3937.007874015748;
	}
	return 0 + $v;
}

sub _usage {
	print STDERR "Invalid parameters\n";
	print STDERR "Usage: First, run\n";
	print STDERR "\tpanelizer-pcb2panel board1.pcb board2.pcb board3.pcb > boards.pcb\n";
	print STDERR "Then, edit boards.pcb to place outlines and size the board.\n";
	print STDERR "Next, run\n";
	print STDERR "\tpanelizer-panel2pcb [-l regexp] boards.pcb > panel.pcb\n";
	print STDERR "and edit/print panel.pcb.\n";
	return 2;
}



package GEDA::Machinery::PCB::Panelizer::ToPanel;
use base 'GEDA::Machinery::PCB::Panelizer';

sub _read_pcb_for_panel {
	my $self = shift;
	my $fh = shift;
	my $pcb_suggested_name = shift;

	my($width, $height);
	my @outline = ();

	while (<$fh>) {
		if (/^PCB\[".*" (\S+) (\S+)\]/) {
			$width = $self->_parse_value($1);
			$height = $self->_parse_value($2);
			$self->_log(sprintf "%s : %d x %d", $pcb_suggested_name // "(board)", $width, $height);
			last;
		}
	}

	while (<$fh>) {
		if (/Layer\(.*"outline"\)/) {
			<$fh>; # open paren
			while (<$fh>) {
				last if /^\)/; # close paren
				my($args) = m@\[(.*)\]@;
				my($x1, $y1, $x2, $y2, $width) = split(' ', $args);
				push @outline, "  ElementLine[$x1 $y1 $x2 $y2 $width]\n";
			}
		}
	}

	return (join('', @outline), $width, $height);
}

sub _basename_of {
	my $self = shift;
	my $pcb = shift;
	for($pcb) {
		s@.*/@@;
		s@\.pcb$@@;
	}
	return $pcb;
}

sub _collect_outlines {
	my $self = shift;
	my @pcb_data;
	for my $file (@_) {
		open(my $fh, '<', $file);
		my($outline, $width, $height) = $self->_read_pcb_for_panel($fh, $file);
		close $fh;

		push @pcb_data, {
			width => $width,
			height => $height,
			filename => $file,
			basename => $self->_basename_of($file),
			outline => $outline,
		};
	}
	return @pcb_data;
}

sub _print_panel_element {
	my $self = shift;
	my ($fh, $outline, $desc, $name, $x, $y, $w, $h) = @_;

	my $value = "$w x $h";

	print $fh qq{Element["" "$desc" "$name" "$value" $x $y 2000 2000 0 50 ""] (\n};
	print $fh qq{  Pin[0  0 1000 0 0 400 "1" "1" ""]\n};
	print $fh qq{  Pin[$w 0 1000 0 0 400 "2" "2" ""]\n};
	if ($outline =~ /\S/) {
		print $outline;
	} else {
		print $fh "  ElementLine[0 0 $w 0 100]\n";
		print $fh "  ElementLine[0 0 0 $h 100]\n";
		print $fh "  ElementLine[$w 0 $w $h 100]\n";
		print $fh "  ElementLine[0 $h $w $h 100]\n";
	}
	print $fh ")\n";
	return $w + 10000;
}

sub _current_handle() {
	my $h = select;
	if(not ref $h) {
		no strict 'refs';
		$h = \*{$h};
	}
	return $h;
}

sub _pcb_to_panel {
	my $self = shift;
	my $fh = shift // _current_handle;
	my @pcb_data = $self->_collect_outlines(@_);

	# Calculate full panel dimensions
	my($panel_width, $panel_height) = (10000, 0);
	for(@pcb_data) {
		my($width, $height) = @$_{qw/width height/};
		$panel_width += $width + 10000;
		$panel_height = $height if $panel_height < $height;
	}
	$panel_height += 20000;

	# File header
	print $fh qq{PCB["" $panel_width $panel_height]\n};
	print $fh "Grid[10000.0 0 0 1]\n";
	print $fh "DRC[799 799 800 100 1500 800]\n";
	print $fh qq{Groups("1,c:2,s")\n};

	# Add a box outline representing each board in the panel construction file
	my($x, $y) = (10000, 10000);

	for(@pcb_data) {
		my($desc, $name, $outline, $w, $h) =
			@$_{qw/filename basename outline width height/};
		$x += $self->_print_panel_element($fh, $outline, $desc, $name, $x, $y, $w, $h);
	}

	# File footer
	print $fh qq{Layer(1 "component")()\n};
	print $fh qq{Layer(2 "solder")()\n};
	print $fh qq{Layer(3 "silk")()\n};
	print $fh qq{Layer(4 "silk")()\n};
}

sub run {
	my $package = shift;
	my $self = $package->new;
	my $script_name = shift // $0;
	return $self->_usage() unless @_;

	$self->_pcb_to_panel(_current_handle, @_);
	return 0;
}



package GEDA::Machinery::PCB::Panelizer::ToPCB;
use base 'GEDA::Machinery::PCB::Panelizer';

my %temp_keys = (
	pscript => 'pscript.pscript',
	inter => 'inter.pcb',
	final => 'final.pcb',
);

sub _temp_filename_for_key {
	my $self = shift;
	my $key = shift;
	if($key =~ /^panel\.\d+$/) {
		return $key;
	}
	return $temp_keys{$key};
}

sub _figure_rotation {
	my($p1, $p2) = @_;
	my($x1, $y1) = @$p1;
	my($x2, $y2) = @$p2;

	if ($x1 < $x2) {
		return 0;
	} elsif ($x1 > $x2) {
		return 2;
	} elsif ($y1 < $y2) {
		return 3;
	} elsif ($y1 > $y2) {
		return 1;
	}
}

sub _parse_panel_file {
	my $self = shift;
	my($filename) = @_;

	my($panel_width, $panel_height, $pcb, $mx, $my, $rot);
	my(%pinq, @pastes);

	open(my $fh, '<', $filename)
		or die "$filename: $!";
	while (<$fh>) {
		if (/PCB\[.* (\S+) (\S+)\]/) {
			$panel_width = $self->_parse_value($1);
			$panel_height = $self->_parse_value($2);
		}
		if (/Element\["[^"]*"\s+"([^"]*)"\s+"([^"]*)"\s+"([^"]*)"\s+(\S+)\s+(\S+)/) {
			$pcb = $1;
			#$base = $2;
			#$value = $3;
			$mx = $self->_parse_value($4);
			$my = $self->_parse_value($5);
			%pinq = ();
		}
		if (/Pin\[(\S+)\s+(\S+)\s+\S+\s+\S+\s+\S+\s+\S+\s+"(\d)"/) {
			$pinq{$3} = [$self->_parse_value($1), $self->_parse_value($2)];
		}
		if ($pcb && /\)/) {
			$rot = _figure_rotation($pinq{1}, $pinq{2});
			push @pastes, [$pcb, $rot, $mx, $my];
			$pcb = undef;
		}
		if (/Via/) {
			push (@{$self->{panelvias}}, $_);
		}
		if (/^Layer\([^)]*\)$/) {
			<$fh>; # The opening '('
			while (<$fh>) {
				last if /^\)/;
				push (@{$self->{panelcopper}}, $_);
			}
		}
	}
	close $fh;

	return ($panel_width, $panel_height, @pastes);
}

sub _load_board {
	my $self = shift;
	my ($file) = @_;
	$self->{seq} //= 0;
	$self->{seq} = 1 + $self->{seq};
	my $seq = $self->{seq};

	my $temp_panel = $self->_temp_key("panel.$seq");

	open(my $srcfh, '<', $file);
	open(my $dstfh, '>', $temp_panel);
	while (<$srcfh>) {
		if (/PCB\[.* (\S+) (\S+)\]/) {
			$self->{width} = $self->_parse_value($1);
			$self->{height} = $self->_parse_value($2);
		}
		s/Cursor\[.*\]/Cursor[0 0 0.0]/;
		print $dstfh $_;
	}
	close $dstfh;
	close $srcfh;
	$self->_script("LoadFrom(LayoutToBuffer,$temp_panel)");
}

sub _paste_boards {
	my $self = shift;
	my @pastes = @_;

	my $lastboard;
	my $lastrot;

	for my $paste (sort { join("\0", @$a) cmp join("\0", @$b) } @pastes) {
		my($pcb, $rot, $mx, $my) = @$paste;
		if (!defined($lastboard) or $lastboard ne $pcb) {
			$self->_load_board ($pcb);
			$lastboard = $pcb;
			$lastrot = 0;
		}
		while ($lastrot != $rot) {
			$self->_script("PasteBuffer(Rotate,1)");
			$lastrot = ($lastrot+1) % 4;
		}
		$self->_script("PasteBuffer(ToLayout,$mx,$my)");
	}
}

sub _generate_panel_to_pcb_script {
	my $self = shift;
	my($start_pcb_filename, $panel_width, $panel_height, $panel_basename, @pastes) = @_;
	$self->_begin_script();
	$self->_load_as_base_board($start_pcb_filename, $panel_width, $panel_height, $panel_basename);
	$self->_paste_boards(@pastes);
	$self->_end_script;
}

sub _convert_to_base_board {
	my $self = shift;
	my($srcfh, $dstfh, $width, $height) = @_;
	while (<$srcfh>) {
		if (/PCB\[.* (\S+) (\S+)\]/) {
			s/ (\S+) (\S+)\]/ $width $height\]/;
		}
		s/Cursor\[.*\]/Cursor[0 0 0.0]/;
		if (/^Flags/) {
			s/,uniquename,/,/;
			s/,uniquename//;
			s/uniquename,//;
		}
		next if /\b(Via|Pin|Pad|ElementLine|Line|Arc|ElementArc|Text)/;
		if (/Polygon|Element/) {
			my $hole = 0;
			while (<$srcfh>) {
				$hole++ if /Hole \(/;
				last if /^\s*\)\s*$/ && $hole <= 0;
				$hole-- if /\)/;
			}
			next;
		}
		if (/Layer/) {
			if (@{$self->{panelvias}}) {
				print $dstfh @{$self->{panelvias}};
				@{$self->{panelvias}} = ();
			}
		}
		print $dstfh $_;
		if (/Layer\((\d+) \"(.*)\"\)/) {
			my $lnum = $1;
			my $lname = $2;
			print $dstfh scalar <$srcfh>;
			$self->_log("layer $lnum $lname vs '$self->{panelcopperlayers}'");
			if ($lnum =~ /$self->{panelcopperlayers}/ || $lname =~ /$self->{panelcopperlayers}/) {
				print $dstfh @{$self->{panelcopper}};
			}
		}
	}
}

sub _load_as_base_board {
	my $self = shift;
	my ($start_pcb_filename, $panel_width, $panel_height, $nbase, $suggested_output_filename) = @_;

	$self->{panelcopperlayers} = ".*" unless $self->{panelcopperlayers};

	my $inter_pcb_file = $self->_temp_key("inter");


	open(my $srcfh, '<', $start_pcb_filename) or croak("$start_pcb_filename: $!");
	open(my $dstfh, '>', $inter_pcb_file);
	$self->_convert_to_base_board($srcfh, $dstfh, $panel_width, $panel_height);
	close $dstfh;
	close $srcfh;

	$self->_script("LoadFrom(Layout,$inter_pcb_file)");

	$self->{ox} = $self->{oy} = 0;
}

sub _cat_result {
	my $self = shift;
	my $dst = shift;
	$self->_temp_cat("final", $dst);
}

sub _open_script {
	my $self = shift;
	my $pscript = $self->_temp_key("pscript");
	open(my $scriptfh, '>', $pscript);
	$self->{scriptfh} = $scriptfh;
}

sub _begin_script {
	my $self = shift;
	$self->_open_script(@_);
	# Insert any application-blind header here
}

sub _script {
	my $self = shift;
	my $fh = $self->{scriptfh};
	for(@_) {
		print $fh "$_\n";
	}
}

sub _close_script {
	my $self = shift;
	my $scriptfh = $self->{scriptfh};
	close $scriptfh;
	delete $self->{scriptfh};
}

sub _end_script {
	my $self = shift;
	my $temp_output_filename = $self->_temp_key("final");
	$self->_script(
		"SaveTo(LayoutAs,$temp_output_filename)",
		"Quit()"
		);
	$self->_close_script;
}

sub _run_script {
	my $self = shift;
	GEDA::Machinery::Run->pcb_run_actions($self->_temp_key("pscript"));
}

sub run {
	my $package = shift;
	my $self = $package->new;
	my $script_name = shift // $0;
	return $self->_usage() unless @_;

	if (@_ and $_[0] eq "-l") {
		$self->{panelcopperlayers} = shift;
	}

	my $panel_filename = shift;
	my $panel_basename = $panel_filename;
	$panel_basename =~ s/\.pcb$//;

	my($panel_width, $panel_height, @pastes) = $self->_parse_panel_file($panel_filename);
	my $start_pcb_filename = $pastes[0][0];

	$self->_generate_panel_to_pcb_script(
		$start_pcb_filename, $panel_width, $panel_height, $panel_basename, @pastes);
	$self->_run_script;

	$self->_cat_result();
}

1;
