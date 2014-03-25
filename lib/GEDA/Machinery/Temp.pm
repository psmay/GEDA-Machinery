
package GEDA::Machinery::Temp;

use warnings;
use strict;
use Carp;
use 5.010;

use File::Temp 'tempdir';
use File::Spec;
use File::Copy 'copy';

sub _temp_mgmt_data {
	my $self = shift;
	my $pkg = __PACKAGE__;
	if(not $self->{$pkg}) {
		$self->{$pkg} = {};
	}
	return $self->{$pkg};
}

sub _temp_dir {
	my $self = shift;
	my $dont_create = shift;
	my $delete = +(defined($dont_create) and $dont_create eq 'delete');

	my $d = $self->_temp_mgmt_data;
	if($delete) {
		delete $d->{dir};
	}
	elsif(not defined $d->{dir} and not $dont_create) {
		$d->{dir} = tempdir(CLEANUP => 1);
	}
	return $d->{dir};
}

sub _temp_files {
	my $self = shift;
	my $dont_create = shift;
	my $delete = +(defined($dont_create) and $dont_create eq 'delete');

	my $d = $self->_temp_mgmt_data;
	if($delete) {
		delete $d->{files};
	}
	elsif(not defined $d->{files} and not $dont_create) {
		$d->{files} = {};
	}
	return $d->{files};
}

sub _temp_file {
	my $self = shift;
	my $name = shift;
	return File::Spec->catfile($self->_temp_dir, $name);
}

sub _temp_filename_for_key {
	my $self = shift;
	return undef;
}

sub _temp_key {
	my $self = shift;
	my $key = shift;
	my $dont_create = shift;
	my $filename = shift;

	my $d = $self->_temp_mgmt_data;
	my $t = $self->_temp_files;

	if(not exists $t->{$key}) {
		if(not $dont_create) {
			$filename = $self->_temp_filename_for_key($key)
				unless defined $filename;
			croak "_temp_filename_for_key does not supply " .
				"a filename for key $key"
				unless defined $filename;
			$t->{$key} = $self->_temp_file($filename);
		}
		else {
			return undef;
		}
	}

	return $t->{$key};
}

sub __temp_get_current_handle() {
	my $h = select;
	if(not ref $h) {
		no strict 'refs';
		$h = \*{$h};
	}
	return $h;
}

sub _temp_cat {
	my $self = shift;
	my $key = shift;
	my $dst = shift;
	$dst = __temp_get_current_handle unless defined $dst;

	my $filename = $self->_temp_key($key, 1);
	croak "No known filename for key '$key'" unless defined $filename;
	copy($filename, $dst);
}

sub _temp_clear_files {
	my $self = shift;
	my $d = $self->_temp_mgmt_data;
	my $f = $self->_temp_files(1);
	if(defined $f) {
		for(keys %$f) {
			unlink $f->{$_};
		}
		$self->_temp_files('delete');
	}
}

sub _temp_clear_dir {
	my $self = shift;
	my $d = $self->_temp_mgmt_data;
	my $t = $self->_temp_dir(1);
	$self->_temp_clear_files;
	if(defined $t) {
		unlink $t;
		$self->_temp_dir('delete');
	}
}


1;

