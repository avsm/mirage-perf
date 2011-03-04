#! /usr/bin/perl

require "flush.pl";
use FindBin;
use lib "$FindBin::Bin";

   # declare functions we implement later.
sub addRecord;
sub initWriter;
sub cleanupWriters;
sub readConfig;
sub processLine;
sub parse_csv;

# begin main program

      # global vars
   my @writers; # list of all writers to use during DNS data generation.
   my $conf;    # handle to configuration file.
   my $writer;  # name of writer obtained from conf file to initialize.
   my $inputfile; # CSV input file to use in creating host / zone names.
   my $dataLine;
   my $linesProcessed = 0;

      # used in reading / writing host / zone entries.
      # these are global to minimize copying.
   $zone;
   $host;
   $ttl;
   $type;
   $mx_priority;
   $data;
   $adminEmail;
   $serial;
   $refresh;
   $retry;
   $expire;
   $minimum;

      # verify we have 1 command line arg.  Output err msg if not.
   if(@ARGV != 1) {
      my $tmp;
      if(@ARGV < 1){
         $tmp = "A configuration file must be specified on the command line.\n";
      } else {
         $tmp = "Too many command line parameters.\n";
      }
      $tmp .= "Usage: dnsCSVDataReader.pl ConfigFile\n";
      die $tmp;
   }
      
      # read configuration first.
      # this also initializes all the writers.
   readConfig();

      # tell the user what is going on.
   print "Lines processed: ";

      # skip first line, it's headers.
   $dataLine = <$inputfile>;

      # write out all the zones
   while($dataLine = <$inputfile>){
      print "$linesProcessed ";
      for($k = length($linesProcessed) + 1; $k > 0; $k--){
         print "\b";
      }      
      flush(STDOUT);
      $linesProcessed++;
      processLine();
   }

      # all done, shutdown
   cleanupWriters();

   print "\n";
# end of main program

sub processLine(){
         
      # remove trailing newline chars.
   $dataLine =~ s/\r|\n//g;

      # parse CSV
   ($zone, $host, $ttl, $type, $mx_priority,
          $data, $adminEmail, $serial, $refresh,
          $retry, $expire, $minimum) = parse_csv();

      # write DNS record
   addRecord(*zone, *host, *ttl, *type, *mx_priority,
          *data, *adminEmail, *serial, *refresh,
          *retry, *expire, *minimum);
}

   # parses a CSV line into it's fields.
   # found somewhere on the net & modified.
   # originally attributed to Mastering Regular Expressions.
sub parse_csv {
      
      # create array list
   my @new  = ();
      
      # get data
   push(@new, $+) while $dataLine =~ m{"([^\"\\]*(?:\\.[^\"\\]*)*)",? |  ([^,]+),? | ,}gx;

      # return list
   return @new;      # list of values that were comma-separated
}

   # reads configuration file.
   # sets global parameters.
   # initializes writers.
sub readConfig {

   my $inputline;
   my $hostsIDX = 0;
   my $hostsLeft;
   my $hostsRight;

      # open config file, or die if error.
   open ($conf, $ARGV[0]) || die "Could not open file $ARGV[0]\n";
   
      # loop through configuration file one line at a time.
   while ($inputline = <$conf>) {
         # remove any line termination characters.
      $inputline =~ s/[\r]*[\n]*$//;
         
         # remove comments
      $inputline =~ s/#.*$//g;
   
         # remove leading and trailing spaces.
      $inputline =~ s/^[ \t]*//;
      $inputline =~ s/[ \t]*$//;
   
         # skip empty lines
      if(length($inputline) < 1){
         next;
      }


         # search for writer entry
      if($inputline =~ m/writer:/i){
         if(!$inputfile){
            die "The 'inputfile' parameters must be specified\n" .
                "in the configuration before any writers.\n";
         }
            # if we are already working on a writer, this must be a new one
         if(length($writer) > 0){
               # initilize writer we were working on (pass parameters too)
            initWriter($writer, *params);
               # reset parameters for next writer.
            $params = "";
         }
            # set writer to the name of the next one
         $writer = $inputline;
         $writer =~ s/writer[ \t]*:[ \t]*//i;
         
         # did not find writer entry
      } else {
            # check if we are currently working on a writer.
         if(length($writer) > 1){   # working on a writer, this is a parameter
               # key is on left side of :.  Strip whitespace between key & :.
            $key = $inputline;
            $key =~ s/[ \t]*\:.*//;
   
               # value is on right side of :. Strip whitespace between : & value.
            $value = $inputline;
            $value =~ s/.*?:[ \t]*//;
            
               # save parameters to use when we initialize writer.
            $params{"$key"} = $value;
   
         } else { # not working on a writer yet.
               # is this a zone parameter
            if($inputline =~ m/inputfile:/i){

                  # remove "inputfile" key
               $inputline =~  s/.*?:[ \t]*//i;
                  # attempt to open file
               open($inputfile, $inputline) ||
                  die "Could not open inputfile '$inputline'\n";
            } else {
               die "Only the 'inputfile' parameter may\n" .
                   "preceed writer declarations.\n"
            }                                    
         }
      } # ends else of search for writer entry
   } # end of config file input loop
   
      # initialize last writer.
   initWriter($writer, *params);
} # end of readConfig

   # Initializes a single writer.
   #
   # parameter 1 should be the module name to load.
   # all modules should be in a path relative to this 
   # programs path.
   #
   # parameter 2 should be the assoc array of values
   # the module needs to initialize itself.
sub initWriter {
   my $writer = shift;
   local *params = shift;

      # convert colon notation to relative path to module
   $writer =~ s/::/\//g;
   
      # load module
   require "$writer.pm";
   
      # convert relative path back to colon notation
   $writer =~ s/\//::/g;
   
      # create new instance of writer
   $writer = new $writer;

      # initialize writer with parameters.
   $writer->init(*params);

      # add writer to list of writers.
   push (@writers, $writer);
} # end of initWriter

   # loops through all the writers and tells them to cleanup.
sub cleanupWriters {
   my $writer;

   while ($writer = pop(@writers)) {
      $writer->cleanup();
   }
} # end of cleanupWriters

   # loops through all the writers and "writes" the dns record
sub addRecord {
   local (*zone, *host, *ttl, *type, *mx_priority,
       *data, *adminEmail, *serial, *refresh,
       *retry, *expire, *minimum) = @_;

   my $writer;

      # make sure zone, host & type are always lowercase.
   $zone =~ tr/A-Z/a-z/;
   $host =~ tr/A-Z/a-z/;
   $type =~ tr/A-Z/a-z/;

      # addRecord to each writer
   foreach $writer (@writers){   
      $writer->addRecord(*zone, *host, *ttl, *type, *mx_priority,
         *data, *adminEmail, *serial, *refresh,
         *retry, *expire, *minimum);
   }

} # end of addRecord
