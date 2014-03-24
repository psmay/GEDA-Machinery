
package GEDA::Machinery::Run;

use warnings;
use strict;
use Carp;
use 5.010;

use IPC::Open3;
use Symbol 'gensym';

my $PCB = `which pcb`;
chomp $PCB;

sub which_pcb {
	return $PCB;
}

sub _run_without_writing {
	my @command = @_;

	my $output;
	my $child_error;

	{
		local $/;
		my ($out, $in) = ('', gensym);

		my $pid = open3($out, $in, $in, @command)
			or croak "Could not run @command: $!";
		close $out;
		$output = <$in>;
		close $in;
		waitpid $pid, 0;

		$child_error = $?;
	}

	if($child_error) {
		my $exit_code = $child_error >> 8;
		croak "Command @command exited with status $exit_code: $output";
	}
}

sub pcb_visible_to_eps {
	my $self = shift;
	my $pcb_filename = shift;
	my $eps_filename = shift;

	my $pcb = $self->which_pcb;

	_run_without_writing(
		$pcb,
		qw/-x eps/,
		'--eps-file', $eps_filename,
		'--only-visible',
		$pcb_filename);
}

sub pcb_run_actions {
	my $self = shift;
	my $script_filename = shift;

	my $pcb = $self->which_pcb;

	_run_without_writing($pcb, '--action-script', $script_filename);
}

1;

