package Email::Find;

use strict;
use vars qw($VERSION @EXPORT);
$VERSION = '0.05';

# Need qr//.
require 5.005;

use base qw(Exporter);
@EXPORT = qw(find_emails);

use Email::Valid;
require Mail::Address;


my $esc         = '\\\\';               my $period      = '\.';
my $space       = '\040';
my $open_br     = '\[';                 my $close_br    = '\]';
my $nonASCII    = '\x80-\xff';          my $ctrl        = '\000-\037';
my $cr_list     = '\n\015';
my $qtext       = qq/[^$esc$nonASCII$cr_list\"]/;
my $dtext       = qq/[^$esc$nonASCII$cr_list$open_br$close_br]/;
my $quoted_pair = qq<$esc>.qq<[^$nonASCII]>;
my $atom_char   = qq/[^($space)<>\@,;:\".$esc$open_br$close_br$ctrl$nonASCII]/;
my $atom        = qq<$atom_char+(?!$atom_char)>;
my $quoted_str  = qq<\"$qtext*(?:$quoted_pair$qtext*)*\">;
my $word        = qq<(?:$atom|$quoted_str)>;
my $domain_ref  = $atom;
my $domain_lit  = qq<$open_br(?:$dtext|$quoted_pair)*$close_br>;
my $sub_domain  = qq<(?:$domain_ref|$domain_lit)>;
my $domain      = qq<$sub_domain(?:$period$sub_domain)*>;
my $local_part  = qq<$word(?:$period$word)*>;


# Finally, the address-spec regex (more or less)
use vars qw($Addr_spec_re);
$Addr_spec_re   = qr<$local_part\s*\@\s*$domain>;



my $validator = Email::Valid->new('-fudge'      => 1,
                                  '-fqdn'       => 1,
                                  '-local_rules' => 1,
                                  '-mxcheck'    => 0,
                                 );

sub find_emails (\$&) {
    my($r_text, $callback) = @_;

    my $emails_found = 0;

    study($$r_text);

    $$r_text =~ s{($Addr_spec_re)}{
        my($orig_match) = $1;

        # XXX Add cruft handling.
        my($start_cruft) = '';
        my($end_cruft)   = '';
        if( $orig_match =~ s|([),.'";?!]+)$|| ) { 
            $end_cruft = $1; 
        } 

        if( my $email = $validator->address($orig_match) ) {
            $email = Mail::Address->new('', $email);
            $emails_found++;

            $start_cruft . $callback->($email, $orig_match) . $end_cruft;
        }
        else {
            # XXX Again with the cruft!

            $start_cruft . $orig_match . $end_cruft;
        }
    }eg;

    return $emails_found;
}

return '*@qt.to';

__END__

=pod

=head1 NAME

  Email::Find - Find RFC 822 email addresses in plain text


=head1 SYNOPSIS

  use Email::Find;
  $num_found = find_emails($text, \&callback);


=head1 DESCRIPTION

This is a module for finding a I<subset> of RFC 822 email addresses in
arbitrary text (L<CAVEATS>).  The addresses it finds are not
guaranteed to exist or even actually be email addresses at all
(L<CAVEATS>), but they will be valid RFC 822 syntax.

Email::Find will perform some heuristics to avoid some of the more
obvious red herrings and false addresses, but there's only so much
which can be done without a human.


=head2 Functions

Email::Find exports one function, find_emails().  It works very
similar to URI::Find's find_uris().

  $num_emails_found = find_emails($text, \&callback);

The first argument is a block of text for find_emails to search
through and manipulate.  Second is a callback routine which defines
what to do with each email as they're found.  It returns the total
number of emails found.

The callback is given two arguments.  The first is a Mail::Address
object representing the address found.  The second is the actual
original email as found in the text.  Whatever the callback returns
will replace the original text.


=head1 EXAMPLES

  # Simply print out all the addresses found leaving the text undisturbed.
  find_emails($text, sub {
                         my($email, $orig_email) = @_;
                         print "Found ".$email->format."\n";
                         return $orig_email;
                     });


  # For each email found, ping its host to see if its alive.
  require Net::Ping;
  $ping = Net::Ping->new;
  my %Pinged = ();
  find_emails($text, sub {
                         my($email, $orig_email) = @_;
                         my $host = $email->host;
                         next if exists $Pinged{$host};
                         $Pinged{$host} = $ping->ping($host);
                     });

  while( my($host, $up) = each %Pinged ) {
      print "$host is ". $up ? 'up' : 'down' ."\n";
  }


  # Count how many addresses are found.
  print "Found ", find_emails($text, sub { return $_[1] }), " addresses\n";


  # Wrap each address in an HTML mailto link.
  find_emails($text, sub {
                         my($email, $orig_email) = @_;
                         my($address) = $email->format;
                         return qq|<a href="mailto:$address">$orig_email</a>|;
                     });


=head1 CAVEATS

=over 4

=item Why a subset of RFC 822?

I say that this module finds a I<subset> of RFC 822 because if I
attempted to look for I<all> possible valid RFC 822 addresses I'd wind
up practically matching the entire block of text!  The complete
specification is so wide open that its difficult to construct
soemthing that's I<not> an RFC 822 address.

To keep myself sane, I look for the 'address spec' or 'global address'
part of an RFC 822 address.  This is the part which most people
consider to be an email address (the 'foo@bar.com' part) and it is
also the part which contains the information necessary for delivery.

=item Why are some of the matches not email addresses?

Alas, many things which aren't email addresses I<look> like email
addresses and parse just fine as them.  The biggest headache is email
and usenet and email message IDs.  I do my best to avoid them, but
there's only so much cleverness you can pack into one library.

=back

=head1 AUTHOR

Copyright 2000, 2001 Michael G Schwern <schwern@pobox.com>.
All rights reserved.

=head1 THANKS

Thanks to Jeremy Howard for his patch to make it work under 5.005.

Many thanks to Tatsuhiko Miyagawa for the much, much faster and
simpler regex!

=head1 LICENSE

This module is free software; you may redistribute it and/or modify it
under the same terms as Perl itself.

=for _private
After talking with a few legal people, it was found I can't restrict how
code is used, only how it is distributed.  Not without making installation
of the module annoying.  Please don't make me add the annoying installation
steps.

The author B<STRONGLY SUGGESTS> that this module not be used for the
purposes of sending unsolicited email (ie. spamming) in any way, shape
or form or for the purposes of generating lists for commercial sale.

If you use this module for spamming I reserve the right to make fun of
you.

=head1 SEE ALSO

L<Email::Valid>, RFC 822, L<URI::Find>, L<Apache::AntiSpam>

=cut
