package Email::Find;

# Sorry, embedded qr//'s appear to be really, really, really slow
# under 5.005 stable.
require 5.005_63;

use strict;
use vars qw($VERSION @EXPORT);
$VERSION = 0.01;

use base qw(Exporter);
@EXPORT = qw(find_emails);

#use Email::Valid;
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
$Atom_re  = qr/[^$Ctl$Space$Specials]+/;
$Specials_cheat = $Specials;
$Specials_cheat =~ s/\\\.//;
$Atom_cheat_re = qr/[^$Ctl$Space$Specials_cheat]+/;

# Build quoted string regex
use vars qw($Qtext_re $Qpair_re $Quoted_string_re);
$Qtext_re = '[^"\\\r]+';      # " #
$Qpair_re = qr/\\[$Char]/;
$Quoted_string_re = qr/"(?:$Qtext_re|$Qpair_re)*"/;

# Build domain regex.
use vars qw($Domain_ref_re $Dtext_re $Domain_literal_re $Sub_domain_re
            $Domain_ref_cheat_re $Sub_domain_literal_cheat_re
            $Domain_literal_cheat_re
           );
$Domain_ref_re = $Atom_re;
$Dtext_re = qr/[^\[\]\\\r]/;
$Domain_literal_re = qr/\[(?:$Dtext_re|$Qpair_re)*\]/;
$Sub_domain_re = "(?:$Domain_ref_re|$Domain_literal_re)";
$Domain_ref_cheat_re = $Atom_cheat_re;

$Sub_domain_literal_cheat_re = "(?:$Dtext_re|$Qpair_re)*";
$Domain_literal_cheat_re = qr/\[$Sub_domain_literal_cheat_re\]/;

# Build local part regex.
use vars qw($Word_re $Local_part_re $Local_part_cheat_re);
$Word_re = "(?:$Atom_re|$Quoted_string_re)+";
$Local_part_re = qr/$Word_re(?:\.$Word_re)*/;
$Local_part_cheat_re = qr/(?:$Atom_cheat_re|$Quoted_string_re)+/;

# Finally, the address-spec regex (more or less)
use vars qw($Addr_spec_re);
$Addr_spec_re = qr/$Local_part_cheat_re\@
                       (?:$Domain_ref_cheat_re|
                          $Domain_literal_cheat_re)
                  /x;


sub find_emails (\$&) {
    my($r_text, $callback) = @_;

    my $emails_found = 0;

    $$r_text =~ s{($Addr_spec_re)}{
        my($orig_match) = $1;

        # XXX Add cruft handling.

        if( my $email = Mail::Address->new('',$orig_match) ) {
            $emails_found++;

            # XXX Don't forget the cruft.
            $callback->($email, $orig_match);
        }
        else {
            # XXX Again with the cruft!
            $orig_match;
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
and usenet message IDs.  I do my best to avoid them, but there's only
so much cleverness you can pack into one library.

=item This module requires 5.005_63 or higher!

This module runs so slow as to be unusable with 5.005 stable.  I'm not
sure, but it might be because I build up my search regex using lots of
compiled regexes.  Either way, it runs orders of magnitude faster
under 5.005_63.

Perhaps in later versions I'll be able to tweak it to be efficient
with 5.005 stable.

=back

=head1 AUTHOR

Michael G Schwern <schwern@pobox.com>


=head1 SEE ALSO

  L<Email::Valid>, RFC 822, L<URI::Find>

=cut
