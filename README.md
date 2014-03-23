GEDA::Machinery
===============

This is a set of Perl scripts and libraries for
[gEDA](http://www.geda-project.org/). Currently, it is primarily
composed of adaptations of [original scripts by DJ
Delorie](http://www.gedasymbols.org/user/dj_delorie/) with substantial
refactoring to facilitate understanding and modification. This includes
modifications to support `warnings` and `strict`, change globals to
object attributes, and minimize calls to external programs.

The directory structure used is laid out with the intention of,
eventually, making the code packageable as a CPAN module.

License
-------

As of this writing, all of this library is available under GNU GPL v2 or
later. License and copyright information is included in the individual
files.
