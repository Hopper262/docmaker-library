use strict;

# Bootstrapping die message, in case requires fail
sub early_die
{
  return if $^S;
  print <<END;
Content-type: text/plain

Died: $_[0]

END
#   for my $var (sort keys %ENV)
#   {
#     print "$var = $ENV{$var}\n";
#   }
}
$SIG{__DIE__} = \&early_die;


# figure out root
our $ROOT = $ENV{'USEROOT'} || $0 || '';
$ROOT =~ s/^$ENV{'DOCUMENT_ROOT'}//;
$ROOT =~ s|/[^/]+$||;
{
  my $foo = __FILE__;
  while ($foo =~ /^\.\./) {
    $foo =~ s|^\.\./||;
    $ROOT =~ s|/[^/]+$||;
  }
}
our $FULLROOT = 'http://' . $ENV{'HTTP_HOST'} . $ROOT;
our $FILEROOT = $ENV{'DOCUMENT_ROOT'} . $ROOT;
our $CONTENTROOT = "$FILEROOT/files";

# constant strings
our $STYLE = $ROOT . '/style';

#scripts
our $HOME_URL = "$ROOT/";
our $UPLOAD_URL = "$ROOT/upload";
our $FILE_URL = "$ROOT/files";
our $ARCHIVE_URL = "$ROOT/files/";
our $HELP_URL = "$ROOT/help";

# ph/subs files
require "$FILEROOT/modules/db.ph";
require "$FILEROOT/modules/db.subs";
require "$FILEROOT/modules/docmaker.subs";
require "$FILEROOT/modules/page.subs";
require "$FILEROOT/modules/document.subs";

# end file
1;
