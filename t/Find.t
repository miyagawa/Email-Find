# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)
use strict;

use vars qw($Total_tests);

my $loaded;
my $test_num = 1;
BEGIN { $| = 1; $^W = 1; }
END {print "not ok $test_num\n" unless $loaded;}
print "1..$Total_tests\n";
use Email::Find;
$loaded = 1;
ok(1, 'compile');
######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):
sub ok {
    my($test, $name) = @_;
    print "not " unless $test;
    print "ok $test_num";
    print " - $name" if defined $name;
    print "\n";
    $test_num++;
}

sub eqarray  {
    my($a1, $a2) = @_;
    return 0 unless @$a1 == @$a2;
    my $ok = 1;
    for (0..$#{$a1}) { 
        unless($a1->[$_] eq $a2->[$_]) {
        $ok = 0;
        last;
        }
    }
    return $ok;
}

# Change this to your # of ok() calls + 1
BEGIN { $Total_tests = 1 }

my %Tests;
BEGIN {
    %Tests = ('Hahah!  Use "@".+*@[132.205.7.51] and watch them cringe!'
                  => '"@".+*@[132.205.7.51]',
              'What about "@"@foo.com?' => '"@"@foo.com',
              'Eli the Beared <*@qz.to>' => '*@qz.to'
             );

    $Total_tests += (3 * keys %Tests);
}

while( my($text, $expect) = each %Tests ) {
    my($orig_text) = $text;
    ok( find_emails($text, sub { ok( $_[0]->address eq $expect );  
                                 return $_[1] 
                             } 
                   ) == 1 
      );
    ok( $text eq $orig_text );
}

BEGIN { $Total_tests++ }

# Do all the tests again as one big block of text.
my $mess_text = join "\n", keys %Tests;
ok( find_emails($mess_text, sub { return $_[1] }) == keys %Tests );


# Tests for false positives.
my @FalseTests;
BEGIN {
    @FalseTests = (
                   '"@"+*@[132.205.7.51]'
                  );

    $Total_tests += @FalseTests * 2;
}

foreach my $f_text (@FalseTests) {
    my $orig_text = $f_text;
    ok( find_emails($f_text, sub {1}) == 0 );
    ok( $orig_text eq $f_text );
}
