package binddlz::writers::bdbhpt;
require Exporter;

@ISA = qw(Exporter);

# export methods
@EXPORT = qw(getParameters, init, cleanup, addRecord);
  
# forward declaration of private methods
sub mkdirR;

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

   my $zoneFile, $dataFile, $xfrFile;

      # The "base" parameter is the base directory we should write to.
   my $base = $params{"base"};
   my $pathSep = $base;

      # verify a base was passed.
   if(length($base) < 1){
      my $tmp = "A \"base\" parameter must be supplied to the\n";
      $tmp .= "binddlz::writers::bdbhpt writer\n";
      die $tmp;
   }

      # attempt to determine path separator
   $pathSep =~ s/.*([\\\/]).*/$1/;
   if(length($pathSep) != 1){
      die "Could not determine path separator.\n";
   }

      # if $base has ending "/" or "\" get rid of it.
   $base =~ s/[\\\/]$//;

      # attempt to create base directory, die if we can't
   if($base !~ /[ \t]*\|/){
      mkdirR($base) ||
         die ("Directory ${base} doesn't exist and could not be created.\n");
   } else {
      die ("The binddlz::writers::bdbhpt writer does not support piping.\n");
   }

   # create a zone file.
   open($zoneFile, ">" . $base . $pathSep . "bdb.zone") ||
      die "binddlz::writers::bdbhpt could not open\n" .
          "'${base}${pathSep}bdb.zone' for writing\n";

   $this->{'zoneFile'} = $zoneFile;

   # create a xfr file/
   open($xfrFile, ">" . $base . $pathSep . "bdb.xfr") ||
      die "binddlz::writers::bdbhpt could not open\n" .
          "'${base}${pathSep}bdb.xfr' for writing\n";

   $this->{'xfrFile'} = $xfrFile;

   # create a data file.
   open($dataFile, ">" . $base . $pathSep . "bdb.data") ||
      die "binddlz::writers::bdbhpt could not open\n" .
          "'${base}${pathSep}bdb.data' for writing\n";

   $this->{'dataFile'} = $dataFile;

      # count of how many DNS records have been written
   $this->{'count'} = 1;

}

   # add "write" a DNS record.
sub addRecord {
   my $this = shift;
   local (*zone, *host, *ttl, *type, *mx_priority,
       *data, *adminEmail, *serial, *refresh,
       *retry, *expire, *minimum) = @_;

      # get the data file handle
   my $dataFile = $this->{'dataFile'};

      # get the zone file handle
   my $zoneFile = $this->{'zoneFile'};

      # get the xfr file handle
   my $xfrFile = $this->{'xfrFile'};

      # get the count of how many records we've written
   my $count = $this->{'count'}; 

      # get the name of the zone we last worked on.
   my $lastZone = $this->{'lastZone'}; 

      # get the name of the host we last worked on.
   my $lastHost = $this->{'lastHost'};

      # reverse zone string for zone file.
   my $reverseZone = reverse $zone;

      # if we have a lastZone (not first time through) AND it is 
      # not the same as the one we are working on now add a new
      # entry to zone file.
      # store reversed zone name as key, and no value

   if($lastZone ne $zone){
      printf $zoneFile ("${reverseZone}\n\n");
      $this->{'lastZone'} = $zone;
   }
   
      # write entry to "xfr" secondary db
      # only store unique key/value pairs.
   if($lastHost ne $host || $lastZone ne $zone){
      print $xfrFile ("${zone}\n${host}\n");
      $this->{'lastHost'} = $host;
   }

      # write entry to "data" primary db.
      # use count as replication id.
   print $dataFile ("${zone} ${host}\nREP-ID:${count} ${host} ${ttl} ${type}");

   if($type eq "mx"){
      print $dataFile (" ${mx_priority}");
   }

   print $dataFile (" ${data}");

   if($type eq "soa"){
      print $dataFile (" ${adminEmail} ${serial} ${refresh} ${retry} ");
      print $dataFile ("${expire} ${minimum}");
   }
   print $dataFile ("\n");

      # increment count, and store to use next time.
   $count = $count + 1;
   $this->{'count'} = $count;
}

   # cleanup this instance after writing DNS data
sub cleanup() {
}

   # recursively make directory path
   # Parameter 1 - directory path to be created.
sub mkdirR {
      # get passed in dir name.
   my $dir = shift;
      
      # determine Parent directory
   my $pDir = $dir;
   $pDir =~ s/(.*)([\\\/].*$)/$1/;
   
      # stat dir, if it doesn't exist recursively make its parent.
      # if everything fails horribly, die.
   stat($dir) || (mkdirR($pDir) && mkdir($dir, 0777)) ||
      die ("Could not create directory '${dir}'.\n");;
}

# last line of a perl module must be 1;
1;
