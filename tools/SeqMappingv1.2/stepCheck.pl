#!/usr/bin/env perl

#########################################################################################
#                                       stepCheck.pl
#########################################################################################
# 
#  This program checks the input parameters and files. If there is a problem in any of 
#  the params, this program returns an error. 
#  This program also copy/makes links and unzip the input files into the necessary locations 
#  for downstream analysis.
#
#
#########################################################################################
# AUTHORS:
#
# Alper Kucukural, PhD 
# Jul 4, 2014
#########################################################################################


############## LIBRARIES AND PRAGMAS ################

 use List::Util qw[min max];
 use strict;
 use File::Basename;
 use Getopt::Long;
 use Pod::Usage; 
 
#################### VARIABLES ######################
 my $input            = "";
 my $resume           = "";
 my $outdir           = "";
 my $jobsubmit        = "";
 my $barcode          = "";
 my $adapter          = ""; 
 my $trim             = ""; 
 my $servicename      = "";
 my $help             = "";
 my $print_version    = "";
 my $version          = "1.0.0";
################### PARAMETER PARSING ####################

my $cmd=$0." ".join(" ",@ARGV); ####command line copy

GetOptions( 
	'input=s'        => \$input,
	'resume=s'       => \$resume,
	'outdir=s'       => \$outdir,
        'barcode=s'      => \$barcode,
        'adapter=s'      => \$adapter,
        'trim=s'         => \$trim,
        'servicename=s'  => \$servicename,
        'jobsubmit=s'    => \$jobsubmit,
	'help'           => \$help, 
	'version'        => \$print_version,
) or die("Unrecognized options.\nFor help, run this script with -help option.\n");

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

pod2usage( {'-verbose' => 0, '-exitval' => 1,} ) if ( ($input eq "") or ($outdir eq "") );	

################### MAIN PROGRAM ####################
#    maps the reads to the ribosome and put the files under $outdir/after_ribosome directory
if ($resume eq "fresh")
{
   `rm -rf $outdir/tmp/track/*`;
   `rm -rf $outdir/seqmapping`;
   `rm -rf $outdir/tophat`;
   `rm -rf $outdir/rsem`;
   `rm -rf $outdir/*tdf*`;
   `rm -rf $outdir/*ucsc*`;
   `rm -rf $outdir/agg`;
   `rm -rf $outdir/macs`;
}

$input=~s/:+/:/g;
$input=~s/\s//g;
$input=~s/:$//g;
 
my @pfiles=split(/:/,$input);

if($adapter ne "NONE")
{
   die "Error 66: please check the adapter:$adapter" unless ($adapter =~/^[ACGT:]+$/);
}
if($trim ne "NONE")
{
   my @nts=split(/[,\s\t:]+/,$trim);
   foreach my $ntlen (@nts)
   {
      if (length($ntlen)>=1)
      {
         die "Error 67: please check the trim lengths:$ntlen" unless ($ntlen =~/^[\d]+$/);
      }
   }   
}
$outdir   = "$outdir/input";
`mkdir -p $outdir`;

my $pair=0;
if($barcode eq "NONE")
{
  my %prefiles1=();
  my %prefiles2=();
  my $cat=0;
  for(my $i=0;$i<scalar(@pfiles);$i++) 
  {
    my @files=split(/[,\s\t]+/,$pfiles[$i]);
    print "[".$files[1]."]\n";
    if (length($files[1])>1)
    {
    die "Error 64: please check the file:".$files[1] unless (checkFile($files[1]));
    if (exists $prefiles1{$files[0]})
    {
      $cat=1;
      $prefiles1{$files[0]}.=$files[1]." ";
    }
    else
    {
      $prefiles1{$files[0]}=$files[1]." ";
    }
    if (scalar(@files)==3) 
    {
      $pair=1;
      die "Error 64: please check the file:".$files[2] unless (checkFile($files[2]));
      $prefiles2{$files[0]}.=$files[2]." ";  
    }
    }
  }

  foreach my $libname (keys %prefiles1) 
  {
    my $str_file="";
    my $com="";
    if (!$pair) 
    {
       $str_file=$prefiles1{$libname};  
 
       if ($str_file=~/\.gz/)
       {
         $com="zcat $str_file > $outdir/$libname.fastq;";
         $str_file= "$outdir/$libname.fastq";
       }
       else
       {
         if ($cat)
         {
           $com="cat $str_file > $outdir/$libname.fastq;";
         }
         else
         {
           $com="ln -sf $str_file $outdir/$libname.fastq;";
         }
       }
    }
    else
    {
      my $file1=$prefiles1{$libname};  
      my $file2=$prefiles2{$libname};  
      
      if ($file1=~/\.gz/)
      {
       $com="zcat ".$file1." > $outdir/$libname.1.fastq;";
       $com.="zcat ".$file2." > $outdir/$libname.2.fastq;";
      }
      else
      {
         if ($cat)
         {
           $com="cat ".$file1." > $outdir/$libname.1.fastq;";
           $com.="cat ".$file2." > $outdir/$libname.2.fastq;";
         }
         else
         {
           $com="ln -sf $file1 $outdir/$libname.1.fastq;";
           $com.="ln -sf $file2 $outdir/$libname.2.fastq;";
         }
       }      
     }
     if ($com=~/^ln/)
     {
       print $com."\n";
       `$com`;       
     }
     else
     {
       my $job=$jobsubmit." -n ".$servicename."_".$libname." -c \"$com\"";
       print $job."\n";   
       `$job`;
     }
  }  
}
else
{
  # If we are going to do a barcode separation, just check lane files exists in
  # given location
 
  my @prefiles=();
  foreach my $line (@pfiles)
  { 

    print $line."\n";
    my @files=split(/[,\s\t]+/,$line);
    if (scalar(@files)>1)
    {
       $pair=1;
    }
    foreach my $file (@files)
    {
        print "[$file]\n";
        die "Error 64: please check the file:".$file unless (checkFile($file));
    }
    $prefiles[0].=$files[0]." ";
    if ($pair){
       $prefiles[1].=$files[1]." ";
    }
  }
  my $i=1;
  my $com="";
  foreach my $file (@prefiles)
  {
    if($file!~/^$/)
    {
      my $pairedstr="";
      $pairedstr="_R$i" if ($pair); 
      if ($file=~/\.gz/)
      {
        $com="zcat ".$file." > $outdir/data$pairedstr.fastq";
      }
      else
      {

         if (scalar(@pfiles)==1)
         {
            $com="ln -s ".$file." $outdir/data$pairedstr.fastq";
         }
         else
         {
            $com="cat ".$file." > $outdir/data$pairedstr.fastq";
         }
      }

      print "COMMAND: [ $com ]\n\n";
      if ($com=~/^ln/)
      {
        `$com`;
      }
      else
      {
         my $job=$jobsubmit." -n ".$servicename.$i." -c \"$com\"";
         print $job."\n\n";
         `$job`;
      }
      $i++;
    }
   }
  # If all the files exists check if the barcodes and library names were defined right
  
  my @blines=split(/:/,$barcode);
  foreach my $line (@blines)
  {
    if (length($line)>1)
    {
      my @defs=split(/[,\s\t]+/,$line);
      die "Error 65: please check the barcode definitions:$line" unless (scalar(@defs)==2);
    }
  }
}
 

sub checkFile
{
 my ($file) = $_[0];
 return 1 if (-e $file);
 return 0;
}

__END__


=head1 NAME

stepCheck.pl

=head1 SYNOPSIS  

stepCheck.pl -i input <fastq> 
            -o outdir <output directory> 

stepCheck.pl -help

stepCheck.pl -version

For help, run this script with -help option.

=head1 OPTIONS

=head2 -i  input file <fastq format> 

fastq files has to be separated with ":". If it is paired end the paired end files has to ber separated by ","

Ex: For single end;

test1.fastq:test2.fastq:ctrl1.fastq:ctrl2.fastq

for paired end;

test1_R1.fastq,test1_R2.fastq:ctrl1_R1.fastq,ctrl1_R2.fastq

    
=head2 -o outdir <output directory>

the output files will be "$outdir/input" 

=head2 -help

Display this documentation.

=head2 -version

Display the version

=head1 DESCRIPTION

 This program map the reads to rRNAs and put the rest into other files 

=head1 EXAMPLE


stepCheck.pl -i test1.fastq:test2.fastq:ctrl1.fastq:ctrl2.fastq
            -o ~/out
            -b ~/bowtie_dir/bowtie
            -p "-p 8 -n 2 -l 20 -M 1 -a --strata --best"
            -r ~/bowtie_ind/rRNA

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

