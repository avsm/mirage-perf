#-----------------------------------------------------------------------------#
# This script can be used to convert OpenOfficeOrg dictionary files (*.dic)   #
# into a format usable for creating DNS test data.                            #
#                                                                             #
# To execute: sed -n -f dictionaryFixer.sed < input_file > output_file        #
# The "-n" is required!  Not using it will cause doubles in the output file.  #
#-----------------------------------------------------------------------------#

# strip "/" character and everything after it from the line
s/\/.*//

# remove any lines that have non-alpha characters
# or are shorter than 4 characters.
/^\w\{4,\}$/p

