#!/usr/bin/perl
# -*- perl -*-

# Copyright 2006 DJ Delorie <dj@delorie.com>
# Released under the terms of the GNU General Public License, version 2

package GEDA::Machinery::PCB::Panelizer;

use warnings;
use strict;
use Carp;
use 5.010;

use File::Temp 'tempdir';
use File::Spec;

use GEDA::Machinery::Run;


sub baseboard {
	my $self = shift;
	my ($file, $width, $height, $nbase, $output_filename) = @_;
	if(! $output_filename) {
		my $base;
		if (! $nbase) {
			$base = $file;
			$base =~ s@.*/@@;
		} else {
			$base = $nbase;
		}
		$output_filename = "$base.panel.pcb";
		$output_filename =~ s/pnl\.panel\.pcb/pcb/;
	}
	$self->{output_filename} = $output_filename;

	$self->{panelcopperlayers} = ".*" unless $self->{panelcopperlayers};

	my $pscript = $self->_add_temp_key("pscript", "pscript.pscript");

	open(my $scriptfh, '>', $pscript);
	$self->{scriptfh} = $scriptfh;

	my $inter_pcb_file = $self->_add_temp_key("inter", "inter.pcb");

	open(my $srcfh, '<', $file)
		or die("$file: $!");
	open(my $dstfh, '>', $inter_pcb_file);
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
	close $dstfh;
	close $srcfh;

	$self->_script("LoadFrom(Layout,$inter_pcb_file)");

	$self->{ox} = $self->{oy} = 0;
}

sub loadboard {
	my $self = shift;
	my ($file) = @_;
	$self->{seq} //= 0;
	$self->{seq} = 1 + $self->{seq};
	my $seq = $self->{seq};

	my $temp_panel = $self->_add_temp_key("panel.$seq", "panel.$seq");

	open(my $srcfh, '<', $file);
	open(my $dstfh, '>', $temp_panel);
	while (<$srcfh>) {
		if (/PCB\[.* (\S+) (\S+)\]/) {
			$self->{width} = $self->parseval($1);
			$self->{height} = $self->parseval($2);
		}
		s/Cursor\[.*\]/Cursor[0 0 0.0]/;
		print $dstfh $_;
	}
	close $dstfh;
	close $srcfh;
	$self->_script("LoadFrom(LayoutToBuffer,$temp_panel)");
}

sub opaste {
	my $self = shift;
	$self->{vx} = $self->{ox};
	$self->{vy} = $self->{oy} + $self->{height};
	$self->_script("PasteBuffer(ToLayout,$self->{ox},$self->{oy})");
	$self->{ox} += $self->{width};
	$self->{oy} = 0;
}

sub vpaste {
	my $self = shift;
	$self->_script("PasteBuffer(ToLayout,$self->{vx},$self->{vy})");
	$self->{vy} += $self->{height};
}

sub done {
	my $self = shift;
	my $scriptfh = $self->{scriptfh};
	
	my $final_output_filename = $self->{output_filename};

	$self->_script(
		"SaveTo(LayoutAs,$final_output_filename)",
		"Quit()"
		);

	close $scriptfh;
	delete $self->{scriptfh};

	GEDA::Machinery::Run->pcb_run_actions($self->_temp_key("pscript"));
}

sub parseval {
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





# Object facilities

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
	$self->_clear_temp_dir;
}

# Temp file facilities

sub _temp_dir {
	my $self = shift;
	my $dont_create = shift;
	if(not defined $self->{temp_dir} and not $dont_create) {
		$self->{temp_dir} = tempdir(CLEANUP => 1);
	}
	return $self->{temp_dir};
}

sub _temp_file {
	my $self = shift;
	my $name = shift;
	return File::Spec->catfile($self->_temp_dir(), $name);
}

sub _temp_key {
	my $self = shift;
	my $t = $self->{temp_files};

	my $key = shift;
	
	if(@_) {
		my $new_value = shift;
		if(not defined $new_value) {
			delete $t->{$key};
		}
		else {
			$t->{$key} = $self->_temp_file($new_value);
		}
	}

	return $t->{$key};
}

sub _add_temp_key {
	my $self = shift;
	my $key = shift;
	my $filename = shift;

	# Similar to $self->_temp_key($key, $filename), but this one only changes a
	# value that doesn't already exist. If the key exists, undef is returned.

	if(not exists $self->{temp_files}{$key}) {
		my $path = $self->{temp_files}{$key} = $self->_temp_file($filename);
		return $path;
	}
	return undef;
}



sub _clear_temp_files {
	my $self = shift;
	if(defined $self->{temp_files}) {
		for(keys %{$self->{temp_files}}) {
			unlink $self->{temp_files}{$_};
		}
		delete $self->{temp_files};
	}
}

sub _clear_temp_dir {
	my $self = shift;
	$self->_clear_temp_files;
	if(defined $self->{temp_dir}) {
		unlink $self->{temp_dir};
		delete $self->{temp_dir};
	}
}



sub _log {
	my $self = shift;
	say STDERR @_;
}



## Original scripts

sub _read_pcb_for_panel {
	my $self = shift;
	my $pcb = shift;

	my($width, $height);
	my @outline = ();

	open(my $fh, '<', $pcb);

	while (<$fh>) {
		if (/^PCB\[".*" (\S+) (\S+)\]/) {
			$width = $self->parseval($1);
			$height = $self->parseval($2);
			$self->_log(sprintf "%s : %d x %d", $pcb, $width, $height);
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

	close $fh;

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
	for my $filename (@_) {
		my($outline, $width, $height) = $self->_read_pcb_for_panel($filename);
		push @pcb_data, {
			width => $width,
			height => $height,
			filename => $filename,
			basename => $self->_basename_of($filename),
			outline => $outline,
		};
	}
	return @pcb_data;
}

sub _print_panel_element {
	my $self = shift;
	my ($outline, $desc, $name, $x, $y, $w, $h) = @_;

	my $value = "$w x $h";

	print qq{Element["" "$desc" "$name" "$value" $x $y 2000 2000 0 50 ""] (\n};
	print qq{  Pin[0  0 1000 0 0 400 "1" "1" ""]\n};
	print qq{  Pin[$w 0 1000 0 0 400 "2" "2" ""]\n};
	if ($outline =~ /\S/) {
		print $outline;
	} else {
		print "  ElementLine[0 0 $w 0 100]\n";
		print "  ElementLine[0 0 0 $h 100]\n";
		print "  ElementLine[$w 0 $w $h 100]\n";
		print "  ElementLine[0 $h $w $h 100]\n";
	}
	print ")\n";
	return $w + 10000;
}

sub pcb2panel_usage {
	my $script_name = shift;
	print "Usage: $script_name board1.pcb board2.pcb board3.pcb > boards.pcb\n";
	print "Then edit boards.pcb, putting each outline where you want it\n";
	print "and sizing the board.  Then:\n";
	print "panel2pcb boards.pcb\n";
	print "and edit/print boards.panel.pcb\n";
	return 0;
}

sub pcb2panel_run {
	my $package = shift;
	my $self = $package->new;
	my $script_name = shift // $0;
	return pcb2panel_usage($script_name) unless @_;

	my @pcb_data = $self->_collect_outlines(@_);

	# Calculate full panel dimensions
	my($panel_width, $panel_height) = (10000, 0);
	for(@pcb_data) {
		my($width, $height) = @$_{qw/width height/};
		$panel_width += $width + 10000;
		$panel_height = $height if $panel_height < $height;
	}
	$panel_height += 20000;

	print qq{PCB["" $panel_width $panel_height]\n};
	print "Grid[10000.0 0 0 1]\n";
	print "DRC[799 799 800 100 1500 800]\n";
	print qq{Groups("1,c:2,s")\n};

	my($x, $y) = (10000, 10000);

	for(@pcb_data) {
		my($desc, $name, $outline, $w, $h) =
			@$_{qw/filename basename outline width height/};
		$x += $self->_print_panel_element($outline, $desc, $name, $x, $y, $w, $h);
	}

	print qq{Layer(1 "component")()\n};
	print qq{Layer(2 "solder")()\n};
	print qq{Layer(3 "silk")()\n};
	print qq{Layer(4 "silk")()\n};

	return 0;
}


sub panel2pcb_usage {
	my $script_name = shift;
	print "Usage: $script_name board1.pcb board2.pcb board3.pcb > boards.pcb\n";
	print "Then edit boards.pcb, putting each outline where you want it\n";
	print "and sizing the board.  Then:\n";
	print "panel2pcb [-l regex] boards.pcb\n";
	print "and edit/print boards.panel.pcb\n";
	return 0;
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
			$panel_width = $self->parseval($1);
			$panel_height = $self->parseval($2);
		}
		if (/Element\["[^"]*"\s+"([^"]*)"\s+"([^"]*)"\s+"([^"]*)"\s+(\S+)\s+(\S+)/) {
			$pcb = $1;
			#$base = $2;
			#$value = $3;
			$mx = $self->parseval($4);
			$my = $self->parseval($5);
			%pinq = ();
		}
		if (/Pin\[(\S+)\s+(\S+)\s+\S+\s+\S+\s+\S+\s+\S+\s+"(\d)"/) {
			$pinq{$3} = [$self->parseval($1), $self->parseval($2)];
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

sub panel2pcb_run {
	my $package = shift;
	my $self = $package->new;
	my $script_name = shift // $0;
	return panel2pcb_usage($script_name) unless @_;

	if (@_ and $_[0] eq "-l") {
		$self->{panelcopperlayers} = shift;
	}

	my $panel_filename = shift;
	my $panel_xname = $panel_filename;
	$panel_xname =~ s/\.pcb$//;

	my($panel_width, $panel_height, @pastes) = $self->_parse_panel_file($panel_filename);

	my $start = $pastes[0][0];

	$self->baseboard($start, $panel_width, $panel_height, $panel_xname);

	my $lastboard;
	my $lastrot;

	for my $paste (sort @pastes) {
		my($pcb, $rot, $mx, $my) = @$paste;
		if (!defined($lastboard) or $lastboard ne $pcb) {
			$self->loadboard ($pcb);
			$lastboard = $pcb;
			$lastrot = 0;
		}
		while ($lastrot != $rot) {
			$self->_script("PasteBuffer(Rotate,1)");
			$lastrot = ($lastrot+1) % 4;
		}
		$self->_script("PasteBuffer(ToLayout,$mx,$my)");
	}

	$self->done();
}

sub _script {
	my $self = shift;
	my $fh = $self->{scriptfh};
	for(@_) {
		print $fh "$_\n";
	}
}

1;
