package My::DB::Sth;
use strict;
use warnings 'FATAL' => 'all';
no warnings 'redefine';

## The documentation for My::DB::Sth is grouped with
## the My::DB documentation below.

BEGIN {
  use Exporter ();
  use DBI ();
  
  # load DBD::mysql without strict in effect
  {
    no strict;
    use DBD::mysql;
  }
 
  our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
  
  $VERSION = '1.57';
  @ISA = qw(Exporter);
  @EXPORT = qw();
  @EXPORT_OK = qw();
  %EXPORT_TAGS = ();
}
our @EXPORT_OK;


## new is the constructor

sub new
{
  my ($class, $parent, $sql, $outputvars) = @_;
  
  my $self = bless {}, $class;
  
  $self->{'Parent'} = $parent;
  $self->{'SQL'} = $sql;
  $self->{'OutVars'} = $outputvars;
  
  return $self;
} # end new


## _bind creates and executes a statement

sub _bind
{
  my ($self, $bindvars) = @_;
    
  # Create statement handle
  my $parent = $self->{'Parent'}
    or return undef;
  my $dbh = $parent->_dbi()
    or return undef;
  my $sth = $dbh->prepare($self->{'SQL'});
  unless ($sth)
  {
    $parent->_error($dbh->errstr, $self->{'SQL'});
    return undef;
  }
  $self->{'STH'} = $sth;
  
  # Bind any input vars and execute
  my @bind = $self->_bind_array($sth->{'NUM_OF_PARAMS'}, $bindvars);
  my $result;
  unless ($result = $sth->execute(@bind))
  {
    if ($sth->errstr =~ 'Lost connection to MySQL server during query')
    {
      ## retry for this error
      unless ($sth = $dbh->prepare($self->{'SQL'}))
      {
        $parent->_error($dbh->errstr, $self->{'SQL'});
        return undef;
      }
      $self->{'STH'} = $sth;
      unless ($result = $sth->execute(@bind))
      {
        $parent->_error($sth->errstr, $self->{'SQL'});
        return undef;
      }
    }
    else
    {
      $parent->_error($sth->errstr, $self->{'SQL'});
      return undef;
    }
  }
  
  # We might be a write-only statement
  unless ($sth->{'NUM_OF_FIELDS'} && $self->{'OutVars'})
  {
    return $dbh->{'mysql_insertid'} || $result;
  }
  
  # we'll have output, bind output variables
  my @out = $self->_out_array($sth->{'NUM_OF_FIELDS'}, $self->{'OutVars'});
  unless ($sth->bind_columns(@out))
  {
    $parent->error($sth->errstr, $self->{'SQL'});
    return undef;
  }
  return $result;
} # end _bind


## rebind reloads the statement with new bind variables

sub rebind
{
  my ($self, @bindvars) = @_;

  if (scalar(@bindvars) == 1 &&
      ref($bindvars[0]) eq 'ARRAY')
  {
    return $self->_bind($bindvars[0]);
  }
  return $self->_bind(\@bindvars);
} # end rebind


## fetch retrieves one row of data into
## the predefined output variables

sub fetch
{
  my ($self) = @_;
  
  my $sth = $self->{'STH'}
    or return undef;
  my $result = $sth->fetchrow_arrayref();
  if (!$result && $sth->err)
  {
    $self->{'Parent'}->_error($sth->errstr, $self->{'SQL'});
  }
  return $result ? 1 : 0;
}

## finish is rarely needed

sub finish
{
  my ($self) = @_;
  
  if ($self->{'STH'})
  {
    $self->{'STH'}->finish();
    $self->{'STH'} = undef;
  }
  
  # make sure we aren't keeping stray connections alive
  $self->{'Parent'} = undef;
} # end finish


## Bind input variables to data

sub _bind_array
{
  my ($self, $ct, $aryref) = @_;
  
  # no input variables in statement
  return () unless $ct;
  
  # no data given
  return (map(undef, 1..$ct)) unless defined $aryref;
  
  # one data item without indirection
  return ($aryref, map(undef, 2..$ct)) unless ref($aryref) eq 'ARRAY';
  
  # multiple data items in array reference
  return (@$aryref[0..($ct - 1)]);
} # end _bind_array
  

## Transform output references into DBI-friendly form

sub _out_array
{
  my ($self, $ct, $aryref) = @_;
  
  # no output from statement
  return () unless $ct;
  
  # no refs to hold output
  return (map(undef, 1..$ct)) unless defined $aryref;
  
  # one direct scalar reference, to hold one output
  return ($aryref, map(undef, 2..$ct)) unless ref($aryref) eq 'ARRAY';
  
  # array of references
  return (@$aryref[0..($ct - 1)]) if ref($aryref->[0]);
  
  # array to be filled out -- create references for each array position
  return (map +( \$aryref->[$_] ), 0..($ct-1));
} # end _out_array


## destructor

sub DESTROY
{
  my ($self) = @_;
  
  $self->finish();
} # end DESTROY


package My::DB;
use strict;
use warnings 'FATAL' => 'all';
no warnings 'redefine';

=head1 NAME

My::DB - Interact with a MySQL database

My::DB::Sth - Statement objects created by My::DB

=head1 SYNOPSIS

    use My::DB;

    # error routine for database problems
    sub myErrRoutine
    {
      my ($err, $sql) = @_;
      print "Error occurred: $err, $sql\n";
    }

    my $db = My::DB->new('mydb@data22', 'user', 'pass', \&myErrRoutine);

    # standard select loop
    my ($fld1, $fld2);
    my $st = $db->bind(
                'SELECT * FROM foo WHERE bar = ?',
                [ 'baz' ],
                [ \$fld1, \$fld2 ]);
    while ($st->fetch())
    {
      print $fld1 . ', ' . $fld2 . "\n";
    }
    $st->finish();

    # ...or...
    my $st2 = $db->bind(
                'SELECT fld2 FROM foo WHERE bar = ?',
                'baz',
                \$fld2);
    while ($st2->fetch())
    {
      print $fld2 . "\n";
    }
    $st2->finish();

    # ...or....
    my $st3 = $db->bind(
                'SELECT * FROM foo WHERE bar = ?',
                'baz',
                \@output);
    while ($st3->fetch())
    {
      print join(', ', @output) . "\n";
    }
    $st3->finish();

    # convenience routines
    $db->do('INSERT INTO foo VALUES (?, ?)', [ 'a', 'b' ]);
    $db->select('SELECT COUNT(*) FROM foo', undef, \$count);

    # batch fetching
    my @rows = $db->fetchAll(
                'SELECT * FROM foo WHERE bar = ?',
                'baz');
    for $colref (@rows)
    {
      print join(', ', @$colref) . "\n";
    }

    # reusing statements
    @output = ();
    my $st4 = $db->prebind(
                'SELECT * FROM foo WHERE bar = ?',
                \@output);
    for $val (@barvalues)
    {
      $st4->rebind($val);
      print 'Foo output when bar = ' . $val . "\n";
      while ($st4->fetch())
      {
        print join(', ', @output) . "\n";
      }
    }
    $st4->finish();

    $db->disconnect();

=head1 DESCRIPTION

My::DB is a wrapper for DBI, to aid in error checking and
efficient programming practices.  All database actions are checked
for errors, notifying a user-defined callback when necessary, without
requiring extra client effort.  The API encourages the use of
bind variables and output variable binding, which can improve the
efficiency of the code and promotes statement reuse.

=head2 BIND VARIABLES

SQL statements are allowed to contain placeholders for data values.
These placeholders are indicated by a question mark (?) in the
statement text.  The values can be supplied separately, to several
My::DB methods.  In every method, bind variables can be specified
in several ways:

- If more than one bind variable is used, an array reference must be
passed to the routine.  This can be done using square brackets, or
it can be a hard reference to a predefined array.  (Update: this is
not necessary for C<do()>, C<rebind()>, or C<fetchAll()>: for these
routines, you can just pass bind variables as extra parameters.)

- If only one bind variable is used, it can be passed directly to the
routine.  There is no need to write C<['a']> to pass a single bind
variable; simply passing C<'a'> will work just as well.

- If the statement uses no bind variables at all, C<undef> can be
passed as the parameter.

=head2 OUTPUT VARIABLES

DBI, which is used as the engine underneath My::DB, is much more
efficient when rows can be directly fetched into their final
destinations.  To encourage this efficiency, My::DB requires
that database results be retrieved by providing references to
variable storage.

For each field that will be retrieved by a query, a corresponding
variable must exist.  References to each of these variables can be
provided within an array reference.  For example, to fetch results
into C<$foo>, C<$bar>, and C<$baz>, pass the array reference
C<[ \$foo, \$bar, \$baz ]> as the parameter for output variables.

Shortcuts exist for some common cases:

- If only one field is returned, a reference C<\$foo> can be provided
directly.

- To retrieve all fields of a single row into an array, C<\@output>
can be provided instead of C<[ \$output[0], \$output[1], ... ]>.
This is useful when the total number of fields returned by the SQL
is unknown.  The contents of C<@output> will be overwritten with the
current row each time C<fetch()> is called.

- If no output will be returned from the statement, C<undef> can be
passed as the parameter.

=head1 PREREQUISITES

My::DB currently requires DBI.  My::DB is intended as
a complete wrapper over DBI, so that My::DB may be rewritten
using another access package without requiring the rewriting
of any client code.

=cut

BEGIN {
  use Exporter ();
  use DBI ();
  
  our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
  
  $VERSION = '1.56';
  @ISA = qw(Exporter);
  @EXPORT = qw();
  @EXPORT_OK = qw();
  %EXPORT_TAGS = ();
}
our @EXPORT_OK;

=head1 USAGE

=head2 DATABASE METHODS

=over 4

=item C<My::DB->($db, $user, $pw, $err_func)>

This routine creates a DB object.  The first three parameters
are a database name, user, and password for connection to a
MySQL database.  If the database name is in the form:

  database@host

then a connection will be made to the remote hostname <host>.

If you have redundant database servers, you can specify them
with the form:

  database@host1|host2

Only two hosts are supported at the moment. The same user, database,
and password will be tried for host2 if the connection to host1
fails.

If the host starts with "SOCK:", the DBI connection string will pass
the parameter as "mysql_socket=..." instead of "host=...".

The fourth parameter is an optional reference to an error
routine.  If used, the routine will be called with an error
message and any relevant SQL statement whenever an error occurs.

=cut

sub new
{
  my ($class, $db, $user, $pw, $err_func) = @_;
  my ($self);
  
  $self = bless {}, $class;
  
  $self->{'ERR'} = $err_func;
  my $host = 'localhost';
  if ($db =~ s/\@(.+)//)
  {
    $host = $1;
  }
  $self->{'DatabaseParam'} = "$user:$db\@$host";
  if ($host =~ /\|/)
  {
    my ($primary, $secondary) = split(/\|/, $host);
    $host = $secondary;
    
    my $conn = 
    $self->{'PrimaryConnStrings'} = [ "dbi:mysql:database=$db;" . $self->_mungehost($primary), $user, $pw ];
  }
  $self->{'ConnStrings'} = [ "dbi:mysql:database=$db;" . $self->_mungehost($host), $user, $pw ];
  $self->{'DBI'} = undef;
  
  return $self;
} # end new

## _mungehost forms the correct connection
## string based on the host format (to handle
## socket connections).

sub _mungehost
{
  my ($self, $hoststr) = @_;
  
  if ($hoststr =~ s/^SOCK://)
  {
    return 'mysql_socket=' . $hoststr;
  }
  return 'host=' . $hoststr;
} # end _mungehost


## _dbi is an internal routine
## to establish the DBI connection, if
## we haven't already done so, and
## retrieve the DBI handle.

sub _dbi
{
  my ($self) = @_;
  my ($dbh, @params);
  
  $dbh = $self->{'DBI'};
  if (!defined $dbh)
  {
    my @connerr;
    if ($self->{'PrimaryConnStrings'})
    {
      @params = @{$self->{'PrimaryConnStrings'}};
      $params[0] .= ';mysql_connect_timeout=5';
      $dbh = DBI->connect(@params);
      @connerr = (DBI->errstr, $params[0]) unless $dbh;
    }
    if (!defined $dbh)
    {
      @params = @{$self->{'ConnStrings'}};
      $dbh = DBI->connect(@params)
        or $self->_error(DBI->errstr, join(',', @params));
      $self->_conn_error(@connerr) if $dbh;
    }
    ## make sure we're getting auto reconnect
    $dbh->{'mysql_auto_reconnect'} = 1;
    $dbh->do('SET NAMES utf8');
    $self->{'DBI'} = $dbh;
  }
  
  return ($dbh);
} # end _dbi


## _conn_error reports connection errors
## when the secondary connection succeeds.

sub _conn_error
{
  my ($self, $err, $conn) = @_;
  
  return unless $err;
  
  my $log;
  open($log, '>>', $ENV{'ONETROOT'} . '/logs/DB_conn_error.log') or return;
  my $time = localtime time;
  print $log <<END;
$time :!: $conn :!: $err
END
  close $log;
} # end _conn_error

=item C<connection()>

Returns the database connection information passed
to C<new()>, in the form C<user:db@host>.
Useful for comparing multiple objects to see if they
refer to the same database.

=cut

sub connection
{
  my ($self) = @_;
  return $self->{'DatabaseParam'};
} # end connection

## _error calls the user-defined error
## routine and sets the error flag.

sub _error
{
  my ($self, $err, $sql) = @_;
  my ($err_func);
  
  $err_func = $self->{'ERR'};
  if (defined $err_func)
  {
    &$err_func($err, $sql);
  }

  $self->{'ERR_FLAG'} = $err;
} # end _error


=item C<error()>

This routine returns the last error message if an
error occurred, or C<undef> if no error has occurred.
The error message is cleared only when C<error()> is
called, not when a DBI call succeeds; you can call
multiple methods before checking the error status.

  exit if $db->error();

=cut

sub error
{
  my ($self) = @_;
  my ($msg);
  
  $msg = $self->{'ERR_FLAG'};
  if (defined $msg)
  {
    $self->{'ERR_FLAG'} = undef;
  }
  return $msg;
} # end error


=item C<errorHandler($err_func)>

This routine allows you to change the error routine
called by My::DB.  If defined, the routine will
be called with an error message and any relevant SQL
statement whenever an error occurs.

When called without a parameter, it returns a
reference to the currently used handler.  When called
with undef, it unsets the handler.

  $oldHandler = $db->errorHandler();
  $db->errorHandler(\&MyNewErrRoutine);
  ...
  $db->errorHandler($oldHandler);

=cut

sub errorHandler
{
  my ($self) = shift @_;
  
  if (!scalar @_)
  {
    return $self->{'ERR'};
  }
  else
  {
    $self->{'ERR'} = $_[0];
  }
} # end errorHandler


=item C<bind($sql, $bindvars, $outputvars)>

This routine creates a statement object,
ready for use in a C<fetch()> loop.

  $st = $db->bind($sql, [ $bind1, $bind2 ], \@output);

=cut

sub bind
{
  my ($self, $sql, $bindvars, $outputvars) = @_;
  
  my $sth = My::DB::Sth->new($self, $sql, $outputvars)
    or return undef;
  $sth->_bind($bindvars)
    or return undef;
  return $sth;
} # end bind


=item C<do($sql, $bindvars)>

This routine executes a SQL statement without a return
value.  It combines C<bind()> and C<fetch()>, ignoring
output.

  $db->do($updateSql, $bind1, $bind2);

=cut

sub do
{
  my ($self, $sql, @bindvars) = @_;
  
  my $sth = My::DB::Sth->new($self, $sql)
    or return undef;
    
  if (scalar(@bindvars) == 1 &&
      ref($bindvars[0]) eq 'ARRAY')
  {
    return $sth->_bind($bindvars[0]);
  }
  my $ret = $sth->_bind(\@bindvars);
  $sth->finish();
  return $ret;
} # end do


=item C<select($sql, $bindvars, $outputvars)>

This routine executes a single-line SQL statement.
It combines C<bind()> and C<fetch()>, retrieving
the first row of data into the given output variables.

  $db->select($sql, \@binds, \@output);
  print join(', ', @output);

You can also leave C<$outputvars> off to get the
output returned, like so:

  my @output = $db->select($sql, \@binds);

=cut

sub select
{
  my ($self, $sql, $bindvars, $outputvars) = @_;
  
  my $immediate = 0;
  unless ($outputvars)
  {
    $immediate = 1;
    $outputvars = [];
  }
  my $sth = My::DB::Sth->new($self, $sql, $outputvars)
    or return undef;
  $sth->_bind($bindvars)
    or return undef;
  my $ret = $sth->fetch();
  $sth->finish();
  if ($immediate)
  {
    return wantarray ? @$outputvars
                     : $outputvars->[0];
  }
  return $ret;
} # end select


=item C<prebind($sql, $outputvars)>

If a statement will be used multiple
times with different bind variables, it
can be created with this method.
The C<rebind()> method
must be called on the object, setting the
appropriate bind variables, before it can
be used with C<fetch()>.

  $st = $db->prebind($sql, \@output);
  for $i (@binds)
  {
    $st->rebind($i);
    ...
  }
  $st->finish();

=cut

sub prebind
{
  my ($self, $sql, $outputvars) = @_;
  
  return My::DB::Sth->new($self, $sql, $outputvars);
} # end prebind


=item C<quote($val)>

This routine quotes the given data value for
inclusion in a SQL statement. The return value
includes the outer quotes.

=cut

sub quote
{
  my ($self, $val) = @_;
  
  my $dbh = $self->_dbi();
  if (defined $dbh)
  {
    return $dbh->quote($val);
  }
  return undef;
} # end quote


=item C<disconnect()>

This routine ends the current database session.
Its use is optional, everything should be cleaned
up when the object is destroyed.

=cut

sub disconnect
{
  my ($self) = @_;
  
  my $dbh = $self->{'DBI'};
  if (defined $dbh)
  {
    $dbh->disconnect();
    $self->{'DBI'} = undef;
  }
} # end disconnect


## destructor

sub DESTROY
{
  my ($self) = @_;
  
  $self->disconnect();
} # end DESTROY


=back

=head2 STATEMENT OBJECT METHODS

=over 4

=item C<fetch()>

This routine retrieves the next row of data from the
object's query.  The data is provided in the output
variables previously specified. It returns false when
no more rows are available.

=item C<finish()>

This routine ends the row retrieval process.  Calling
this method is not required; it can improve efficiency
when the remaining rows of a query will not be fetched.

=item C<rebind($bindvars)>

To restart a query with a different set of bind
variables, use this routine.  Statement objects can
be reused with different bind variables, to execute
repetitive queries.

The bind variables may be passed in any of three ways:
as an array reference, as an anonymous array, or as
multiple parameters to the routine.

     $st->rebind(\@binds);
     $st->rebind([$bind1, $bind2]);
     $st->rebind($bind1, $bind2);

=back

=head1 VERSION HISTORY

=over 4

=item Version 1.57 - 9 January 2012

Add mysql_socket option.

=item Version 1.56 - 25 June 2011

Use UTF-8 for talking to server.

=item Version 1.55 - 25 November 2007

Internal change to log certain connection errors.

=item Version 1.54 - 27 September 2007

Added immediate mode to C<select()>.

=item Version 1.53 - 18 September 2007

Added C<quote()>.

=item Version 1.52 - 6 July 2007

Use warnings.

=item Version 1.51 - 29 June 2007

Added C<connection()> routine.

=item Version 1.50 - 3 October 2006

Substantial rewrite, but few API changes (removed some
unused utility routines).

=item Version 1.22 - 6 September 2005

Name change from My::DBmysql back to My::DB (bye, Oracle).

=item Version 1.21 - 13 December 2004

Hmm, seemed to have forgotten about the version updates...
lots of changes for the move to MySQL.

=item Version 1.20 - 24 February 2003

Added C<error()> and C<errorHandler()> routines.

=item Version 1.10 - 21 January 2003

Added C<fetchAll()>; made some of the routines more
intelligent in parsing their parameters.

=item Version 1.00 - 30 October 2002

Initial release.

=back

=head1 AUTHOR

Jeremiah Morris, jm@whpress.com

=head1 COPYRIGHT

Copyright 2002-2012 Jeremiah Morris. All rights reserved.

=cut

1;
