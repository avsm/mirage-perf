#! /usr/bin/perl

require "flush.pl";
use FindBin;
use lib "$FindBin::Bin";

   # declare functions we implement later.
sub addRecord;
sub initWriter;
sub cleanupWriters;
sub readConfig;
sub genZone;
sub genHost;
sub getName;
sub resetFields;
sub getTLD;

# begin main program

      # global vars
   my @writers; # list of all writers to use during DNS data generation.
   my $conf;    # handle to configuration file.
   my $writer;  # name of writer obtained from conf file to initialize.
   my $zones;   # number of zone files to generate.
   my @hosts;   # list of the number of hosts to generate in a zone.
   my $hostsIDX = 0; # index into which host we are working on / last worked on.
   my $inputfile; # dictionary input file to use in creating host / zone names.
   my $inputfileCnt = 0; # how many times the input file has been looped through.
   my @tlds = (".com", ".net", ".org");   # top level domains.
      # used in generating host / zone entries.
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
      $tmp .= "Usage: dnsDataGen.pl ConfigFile\n";
      die $tmp;
   }
      
      # read configuration first.
      # this also initializes all the writers.
   readConfig();

      # seed the random number generator.
   srand();

      # tell the user what is going on.
   print "Zones remaining: ";

      # write out all the zones
   while($zones-- > 0){
      print $zones . " ";
      for($k = length($zones) + 1; $k > 0; $k--){
         print "\b";
      }
      flush(STDOUT);
      genZone();
   }

      # all done, shutdown
   cleanupWriters();
	
   print "\n";
# end of main program

   # Generates zones
   # Writes out two NS, an A, MX and SOA record at the zone apex.
   # then calls genHost as many times as determined
   # by "hosts" parameters in the config file.
sub genZone {
   my $i;

   if($hostsIDX >= @hosts){
      $hostsIDX = 0;
   }
       
      # reset fields 
   resetFields();

      # get a zone name
   $zone = getName();
   $zone .= getTLD();

   # We always create data at the zone apex.
   # This data can be referred to from the other generated zones.
   # This will allow the DNS data to be "proper".
   # All zones are "authoritative" for themselves.

      # add records at zone apex
   $host = "@";
   $ttl = 10;
   $type = "ns";
   $data = "ns1." . $zone . ".";

      # adding first NS record
   addRecord(*zone, *host, *ttl, *type, *mx_priority,
          *data, *adminEmail, *serial, *refresh,
          *retry, *expire, *minimum);

   $data = "ns2." . $zone . ".";

      # adding second NS record
   addRecord(*zone, *host, *ttl, *type, *mx_priority,
          *data, *adminEmail, *serial, *refresh,
          *retry, *expire, *minimum);

      
   $type = "mx";
   $mx_priority = "10";
   $data = "${zone}.";

      # adding MX record
   addRecord(*zone, *host, *ttl, *type, *mx_priority,
          *data, *adminEmail, *serial, *refresh,
          *retry, *expire, *minimum);

   $mx_priority = "";
   $type = "a";
   $data = "127.0.0.1";

      # adding A record
   addRecord(*zone, *host, *ttl, *type, *mx_priority,
          *data, *adminEmail, *serial, *refresh,
          *retry, *expire, *minimum);

   $type = "soa";
   $data = "ns1." . $zone . ".";
   $adminEmail = "root." . $zone . ".";

      # these numbers don't really matter.  They are only needed
      # for zone transfers.  We aren't testing the performance of
      # zone transfers.  Infact if you are using DLZ properly you
      # never need zone transfers.
   $serial = 2;
   $refresh = 28000;
   $retry = 2800;
   $expire = 64800;
   $minimum = 10;

      # adding SOA record
   addRecord(*zone, *host, *ttl, *type, *mx_priority,
          *data, *adminEmail, *serial, *refresh,
          *retry, *expire, *minimum);
   
   if($hosts[$hostsIDX] > 10){
      print $zones . ". Hosts remaining: ";
   }

   for($i = $hosts[$hostsIDX]; $i > 0; $i--){
      if($hosts[$hostsIDX] > 10 && ($i % 10) == 0){
         print $i . " ";
         for($l = length($i) + 1; $l > 0; $l--){
            print "\b";
         }
         flush(STDOUT);
      }
      genHost();
   }

   if($hosts[$hostsIDX] > 10){
      for($l = length($zones . ". Hosts remaining: "); $l > 0; $l--){
         print "\b";
      }
      for($l = length($zones . ". Hosts remaining: ") + 3; $l > 0; $l--){
         print " ";
      }
      for($l = length($zones . ". Hosts remaining: ") + 3; $l > 0; $l--){
         print "\b";
      }
   }

   $hostsIDX++;
}

   # Generate host records
   # writes out an A and an MX record for the zone.
sub genHost {

      # reset all fields (except $zone).
   resetFields();

   $ttl = 10;
   $host = getName();
   $type = "a";
   $data = "127.0.0.1";

      # add "a" record
   addRecord(*zone, *host, *ttl, *type, *mx_priority,
          *data, *adminEmail, *serial, *refresh,
          *retry, *expire, *minimum);

   $type = "mx";
   $mx_priority = "10";
   $data = "${zone}.";

      # add "mx" record
   addRecord(*zone, *host, *ttl, *type, *mx_priority,
          *data, *adminEmail, *serial, *refresh,
          *retry, *expire, *minimum);

}
   # Resets all fields except $zone
sub resetFields {
   # Don't reset $zone
   $host = "";
   $ttl = "";
   $type = "";
   $mx_priority = "";
   $data = "";
   $adminEmail = "";
   $serial = "";
   $refresh = "";
   $retry = "";
   $expire = "";
   $minimum = "";
}

   # Generates a unique name
   # Names are generated by obtaining a word from the input file.
   # Then at a random location within the string a number is inserted.
   # The number starts at 0 and is incremented by one each time we
   # need to restart the input file.  The input file is restarted
   # whenever we reach the end of the file.
sub getName{

      # attempt to get line from inputfile.
   my $tmp = <$inputfile>;
   my $offset;

      # make sure we are not at EOF, if so reset and read another line.
      # also increment inputfileCnt.
   if(eof($inputfile)){
      seek($inputfile, 0, 0);
      $tmp = <$inputfile>;
      $inputfileCnt++;
   }

      # remove trailing newline chars.
   $tmp =~ s/\r|\n//g;

      # insert inputfileCnt # at a random location
   $offset = int(rand(length($tmp)));
   $tmp =~ s/.{$offset}/$&$inputfileCnt/;
      
   return $tmp;
}

   # Returns a random Top Level Domain.
sub getTLD {
   return $tlds[int(rand(@tlds))];
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
         if(!$zones || !@hosts || !$inputfile){
            die "All 'zones', 'hosts' and 'inputfile' parameters must be " .
                "specified\nin the configuration before any writers.\n";
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
            if($inputline =~ m/zones:/i){
               if($zones){
                  die "The 'zones' parameter can only be specified once.\n";
               }
                  # set zones
               $zones = $inputline;
               $zones =~ s/zones[ \t]*:[ \t]*//i;

                  # verify zones is a number and is positive.
               if($zones !~ /^[0-9]*$/ || $zones < 1){
                  die "The \"zones\" parameter must be a positive integer\n";
               }
            }elsif($inputline =~ m/hosts:/i){

                  # remove "hosts" key
               $inputline =~  s/.*?:[ \t]*//i;

                  # get left side (how often to repeat)
               $hostsLeft = $inputline;
               $hostsLeft =~ s/[ \t]*:.*//i;

                  # verify hostsLeft is a number and is positive.
               if($hostsLeft !~ /^[0-9]*$/ || $hostsLeft < 1){
                  die "The left portion of the \"hosts\" parameter must " .
                      "be a positive integer\n";
               }

                  # get right size (number of hosts)
               $hostsRight = $inputline;
               $hostsRight =~ s/.*?:[ \t]*//i;

                  # verify hostsRight is a number and is positive.
               if($hostsLeft !~ /^[0-9]*$/ || $hostsLeft < 1){
                  die "The right portion of the \"hosts\" parameter must " .
                      "be a positive integer\n";
               }
                  # add to hosts list
               while($hostsLeft-- > 0){
                  $hosts[$hostsIDX++] = $hostsRight;
               }
            }elsif($inputline =~ m/inputfile:/i){

                  # remove "inputfile" key
               $inputline =~  s/.*?:[ \t]*//i;
                  # attempt to open file
               open($inputfile, $inputline) ||
                  die "Could not open inputfile '$inputline'\n";
            } else {
               die "Only 'zones', 'hosts' and 'inputfile' parameters may\n" .
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
