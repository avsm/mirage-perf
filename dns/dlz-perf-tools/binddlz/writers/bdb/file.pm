package binddlz::writers::bdb::file;
require Exporter;

@ISA = qw(Exporter);

# export methods
@EXPORT = qw(getParameters, init, cleanup, addRecord);
  
# forward declaration of private methods
sub bdb_fix;

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
      $tmp .= "binddlz::writers::bdb::file writer\n";
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

      # no header is needed for BDB file.
}

   # add "write" a DNS record.
sub addRecord {
   my $this = shift;
   local (*zone, *host, *ttl, *type, *mx_priority,
       *data, *adminEmail, *serial, *refresh,
       *retry, *expire, *minimum) = @_;

      # get the filehandle to write to.
   my $file = $this->{'filehandle'};
   
      # write out BDB entry for this record
   print $file ("d");
   print $file (bdb_fix($zone));
   print $file (bdb_fix($host));
   print $file (bdb_fix($type));
   print $file (bdb_fix($ttl));
   print $file (bdb_fix($mx_priority));
   print $file (bdb_fix($data));
   print $file (bdb_fix($adminEmail));
   print $file (bdb_fix($serial));
   print $file (bdb_fix($refresh));
   print $file (bdb_fix($retry));
   print $file (bdb_fix($expire));
   print $file (bdb_fix($minimum));
   print $file ("\n");
}

   # cleanup this instance after writing DNS data
sub cleanup() {
   # no cleanup is needed for BDB file.   

   # Don't close output file.
   # Perl does automatically when the program completes.
}

   # converts zero length strings to the word NULL that postgres SQL
   # statements expect.  If a second argument is supplied wrap input
   # string with that argument.
sub bdb_fix {
   $in = shift;

   if (length($in) < 1) {
      return "";
   }
   return " ${in}";
}

# last line of a perl module must be 1;
1;
