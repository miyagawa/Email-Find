package Email::Find;

use strict;
use vars qw($VERSION @EXPORT);
$VERSION = '0.03';

# Need qr//.
require 5.005;

use base qw(Exporter);
@EXPORT = qw(find_emails);

use Email::Valid;
require Mail::Address;

# XXX Boy, does this need to be cleaned up!

# XXX I can probably get these from a module.
# Build up basic RFC 822 BNF definitions.
use vars qw($Specials $Space $Char $Ctl $Atom_re $Specials_cheat
            $Atom_cheat_re
           );
$Specials = quotemeta '()<>@,;:\\".[]';
$Space    = '\040';
$Char     = '\000-\177';
$Ctl      = '\000-\037\177';
$Atom_re  = qq/[^$Ctl$Space$Specials]+/;
$Specials_cheat = $Specials;
$Specials_cheat =~ s/\\\.//;
$Atom_cheat_re = qq/[^$Ctl$Space$Specials_cheat]+/;

# Build quoted string regex
use vars qw($Qtext_re $Qpair_re $Quoted_string_re);
$Qtext_re = '[^"\\\r]+';      # " #
$Qpair_re = qq/\\\\[$Char]/;
$Quoted_string_re = qq/"(?:$Qtext_re|$Qpair_re)*"/;

# Build domain regex.
use vars qw($Domain_ref_re $Dtext_re $Domain_literal_re $Sub_domain_re
            $Domain_ref_cheat_re $Sub_domain_literal_cheat_re
            $Domain_literal_cheat_re
           );
$Domain_ref_re = $Atom_re;
$Dtext_re = q/[^\[\]\\\\\r]/;
$Domain_literal_re = q/\[(?:$Dtext_re|$Qpair_re)*\]/;
$Sub_domain_re = "(?:$Domain_ref_re|$Domain_literal_re)";
$Domain_ref_cheat_re = $Atom_cheat_re;

$Sub_domain_literal_cheat_re = "(?:$Dtext_re|$Qpair_re)*";
$Domain_literal_cheat_re = qq/\\[$Sub_domain_literal_cheat_re\\]/;

# Build local part regex.
use vars qw($Word_re $Local_part_re $Local_part_cheat_re);
$Word_re = "(?:$Atom_re|$Quoted_string_re)+";
$Local_part_re = qq/$Word_re(?:\\.$Word_re)*/;
$Local_part_cheat_re = qq/(?:$Atom_cheat_re|$Quoted_string_re)+/;

# Finally, the address-spec regex (more or less)
use vars qw($Addr_spec_re);
 $Addr_spec_re = qr/$Local_part_cheat_re\ ?\@\ ?
                        (?:$Domain_ref_cheat_re|
                           $Domain_literal_cheat_re)
                   /x;



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


=head1 LICENSE

This module may not be used for the purposes of sending unsolicited
email (ie. spamming) in any way, shape or form or for the purposes of
generating lists for commercial sale without explicit permission from
the author.

For everyone else this module is free software; you may redistribute
it and/or modify it under the same terms as Perl itself.

If you're not sure, contact the author.

=head1 SEE ALSO

L<Email::Valid>, RFC 822, L<URI::Find>, L<Apache::AntiSpam>

=cut
