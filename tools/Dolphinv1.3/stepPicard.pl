#!/usr/bin/env perl

#########################################################################################
#                                       stepPicard.pl
#########################################################################################
# 
#  This program runs the picard 
#
#########################################################################################
# AUTHORS:
#
# Alper Kucukural, PhD 
# 
#########################################################################################

############## LIBRARIES AND PRAGMAS ################

 use List::Util qw[min max];
 use strict;
 use File::Basename;
 use Getopt::Long;
 use Pod::Usage; 
 
#################### VARIABLES ######################
 my $refflat          = "";
 my $outdir           = "";
 my $type             = "";
 my $picardCmd        = "";
 my $pubdir           = "";
 my $wkey             = "";
 my $jobsubmit        = "";
 my $servicename      = "";
 my $help             = "";
 my $print_version    = "";
 my $version          = "1.0.0";
################### PARAMETER PARSING ####################

my $cmd=$0." ".join(" ",@ARGV); ####command line copy

GetOptions(
    'outdir=s'        => \$outdir,
    'refflat=s'       => \$refflat,
    'type=s'          => \$type,
    'picardCmd=s'     => \$picardCmd,
    'pubdir=s'        => \$pubdir,
    'wkey=s'          => \$wkey,
    'jobsubmit=s'     => \$jobsubmit,
    'servicename=s'   => \$servicename,
    'help'            => \$help, 
    'version'         => \$print_version,
) or die("Unrecognized optioins.\nFor help, run this script with -help option.\n");

if($help){
    pod2usage( {
		'-verbose' => 2, 
		'-exitval' => 1,
	} );
}

if($print_version){
  print "Version ".$version."\n";
  exit;
}

pod2usage( {'-verbose' => 0, '-exitval' => 1,} ) if ( ($refflat eq "") or ($outdir eq "") or ($picardCmd eq "") );	

################### MAIN PROGRAM ####################
# runs the picard program

my $outd  = "$outdir/picard_$type";

`mkdir -p $outd`;

my @files=();
print $type."\n";
if ($type eq "RSEM")
{ 
   my $indir   = "$outdir/rsem";
   @files = <$indir/pipe*/*.genome.sorted.bam>;
}
elsif ($type eq "chip")
{ 
   my $indir   = "$outdir/seqmapping/chip";
   @files = <$indir/*.sorted.bam>;
}
elsif ($type eq "mergechip")
{ 
   my $indir   = "$outdir/seqmapping/mergechip";
   @files = <$indir/*.bam>;
}
else
{
   my $indir   = "$outdir/tophat";
   print $indir."\n";
   @files = <$indir/pipe*/*.sorted.bam>;
}

foreach my $d (@files){ 
  my $dirname=dirname($d);
  my $libname=basename($d, ".sorted.bam");
	 
  my $com="$picardCmd REF_FLAT=$refflat OUTPUT=$outd/$libname.out INPUT=$d";
  print $com."\n\n";
  my $job=$jobsubmit." -n ".$servicename."_".$libname." -c \"$com\"";
  `$job`;
  die "Error 25: Cannot run the job:".$job if ($?);
}
__END__


=head1 NAME

stepPicard.pl

=head1 SYNOPSIS  

stepPicard.pl 
            -o outdir <output directory> 
            -r refflat <ucsc gtf files> 
            -p picardCmd <picard full path> 

stepPicard.pl -help

stepPicard.pl -version

For help, run this script with -help option.

=head1 OPTIONS

=head2 -o outdir <output directory>

the output files will be stored "$outdir/after_ribosome/cuffdiff" 

=head2 -p picardCmd <picard running line> 

Fullpath of picard running line. Ex: ~/cuffdiff_dir/cuffdiff

=head2  -r refflat <refflat file>  

ucsc refflat file

=head2 -help

Display this documentation.

=head2 -version

Display the version

=head1 DESCRIPTION

This program runs the cufflinks after tophat mappings

=head1 EXAMPLE

stepPicard.pl 
            -o outdir <output directory> 
            -g gtf <ucsc gtf files> 
            -c cufflinksCmd <cufflinks full path> 

=head1 AUTHORS

 Alper Kucukural, PhD
 
=head1 LICENSE AND COPYING

 This program is free software; you can redistribute it and / or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, a copy is available at
 http://www.gnu.org/licenses/licenses.html

