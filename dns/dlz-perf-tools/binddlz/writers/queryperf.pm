package binddlz::writers::queryperf;
require Exporter;

@ISA = qw(Exporter);

# export methods
@EXPORT = qw(getParameters, init, cleanup, addRecord);
  
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
      $tmp .= "binddlz::writers::queryperf writer\n";
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
   
   # no header is output for queryperf
}

   # add "write" a DNS record.
sub addRecord {
   my $this = shift;
   local (*zone, *host, *ttl, *type, *mx_priority,
       *data, *adminEmail, *serial, *refresh,
       *retry, *expire, *minimum) = @_;

      # get the filehandle to write to.
   my $file = $this->{'filehandle'};

      # write out this record
   if($host ne "@"){
      print $file ("${host}.");
   }
      print $file ("${zone} ${type}\n");
}

   # cleanup this instance after writing DNS data
sub cleanup() {
   # no cleanup is needed for queryperf
   
   # Don't close output file.
   # Perl does automatically when the program completes.
}

# last line of a perl module must be 1;
1;
