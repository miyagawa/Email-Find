use lib qw(t/lib);
use Test::More tests => 14;
BEGIN { use_ok('Email::Find') }

my %Tests;
BEGIN {
    %Tests = ('Hahah!  Use "@".+*@[132.205.7.51] and watch them cringe!'
                  => '"@".+*@[132.205.7.51]',
              'What about "@"@foo.com?' => '"@"@foo.com',
              'Eli the Beared <*@qz.to>' => '*@qz.to',
              '"@"+*@[132.205.7.51]'    => '+*@[132.205.7.51]',
             );
}

while( my($text, $expect) = each %Tests ) {
    my($orig_text) = $text;
    ok( find_emails($text, sub { ok( $_[0]->address eq $expect, 
                                     "Found $_[1]" );
                                 return $_[1] 
                             } 
                   ) == 1,
        "  just one"
      );
    ok( $text eq $orig_text,    "  and replaced" );
}


# Do all the tests again as one big block of text.
my $mess_text = join "\n", keys %Tests;
ok( find_emails($mess_text, sub { return $_[1] }) == keys %Tests,
    'One big block' );


# Tests for false positives.
my @FalseTests;
BEGIN {
    # No tests at the moment.
    @FalseTests = (
                  );
}

foreach my $f_text (@FalseTests) {
    my $orig_text = $f_text;
    ok( find_emails($f_text, sub {1}) == 0, "False positive: $f_text" );
    ok( $orig_text eq $f_text,              "  replaced" );
}
