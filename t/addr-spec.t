# $Id$
use strict;
use Test::More tests => 2;

BEGIN { use_ok 'Email::Find::addrspec' }
ok defined $Addr_spec_re;

