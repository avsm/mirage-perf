package binddlz::writers::filesystem;
require Exporter;

@ISA = qw(Exporter);

# export methods
@EXPORT = qw(getParameters, init, cleanup, addRecord);
  
# forward declaration of private methods
sub mkdirR;
sub mkFile;
sub mangleName;
sub fs_fix;

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

      # The "maxlabel" parameter determines the max length of the
      # zone labels.
   my $maxlabel = $params{"maxlabel"};

      # verify a base was passed.
   if(length($base) < 1){
      my $tmp = "A \"base\" parameter must be supplied to the\n";
      $tmp .= "binddlz::writers::filesystem writer\n";
      die $tmp;
   }

      # verify maxlabel was passed.
   if(length($maxlabel) < 1){
      my $tmp = "A \"maxlabel\" parameter must be supplied to the\n";
      $tmp .= "binddlz::writers::filesystem writer\n";
      die $tmp;
   }
      
      # verify maxlabel is a number and not negative.
   if($maxlabel !~ /^[0-9]*$/ || $maxlabel < 0){
      my $tmp = "The \"maxlabel\" parameter passed to ";
      $tmp .= "binddlz::writers::filesystem writer must be a positive integer\n";
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
      die ("The binddlz::writers::filesystem writer does not support piping.\n");
   }
  
      # store the base in this instance so we can use it later.      
   $this->{'base'} = $base;

      # stire the max lable length in this instance.
   $this->{'maxlabel'} = $maxlabel;

      # no header is needed for filesystem.
}

   # add "write" a DNS record.
sub addRecord {
   my $this = shift;
   local (*zone, *host, *ttl, *type, *mx_priority,
       *data, *adminEmail, *serial, *refresh,
       *retry, *expire, *minimum) = @_;

   my $filename;

      # get the base to write to.
   my $base = $this->{'base'};
      
      # get path separator.
   my $pathSep = $this->{'pathSep'};

      # get the max label length
   my $maxlabel = $this->{'maxlabel'};

      # "*" has special meaning in a file system
      # so if host is "*" use "-" as wild card instead.
   my $host = $host;
   if($host eq "*") {
      $host = "-";
   }

      # use local vars so we don't mess things up.
   my $zone = $zone;
   my $unMangledHost = $host;
      
   $zone = mangleName($zone, $maxlabel, $pathSep);
   $host = mangleName($host, $maxlabel, $pathSep);

      # when names are mangled we must put out a .host~hostname entry.
   if($maxlabel > 0){
      mkFile("${base}${pathSep}${zone}${pathSep}.dns${pathSep}${host}${pathSep}.host~${unMangledHost}");
   }

      # construct file name.
   $filename = "${base}${pathSep}${zone}${pathSep}.dns${pathSep}${host}${pathSep}";
   $filename .= $type;
   $filename .= fs_fix($ttl, "~");
   $filename .= fs_fix($mx_priority, "~");
   $filename .= fs_fix($data, "~");
   $filename .= fs_fix($adminEmail, "~");
   $filename .= fs_fix($serial, "~");
   $filename .= fs_fix($refresh, "~");
   $filename .= fs_fix($retry, "~");
   $filename .= fs_fix($expire, "~");
   $filename .= fs_fix($minimum, "~");
      
      # create file on disk
   mkFile($filename);
}

   # cleanup this instance after writing DNS data
sub cleanup() {
   # no cleanup is needed for filesystem.   
}

   # mangles zone or host names according to rules of BIND-DLZ
   # file system driver.
   # Parameter 1 - zone or host name to be mangled.
   # Parameter 2 - max label length.
   # Parameter 3 - path separator for this system.
sub mangleName {
   my $name = shift;
   my $maxlabel = shift;
   my $pathSep = shift;
   my $mySep;
   my $retVal;

      # if maxlabel is 0, then just split name at labels
   if($maxlabel == 0){
      foreach $tmp (reverse(split(/[.]/, $name))){
         $retVal .= "${mySep}${tmp}";
         $mySep = $pathSep;
      }
      return $retVal;
   }

      # otherwise, split name at labels, and at appropriate length
   foreach $tmp (reverse(split(/[.]/, $name))) {
      foreach $tmp2 (split(/(.{0,$maxlabel})/, $tmp)) {
         if(length($tmp2) > 0){
            $retVal .= "${mySep}${tmp2}";
            $mySep = $pathSep;
         }
      }
   }
   return $retVal;
}

   # returns formated data segment as needed for file system driver
   # Parameter 1 - data segment
   # Parameter 2 - separator to place before data segment (optional)
sub fs_fix {
   $in = shift;
   $sep = shift;

   if (length($in) < 1) {
      return "";
   }
   return "${sep}${in}";
}


   # create empty file.
   # Parameter 1 - filename & path to be created.
   # will automatically create the needed directory path.
sub mkFile {
      # get passed in file name & path
   my $file = shift;
   my $filehandle;
      
      # determine files parent directory
   my $pDir = $file;
   $pDir =~ s/(.*)([\\\/].*$)/$1/;

      # recursively create parent directory
   mkdirR($pDir);

      # create an empty file.

      # open file for writing.
   open($filehandle, ">$file") ||
      die "Could not create file '$file'\n";
      
      # close immediately.
   close($filehandle);
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
