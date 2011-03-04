#! /usr/bin/perl

# This script will eliminate duplicate lines in the input and write the
# unique lines to output.  The input file should be sorted, as the matching
# algorithm is very simple. The input file is unchanged.  
#
# Usage: eliminateDups < input_file > output_file
#
# This program loops through each line of the input file and checks if
# the next line is equal to the previous one.  If it is, skip it.  If it is
# not, write it to output.

my $prevLine;
my $line;

while($line = <STDIN>){
   if($line ne $prevLine){
      print $line;
   }
   $prevLine = $line;
}
