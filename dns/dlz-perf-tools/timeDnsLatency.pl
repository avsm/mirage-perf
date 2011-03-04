#! /usr/bin/perl

### This program will query a DNS server to determine how long it takes
### the DNS server to respond.  This program is most useful in testing DNS
### query latency when a server is loaded down by another tool like queryperf

# Make sure we get 2 command line parameters.
# if we don't, then show usage
if($#ARGV != 1){
   $! = 1;
   print "\nUSAGE:\n";
   print "This program expects 2 arguments.\n\n";
   print "timeDnsLatency host, dns_search\n\n";
   print "host (required) the hostname or IP address of the DNS server to query\n";
   print "dns_search (required) the dns query parameters to be passed to dig\n";
   die "\n";
}


# make sure we have a version of dig that supports the noall,
# answer and stats options.

$digOut = `dig -h 2> /dev/null`;

# did dig have errors?
if($? != 0){
   $! = 2;
   print "Dig cannot be found on the path\n";
}

# does dig support +noall option?
if($digOut !~ /\[no\]all/i){
   print "\nThe version of dig found does not support the +noall option\n";
   $! = 2;
   die;
}

# does dig support +answer option?
if($digOut !~ /\[no\]answer/i){
   $! = 2;
   die "The version of dig found does not support the +answer option\n";
}

# does dig support +stats option?
if($digOut !~ /\[no\]stats/i){
   $! = 2;
   die "The version of dig found does not support the +stats option\n";
}

# have dig do our query.
   $digOut = `dig \@$ARGV[0] +noall +answer +stats $ARGV[1]`;


# if connection times out, DNS server is unreachable.
if($digOut =~ /.*connection timed out/i){
   $! = 3;
   die "ERROR UNREACHABLE!\n";
}

# if the first response line has Query time in it, no answer was returned.
if($digOut =~ /^.*Query time/i){
   $! = 4;
   die "ERROR NOANSWER!\n";
}

# remove all extra text.  Just output query response time.
$digOut =~ s/(.*\n)*.*Query time: //i;
$digOut =~ s/\n;;.*\n.*\n.*\n//i;
   
# output query response time.
print "$digOut";



