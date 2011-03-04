package binddlz::writers::ldap::file;
require Exporter;

@ISA = qw(Exporter);

# export methods
@EXPORT = qw(getParameters, init, cleanup, addRecord);
  
# forward declaration of private methods
sub ldap_fix;

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
   my $header = $params{"header"};
   my $base = $params{"base"};

      # verify a filename was passed.
   if(length($filename) < 1){
      my $tmp = "A \"file\" parameter must be supplied to the\n";
      $tmp .= "binddlz::writers::ldap::file writer\n";
      die $tmp;
   }

      # verify a LDAP base was passed.
   if(length($base) < 1){
      my $tmp = "A \"base\" parameter must be supplied to the\n";
      $tmp .= "binddlz::writers::ldap::file writer\n";
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

      # store the base parameter to use later when writing out dns entries
   $this->{'base'} = $base;

   if(length($header) > 0){
      $header =~ s/\\n/\n/g;
      print $file ("$header\n\n");
   }
}

   # add "write" a DNS record.
sub addRecord {
   my $this = shift;
   local (*zone, *host, *ttl, *type, *mx_priority,
       *data, *adminEmail, *serial, *refresh,
       *retry, *expire, *minimum) = @_;

      # get the filehandle to write to.
   my $file = $this->{'filehandle'};

      # get base from config.
   my $base = $this->{'base'};
      
      # get data from last loop
   my $recordID = $this->{'recordID'};
   my $lastZone = $this->{'lastZone'};
   my $lastHost = $this->{'lastHost'};
   my $dataFieldName = "dlzData";

      # Wildcards "*" have special meaning in LDAP so convert
      # wildcards to "~".
   my $host = $host;
   if($host eq "*"){
      $host = "~";
   }

      # recordID is NULL first time through, Set to zero.
   if ($recordID == NULL) {
      $recordID = 0;
   }

      # if this is a new zone from last loop, output a dlzZone object
      # to store hosts in.
   if($zone ne $lastZone){
      print $file ("dn: dlzZoneName=${zone},${base}\n");
      print $file ("objectclass: dlzZone\n");
      print $file ("dlzZoneName: ${zone}\n\n");
      $this->{'lastZone'} = $zone;
   }

      # if this is a new host from last loop, output a dlzHost object
      # to store records in.
   if($host ne $lastHost){
      print $file ("dn: dlzHostName=${host},dlzZoneName=${zone},${base}\n");
      print $file ("objectclass: dlzHost\n");
      print $file ("dlzHostName: ${host}\n\n");
      $this->{'lastHost'} = $host;
         # reset recordID for each host
      $recordID = 0;
   }
              
      # write out LDIF for this record
   print $file ("dn: dlzRecordID=${recordID},dlzHostName=${host},dlzZoneName=${zone},${base}\n");

   if($type eq "a"){
      print $file ("objectclass: dlzARecord\n");
      $dataFieldName = "dlzIPAddr";
   } elsif($type eq "ns"){
      print $file ("objectclass: dlzNSRecord\n");
   } elsif($type eq "mx"){ 
      print $file ("objectclass: dlzMXRecord\n");
   } elsif($type eq "soa"){ 
      print $file ("objectclass: dlzSOARecord\n");
      $dataFieldName = "dlzPrimaryNS";
   } elsif($type eq "txt"){ 
      print $file ("objectclass: dlzTextRecord\n");
   } elsif($type eq "ptr"){ 
      print $file ("objectclass: dlzPTRRecord\n");
   } elsif($type eq "cname"){ 
      print $file ("objectclass: dlzCNameRecord\n");
   } else {
      print $file ("objectclass: dlzGenericRecord\n");
   }

   print $file ("dlzRecordID: $recordID\n");
   print $file (ldap_fix("dlzHostName", $host));
   print $file (ldap_fix("dlzTTL", $ttl));
   print $file (ldap_fix("dlzType", $type));
   print $file (ldap_fix("dlzPreference", $mx_priority));
   print $file (ldap_fix($dataFieldName, $data));
   print $file (ldap_fix("dlzAdminEmail", $adminEmail));
   print $file (ldap_fix("dlzSerial", $serial));
   print $file (ldap_fix("dlzRefresh", $refresh));
   print $file (ldap_fix("dlzRetry", $retry));
   print $file (ldap_fix("dlzExpire", $expire));
   print $file (ldap_fix("dlzMinimum", $minimum));
   print $file ("\n\n");

      # increment recordID and store for next loop.
   $recordID++;      
   $this->{'recordID'} = $recordID;
}

   # cleanup this instance after writing DNS data
sub cleanup() {
   # for LDAP LDIF file no cleanup needed.

   # Don't close output file.
   # Perl does automatically when the program completes.
}

   # output record in LDAP LDIF format.
   # basically, if entry is empty, return nothing.
   # otherwise return entry as attribute_name: attribute value.
sub ldap_fix {
   $attribute = shift;
   $value = shift;

   if (length($value) < 1) {
      return ""; 
   }
   return "${attribute}: ${value}\n";
}

# last line of a perl module must be 1;
1;
