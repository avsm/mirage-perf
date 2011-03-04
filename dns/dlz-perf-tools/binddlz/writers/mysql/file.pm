package binddlz::writers::mysql::file;
require Exporter;

@ISA = qw(Exporter);

# export methods
@EXPORT = qw(getParameters, init, cleanup, addRecord);
  
# forward declaration of private methods
sub mysql_fix;

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
      $tmp .= "binddlz::writers::mysql::file writer\n";
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
   print $file ("\tzone text,\n");
   print $file ("\thost text,\n");
   print $file ("\tttl int(11) default NULL,\n");
   print $file ("\ttype text,\n");
   print $file ("\tmx_priority text,\n");
   print $file ("\tdata text,\n");
   print $file ("\tresp_person text,\n");
   print $file ("\tserial bigint(20) default NULL,\n");
   print $file ("\trefresh int(11) default NULL,\n");
   print $file ("\tretry int(11) default NULL,\n");
   print $file ("\texpire int(11) default NULL,\n");
   print $file ("\tminimum int(11) default NULL,\n");
   print $file ("\tINDEX zone_host_index (zone(30), host(20)),\n");
   print $file ("\tINDEX type_index (type(8))\n");
   print $file (") TYPE=MyISAM;\n\n");
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
   my $zone = mysql_fix($zone, "'");
   my $host = mysql_fix($host, "'");
   my $ttl = mysql_fix($ttl);
   my $type = mysql_fix($type, "'");
   my $mx_priority = mysql_fix($mx_priority);
   my $data = mysql_fix($data, "'");
   my $adminEmail = mysql_fix($adminEmail, "'");
   my $serial = mysql_fix($serial);
   my $refresh = mysql_fix($refresh);
   my $retry = mysql_fix($retry);
   my $expire = mysql_fix($expire);
   my $minimum = mysql_fix($minimum);

      # write out SQL for this record
   print $file ("INSERT INTO dns_records VALUES (");
   print $file ("$zone, $host, $ttl, $type, $mx_priority, $data, ");
   print $file ("$adminEmail, $serial, $refresh, $retry, $expire, $minimum");
   print $file (");\n");

}

   # cleanup this instance after writing DNS data
sub cleanup() {
   # for mysql don't do anything.

   # Don't close output file.
   # Perl does automatically when the program completes.
}

   # converts zero length strings to the word NULL that postgres SQL
   # statements expect.  If a second argument is supplied wrap input
   # string with that argument.
sub mysql_fix {
   $in = shift;
   $wrap = shift;

   if (length($in) < 1) {
      return "NULL";
   }
   return "${wrap}${in}${wrap}";
}

# last line of a perl module must be 1;
1;
