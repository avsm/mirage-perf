package binddlz::writers::postgres::file;
require Exporter;

@ISA = qw(Exporter);

# export methods
@EXPORT = qw(getParameters, init, cleanup, addRecord);
  
# forward declaration of private methods
sub pgsql_fix;

   # Constructor.
   # Don't do much, Just return a pointer to this class.
sub new {
   my $this = {};
   bless $this;
   return $this;
}

   # Check parameters are correct and 
   # prepare this instance to write DNS data
sub init {
   my $this = shift;
   local (*params) = @_;

   my $file;

      # The "file" parameter is the filename of the file we should write to.
   my $filename = $params{"file"};

      # verify a filename was passed.
   if(length($filename) < 1){
      my $tmp = "A \"file\" parameter must be supplied to the\n";
      $tmp .= "binddlz::writers::postgres::file writer\n";
      die $tmp;
   }
      
      # attempt to open file or pipe, die if we can't
   if($filename !~ /[ \t]*\|/){
      open($file, ">$filename") ||
         die ("Couldn't open file: ${filename}\n");
   } else {
      open($file, "$filename") ||
         die ("Couldn't pipe to: ${filename}\n");
   }
  
      # store the file handle in this instance so we can
      # write to it later.      
   $this->{'filehandle'} = $file;

      # after the file is opened, write out the "header"
      # this will create the appropriate table
   print $file ("CREATE TABLE dns_records (\n");
   print $file ("\t\"zone\" text,\n");
   print $file ("\thost text,\n");
   print $file ("\tttl integer,\n");
   print $file ("\t\"type\" text,\n");
   print $file ("\tmx_priority integer,\n");
   print $file ("\tdata text,\n");
   print $file ("\tresp_person text,\n");
   print $file ("\tserial integer,\n");
   print $file ("\trefresh integer,\n");
   print $file ("\tretry integer,\n");
   print $file ("\texpire integer,\n");
   print $file ("\tminimum integer\n");
   print $file (");\n\n");

}

   # add "write" a DNS record.
sub addRecord {
   my $this = shift;
   local (*zone, *host, *ttl, *type, *mx_priority,
       *data, *adminEmail, *serial, *refresh,
       *retry, *expire, *minimum) = @_;

      # get the filehandle to write to.
   my $file = $this->{'filehandle'};

      # properly wrap or convert data for the SQL query.
   my $zone = pgsql_fix($zone, "'");
   my $host = pgsql_fix($host, "'");
   my $ttl = pgsql_fix($ttl);
   my $type = pgsql_fix($type, "'");
   my $mx_priority = pgsql_fix($mx_priority);
   my $data = pgsql_fix($data, "'");
   my $adminEmail = pgsql_fix($adminEmail, "'");
   my $serial = pgsql_fix($serial);
   my $refresh = pgsql_fix($refresh);
   my $retry = pgsql_fix($retry);
   my $expire = pgsql_fix($expire);
   my $minimum = pgsql_fix($minimum);

      # write out SQL for this record
   print $file ("INSERT INTO dns_records (\"zone\", host, ttl, \"type\", ");
   print $file ("mx_priority, data, resp_person, serial, refresh, retry, ");
   print $file ("expire, minimum) VALUES (");
   print $file ("$zone, $host, $ttl, $type, $mx_priority, $data, ");
   print $file ("$adminEmail, $serial, $refresh, $retry, $expire, $minimum");
   print $file (");\n");
}

   # cleanup this instance after writing DNS data
sub cleanup() {
   my $this = shift;

      # get the file handle
   my $file = $this->{'filehandle'};

      # tell postgres to create some indexes.   
   print $file ("\n");
   print $file ("CREATE INDEX zone_index ON dns_records USING btree (\"zone\");\n");
   print $file ("CREATE INDEX host_index ON dns_records USING btree (host);\n");
   print $file ("CREATE INDEX type_index ON dns_records USING btree (\"type\");\n");
   print $file ("CREATE INDEX host_zone_index ON dns_records USING btree (\"zone\", host);\n");
 
   # Don't close output file.
   # Perl does automatically when the program completes.
}

   # converts zero length strings to the word NULL that postgres SQL
   # statements expect.  If a second argument is supplied wrap input
   # string with that argument.
sub pgsql_fix {
   $in = shift;
   $wrap = shift;

   if (length($in) < 1) {
      return "NULL";
   }
   return "${wrap}${in}${wrap}";
}

# last line of a perl module must be 1;
1;
