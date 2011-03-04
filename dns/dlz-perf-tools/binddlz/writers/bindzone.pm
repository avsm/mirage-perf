package binddlz::writers::bindzone;
require Exporter;

@ISA = qw(Exporter);

# export methods
@EXPORT = qw(getParameters, init, cleanup, addRecord);
  
# forward declaration of private methods
sub mkdirR;
sub openZoneFile;
sub genZoneFilePath;

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

      # The "base" parameter is the base directory we should write to.
   my $base = $params{"base"};
   my $pathSep = $base;

      # verify a base was passed.
   if(length($base) < 1){
      my $tmp = "A \"base\" parameter must be supplied to the\n";
      $tmp .= "binddlz::writers::bindzone writer\n";
      die $tmp;
   }

      # attempt to determine path separator, and store in this "instance".
   $pathSep =~ s/.*([\\\/]).*/$1/;
   if(length($pathSep) != 1){
      die "Could not determine path separator.\n";
   }
   $this->{'pathSep'} = $pathSep;

      # if $base has ending "/" or "\" get rid of it.
   $base =~ s/[\\\/]$//;

      # attempt to create base directory, die if we can't
   if($base !~ /[ \t]*\|/){
      mkdirR($base) ||
         die ("Directory ${base} doesn't exist and could not be created.\n");
   } else {
      die ("The binddlz::writers::bindzone writer does not support piping.\n");
   }
  
      # store the base in this instance so we can use it later.      
   $this->{'base'} = $base;

   # create a named.conf file.
   open($file, ">" . $base . $pathSep . "named.conf-data") ||
      die "binddlz::writers::bidnzone could not open\n" .
          "'${base}${pathSep}named.conf' for writing\n";

   $this->{'named.conf'} = $file;
}

   # add "write" a DNS record.
sub addRecord {
   my $this = shift;
   local (*zone, *host, *ttl, *type, *mx_priority,
       *data, *adminEmail, *serial, *refresh,
       *retry, *expire, *minimum) = @_;

      # get the base to write to.
   my $base = $this->{'base'};
      
      # get path separator.
   my $pathSep = $this->{'pathSep'};

      # get named.conf file handle
   my $namedFile = $this->{'named.conf'};

      # get the zone file handle for the last one we worked on.
   my $zoneFile = $this->{'zoneFile'};

      # get the name of the zone we last worked on.
   my $lastZone = $this->{'lastZone'};   

      # if we don't already have a zoneFile open, this is the
      # first time through, so open one.
   if(!$zoneFile){
      $zoneFile = openZoneFile($pathSep,
                  genZoneFilePath($base, $pathSep, $zone),
                  $zone . ".db", $zoneFile);
   }

      # if we have a lastZone (not first time through) AND it is 
      # not the same as the one we are working on now, open a new
      # zoneFile, and add a new entry to named.conf file.
   if($lastZone ne $zone){
      $zoneFile = openZoneFile($pathSep,
                  genZoneFilePath($base, $pathSep, $zone),
                  $zone . ".db", $zoneFile);

            # write new entry to named.conf file.
         print $namedFile ("zone \"${zone}\" {\n");
         print $namedFile ("\ttype master;\n");
         print $namedFile ("\tfile \"" .
            genZoneFilePath($base, $pathSep, $zone) . $pathSep . $zone .
            ".db\";\n");
         print $namedFile ("\tnotify no;\n");
         print $namedFile ("};\n\n");
   } # close if($lastZone && $lastZone ne $zone)

      # write entry to zoneFile.
   print $zoneFile ("${host}\t${ttl}\tIN\t${type}\t");
   if($type eq "mx"){
      print $zoneFile ("${mx_priority} ");
   }
   print $zoneFile ("${data}");
   if($type eq "soa"){
      print $zoneFile (" ${adminEmail} ${serial} ${refresh} ${retry} ");
      print $zoneFile ("${expire} ${minimum}");
   }
   print $zoneFile ("\n");

      #store zoneFile to use next time.
   $this->{'zoneFile'} = $zoneFile;

      #store lastZone to compare with next time.
   $this->{'lastZone'} = $zone;
}

   # cleanup this instance after writing DNS data
sub cleanup() {
   # no cleanup needed for zoneFile
}

   # closes current zone file handle if one is open.
   # then opens a new one for writing, and returns it.
sub openZoneFile {
   my $pathSep = shift;
   my $path = shift;
   my $fileName = shift;
   my $file = shift;

      # close old file
   if($file){
      close($file);
   }

      # make sure directory exists
   mkdirR($path);

      # open new file for writing
   open($file, ">" . $path . $pathSep . $fileName) ||
      die "binddlz::writers::bidnzone could not open zone file\n" .
          "'${path}${pathSep}${fileName}' for writing\n";

   return $file;
}

   # constructs a zone file path
sub genZoneFilePath {
   my $base = shift;
   my $pathSep = shift;
   my $name = shift;

   my $path = $base . $pathSep . substr($name, 0, 1) . $pathSep . substr($name, 0, 2);
   
   return $path;
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
