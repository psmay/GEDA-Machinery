
# ABSTRACT: Collection of extracurricular tasks in support of gEDA
# Dummy package to appease dist maker.
package GEDA::Machinery;
1;

# Use the following command to produce a Github readme:
#	pod2markdown <lib/GEDA/Machinery.pm >README.mkdn
# Or just run dzil release --trial and copy up README.mkdn.

__END__

=head1 NAME

GEDA::Machinery - Generation utilities for users of gEDA

=head1 DESCRIPTION

This is a set of Perl scripts and libraries for gEDA (L<http://www.geda-project.org/>). Currently, it is primarily composed of adaptations of original scripts by DJ Delorie (L<http://www.gedasymbols.org/user/dj_delorie/>) with substantial refactoring to facilitate understanding and modification. This includes modifications to support C<use warnings> and C<use strict>, change globals to object attributes, and minimize calls to external programs.

=head1 COPYRIGHT

Original portions copyright © 2014 Peter S. May.

Refer to individual files for additional information.

=head1 LICENSE

Except where otherwise specified, this software is provided under the terms of the GNU General Public License v2 (or, optionally, any later version) as published by the Free Software Foundation.

=cut


