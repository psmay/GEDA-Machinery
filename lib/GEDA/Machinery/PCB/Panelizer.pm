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


sub baseboard {
	my $self = shift;
	my ($file, $width, $height, $nbase) = @_;
	my $base;
	if (! $nbase) {
		$base = $file;
		$base =~ s@.*/@@;
	} else {
		$base = $nbase;
	}

	$self->{panelcopperlayers} = ".*" unless $self->{panelcopperlayers};

	$self->{pscript} = "$base.pscript";

	open(my $scriptfh, ">$self->{pscript}");
	$self->{scriptfh} = $scriptfh;

	#push(@files_to_remove, "$base.pscript");

	$self->{outname} = "$base.panel.pcb";
	$self->{outname} =~ s/pnl\.panel\.pcb/pcb/;
	open(my $srcfh, $file) || die("$file: $!");
	open(my $dstfh, ">$self->{outname}");
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
			print STDERR "layer $lnum $lname vs '$self->{panelcopperlayers}'\n";
			if ($lnum =~ /$self->{panelcopperlayers}/ || $lname =~ /$self->{panelcopperlayers}/) {
				print $dstfh @{$self->{panelcopper}};
			}
		}
	}
	close $dstfh;
	close $srcfh;

	print $scriptfh "LoadFrom(Layout,$self->{outname})\n";

	$self->{ox} = $self->{oy} = 0;
}

sub loadboard {
	my $self = shift;
	my ($file) = @_;
	$self->{seq} //= 0;
	$self->{seq} = 1 + $self->{seq};

	open(my $srcfh, $file);
	open(my $dstfh, ">temp-panel.$self->{seq}");
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
	my $scriptfh = $self->{scriptfh};
	print $scriptfh "LoadFrom(LayoutToBuffer,temp-panel.$self->{seq})\n";
	#push(@files_to_remove, "temp-panel.$self->{seq}");
}

sub opaste {
	my $self = shift;
	$self->{vx} = $self->{ox};
	$self->{vy} = $self->{oy} + $self->{height};
	my $scriptfh = $self->{scriptfh};
	print $scriptfh "PasteBuffer(ToLayout,$self->{ox},$self->{oy})\n";
	$self->{ox} += $self->{width};
	$self->{oy} = 0;
}

sub vpaste {
	my $self = shift;
	my $scriptfh = $self->{scriptfh};
	print $scriptfh "PasteBuffer(ToLayout,$self->{vx},$self->{vy})\n";
	$self->{vy} += $self->{height};
}

sub done {
	my $self = shift;
	my $scriptfh = $self->{scriptfh};
	print $scriptfh "SaveTo(LayoutAs,$self->{outname}.final.pcb)\n";
	print $scriptfh "Quit()\n";

	close $scriptfh;
	delete $self->{scriptfh};

	system "set -x; pcb --action-script $self->{pscript}";
	#system "pcb -x ps $base.panel.pcb";
	#unlink @files_to_remove;
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






## Original scripts

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

	my %base;
	my @pcbs;
	my(%width, %height);
	my @outlines;

	for my $pcb (@_) {
		my $base = $pcb;
		$base =~ s@.*/@@;
		$base =~ s@\.pcb$@@;
		$base{$pcb} = $base;
		push (@pcbs, $pcb);
		open(my $fh, $pcb);
		while (<$fh>) {
			if (/^PCB\[".*" (\S+) (\S+)\]/) {
				$width{$pcb} = $self->parseval($1);
				$height{$pcb} = $self->parseval($2);
				printf STDERR "%s : %d x %d\n", $pcb, $width{$pcb}, $height{$pcb};
				last;
			}
		}
		my $outline = '';
		while (<$fh>) {
			if (/Layer\(.*"outline"\)/) {
				<$fh>; # open paren
				while (<$fh>) {
					last if /^\)/; # close paren
					my($args) = m@\[(.*)\]@;
					my($x1, $y1, $x2, $y2, $width) = split(' ', $args);
					$outline .= "  ElementLine[$x1 $y1 $x2 $y2 $width]\n";
				}
			}
		}
		push (@outlines, $outline);
		close $fh;
	}

	my $pw = 10000;
	my $ph = 0;
	for my $pcb (@pcbs) {
		$pw += 10000;
		$pw += $width{$pcb};
		$ph = $height{$pcb} if $ph < $height{$pcb};
	}
	$ph += 20000;

	print "PCB[\"\" $pw $ph]\n";
	print "Grid[10000.0 0 0 1]\n";
	print "DRC[799 799 800 100 1500 800]\n";
	print "Groups(\"1,c:2,s\")\n"; #"

	my $x = 10000;
	my $y = 10000;
	for (my $i=0; $i<@pcbs; $i++) {
		my $pcb = $pcbs[$i];
		my $outline = $outlines[$i];
		my $desc = $pcb;
		my $name = $base{$pcb};
		my $value = "$width{$pcb} x $height{$pcb}";
		my $w = $width{$pcb};
		my $h = $height{$pcb};

		print "Element[\"\" \"$desc\" \"$name\" \"$value\" $x $y 2000 2000 0 50 \"\"] (\n";
		print "  Pin[0  0 1000 0 0 400 \"1\" \"1\" \"\"]\n";
		print "  Pin[$w 0 1000 0 0 400 \"2\" \"2\" \"\"]\n";
		if ($outline =~ /\S/) {
			print $outline;
		} else {
			print "  ElementLine[0 0 $w 0 100]\n";
			print "  ElementLine[0 0 0 $h 100]\n";
			print "  ElementLine[$w 0 $w $h 100]\n";
			print "  ElementLine[0 $h $w $h 100]\n";
		}
		print ")\n";
		$x += $w + 10000;
	}

	print "Layer(1 \"component\")()\n";
	print "Layer(2 \"solder\")()\n";
	print "Layer(3 \"silk\")()\n";
	print "Layer(4 \"silk\")()\n";

	return 0;
}

sub panel2pcb_usage {
	my $script_name = shift;
	print "Usage: $script_name board1.pcb board2.pcb board3.pcb > boards.pcb";
	print "Then edit boards.pcb, putting each outline where you want it\n";
	print "and sizing the board.  Then:\n";
	print "panel2pcb [-l regex] boards.pcb\n";
	print "and edit/print boards.panel.pcb\n";
	return 0;
}

sub panel2pcb_run {
	my $package = shift;
	my $self = $package->new;
	my $script_name = shift // $0;
	return panel2pcb_usage() unless @_;

	my $panel = shift;

	if ($panel eq "-l") {
		$self->{panelcopperlayers} = shift;
		$panel = shift;
	}

	my($panel_width, $panel_height);
	my($pcb, $mx, $my, %pinx, %piny, $rot);
	my @paste;

	open(my $panelfh, '<', $panel) or die "$panel: $!";
	while (<$panelfh>) {
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
			%pinx = ();
			%piny = ();
		}
		if (/Pin\[(\S+)\s+(\S+)\s+\S+\s+\S+\s+\S+\s+\S+\s+"(\d)"/) {
			$pinx{$3} = $self->parseval($1);
			$piny{$3} = $self->parseval($2);
		}
		if ($pcb && /\)/) {
			my $x1 = $pinx{1};
			my $y1 = $piny{1};
			my $x2 = $pinx{2};
			my $y2 = $piny{2};

			if ($x1 < $x2) {
				$rot = 0;
			} elsif ($x1 > $x2) {
				$rot = 2;
			} elsif ($y1 < $y2) {
				$rot = 3;
			} elsif ($y1 > $y2) {
				$rot = 1;
			}
			push (@paste, "$pcb\0$rot\0$mx\0$my");
			$pcb = undef;
		}
		if (/Via/) {
			push (@{$self->{panelvias}}, $_);
		}
		if (/^Layer\([^)]*\)$/) {
			<$panelfh>; # The opening '('
			while (<$panelfh>) {
				last if /^\)/;
				push (@{$self->{panelcopper}}, $_);
			}
		}
	}
	close $panelfh;

	my $start = $paste[0];
	$start =~ s/\0.*//;

	$panel =~ s/\.pcb$//;
	$self->baseboard($start, $panel_width, $panel_height, $panel);

	my $lastboard;
	my $lastrot;

	my $scriptfh = $self->{scriptfh};
	for my $paste (sort @paste) {
		($pcb, $rot, $mx, $my) = split(/\0/, $paste);
		if (!defined($lastboard) or $lastboard ne $pcb) {
			$self->loadboard ($pcb);
			$lastboard = $pcb;
			$lastrot = 0;
		}
		while ($lastrot != $rot) {
			print $scriptfh "PasteBuffer(Rotate,1)\n";
			$lastrot = ($lastrot+1) % 4;
		}
		print $scriptfh "PasteBuffer(ToLayout,$mx,$my)\n";
	}

	$self->done();
}

1;
