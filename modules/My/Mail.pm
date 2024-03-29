package My::Mail;
use strict;
use warnings 'FATAL' => 'all';
no warnings 'redefine';

=head1 NAME

My::Mail - send email

=head1 SYNOPSIS

  use My::Mail;
  
  my $mailer = My::Mail->new('from' => 'me@mydomain.org',
                                'subject' => 'Test email');
  $mailer->set('subject' => 'Changed my mind');
  $mailer->mail('to' => 'you@somecompany.com',
                'msg' => 'Body here.');
  
  &My::Mail::mail('from' => 'me@mydomain.org',
                     'subject' => 'No object needed',
                     'to' => [ 'you@somecompany.com', 'other@elsewhere.org' ],
                     'msg' => 'Body here.',
                     'html' => '<p>HTML alternative here.</p>',);

=head1 DESCRIPTION

My::Mail provides a simple interface to email functions.
It automatically sets some common options
that won't change, like encoding type or SMTP gateway.

You can use the mailer in either an object-oriented mode, where it remembers
the parameters until you call C<mail()> (and you can keep calling C<mail()>
to send more emails), or in a one-shot mode that needs no object.

=head1 PREREQUISITES

My::Mail uses the Email::Sender and Email::MIME modules to do the real work.

=cut

BEGIN {
  use Exporter ();
  use Email::Sender::Simple ();
  use Email::Sender::Transport::SMTP ();
  use Email::MIME ();
    
  our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
  
  $VERSION = '1.10';
    
  @ISA = qw(Exporter);
  @EXPORT = qw();
  @EXPORT_OK = qw();
  %EXPORT_TAGS = ('all' => [@EXPORT_OK]);
}
our @EXPORT_OK;

=head1 USAGE

=over 4

=item C<My::Mail->new(%opts)>

Creates a new C<My::Mail> object, with any of the following options:

=over 4

=item from

The sending mail address.

=item to

The target address. To send to multiple addresses, pass a reference
to a list of addresses.

=item subject

The subject of any emails sent with C<send()>.

=item bcc, cc

These work as expected. See C<to> for info on setting multiple addresses.

=item msg

The body of the emails. Yes, you can set this here and call C<mail()>
without any parameters at all.

=back

=cut

sub new
{
  my ($class, %opts) = @_;
  
  my $self = bless {}, $class;
  my %defaults = &_defaults();
  $self->{'opts'} = \%defaults;
  $self->set(%opts);
  return $self;
} # end new

=item C<set()>

Sets or changes any of the options available in C<new()>. Uses the same
syntax described there.

=cut

sub set
{
  my ($self, %opts) = @_;
  
  foreach my $key (keys %opts)
  {
    $self->{'opts'}{$key} = $opts{$key};
  }
} # end set

=item C<mail()>

Sends an email. Any options passed to C<mail()> will override those passed to
C<new()>, but they aren't used for subsequent emails like C<set()>.

This function returns 1 on success, and C<undef> on error.

=cut

sub mail
{
  my ($self, %opts);
  if (ref $_[0])
  {
    ($self, %opts) = @_;
    foreach my $key (keys %{ $self->{'opts'} })
    {
      $opts{$key} = $self->{'opts'}{$key}
          unless exists $opts{$key};
    }
  }
  else
  {
    (%opts) = @_;
    my %defaults = &_defaults();
    foreach my $key (keys %defaults)
    {
      $opts{$key} = $defaults{$key}
          unless exists $opts{$key};
    }
  }
  
  my @parts;
  if ($opts{'msg'})
  {
    push(@parts, Email::MIME->create(
                    'attributes' => {
                      'content_type' => 'text/plain',
                      'disposition' => 'inline',
                      'encoding' => $opts{'encoding'},
                    },
                    'body_text' => $opts{'msg'}));
  }
  if ($opts{'html'})
  {
    push(@parts, Email::MIME->create(
                    'attributes' => {
                      'content_type' => 'text/html',
                      'disposition' => 'inline',
                      'encoding' => $opts{'encoding'},
                    },
                    'body_text' => $opts{'html'}));
  }
  
  my $email = Email::MIME->create(
                'header_str' => [
                  'From' => $opts{'fake_from'} || $opts{'from'},
                  'To' => $opts{'fake_to'} || $opts{'to'},
                  'Cc' => $opts{'cc'},
                  'Bcc' => $opts{'bcc'},
                ],
                'parts' => [ @parts ]);
  
  eval {
    Email::Sender::Simple::sendmail($email,
      {
        'from' => $opts{'from'},
        'to' => $opts{'to'},
      });
  };
  if ($@) {
    print STDERR "Email::Sender::Simple::sendmail failed: $@";
    return undef;
  }
  return 1;
} # end mail
  

sub _defaults
{
  return ('transport' => Email::Sender::Transport::SMTP->new({}),
          'from' => 'jm@whpress.com',
          'to' => 'jm@whpress.com',
          'encoding' => 'quoted-printable');
} # end _defaults

=back

=head1 VERSION HISTORY

=over 4

=item Version 1.10 - 30 April 2018

Rewrite to use Email::Sender instead of Mail::Sender.

=item Version 1.02 - 9 May 2011

Support for HTML email with optional text alternative.

=item Version 1.01 - 6 July 2007

Use warnings.

=item Version 1.00 - 30 January 2004

Initial release.

=back

=head1 AUTHOR

Jeremiah Morris, jm@whpress.com

=head1 COPYRIGHT

Copyright 2004-2018 Jeremiah Morris.  All rights reserved.

=cut

1;
