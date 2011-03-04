#! /usr/bin/perl

require "flush.pl";

### This program will poll a DNS server to determine how long it takes
### the DNS server to respond with the data it expects.  This program
### is most useful in testing RFC2136 dynamic DNS updates, or testing
### how long it takes a DNS server to respond with new data after
### a refresh or reload of its zone files.

# default maximum search time is 5 minutes.  To change the default, change this value.
$maxTime = 5 * 60;

# Make sure we get at least 3 command line parameters.
# if we don't, then show usage
if($#ARGV < 2 || $#ARGV > 3){
   $! = 1;
   print "\nUSAGE:\n";
   print "This program expects 3 arguments.\n\n";
   print "timeDnsRefresh host, dns_search, result, timeout\n\n";
   print "host (required) the hostname or IP address of the DNS server to query\n";
   print "dns_search (required) the dns query parameters to be passed to dig\n";
   print "result (required) the regular expression to search for in the results\n";
   print "timeout (optional) the maximum time (in seconds) to search before giving up\n";
   die "\n";
}

#make sure we have a version of dig that supports the short option.
$digOut = `dig -h 2> /dev/null`;

# did dig have errors?
if($? != 0){
   $! = 2;
   die "\nError!!! Dig cannot be found on the path\n";
}

# does dig support +short option?
if($digOut !~ /\[no\]short/i){
   $! = 2;
   die "\nThe version of dig found does not support the +short option\n";
}

# does dig support the +time option?
if($digOut !~ /time/i){
   $! = 2;
   die "\nThe version of dig found does not support the +time option\n";
}

# get max timeout if it was passed.
if($#ARGV > 2){
   if($ARGV[3] =~ /[^0-9]+/){
      $! = 1;
      die "\nTimeout parameter can only be a number!\n";   
   }
   $maxTime = $ARGV[3];
}
   
# Tell user we are searching
print "\nSearching \'$ARGV[0]\' using \'$ARGV[1]\'\nfor a match to \'$ARGV[2]\'.\n";
if($maxTime > 0){
   print "Will search for a maximum of $maxTime seconds\n";
} else {
   print "Will search forever\n";
}

# keep track of the start time
$startTime = time();

#begin loop

$outMsg = "";

for($i = 1; ; $i++){
   
   # have dig do our query.
   $digOut = `dig \@$ARGV[0] +short +time=1 $ARGV[1]`;

   # did dig have errors - other than timing out?
   $lastRetCd = $? >> 8;
   if($lastRetCd != 0 && $lastRetCd != 9){
      $! = 2;
      die "\nError!!!  dig encountered an error during execution\n" .
          "Dig return code was: $lstRetCd\n";
   }

   # take note of the end time.
   $endTime = time();
   
   # output a message to let the user know how long we have been running.
   $outMsgLen = length($outMsg);
   for($j = 0; $j < $outMsgLen; $j++){
      print "\b";
   }
   $execTime = $endTime - $startTime;
   $outMsg = "Queries: $i Seconds: $execTime";
   print $outMsg;
   
   flush(STDOUT);
   
   # did we find what we were searching for?
   # if so, were done.
   if($digOut =~ /$ARGV[2]/i){
      $outMsgLen = length($outMsg);
      for($j = 0; $j < $outMsgLen; $j++){
         print "\b";
      }
  
      print "\nSuccess.  Found $ARGV[2] after ";
      print $endTime - $startTime;
      print " seconds\n";
      flush(STDOUT);
      last;
   }
   
   # if we have been searching for more than maxTime, we gotta quit.
   if($maxTime > 0 && $execTime >= $maxTime){
      $! = 3;
      die "\nSearch timed out\n";
   }
   
   # wait one second before trying again.
   # only do this if dig didn't have any problems, otherwise dig
   # provides enough delay.
   if($lastRetCd == 0){
      sleep 1;
   }
}
#end loop
