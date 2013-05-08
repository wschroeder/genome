package Genome::Model::Tools::CopyNumber::CopyCatSomatic;

use strict;
use Genome;
use IO::File;
use File::Basename;
use warnings;
require Genome::Sys;
use FileHandle;
use File::Spec;


class Genome::Model::Tools::CopyNumber::CopyCatSomatic{
    is => 'Command',
    has => [        

        normal_window_file => {
	    is => 'String',
	    is_optional => 0,
	    doc => 'normal window file to get reads from (output of gmt copy-number bam-window)',
	},
	tumor_window_file => {
	    is => 'String',
	    is_optional => 0,
	    doc => 'tumor window file to get reads from (output of gmt copy-number bam-window)',
	},
        output_directory => {
            is => 'String',
            is_optional => 0,
            doc =>'path to the output directory',
        },
        annotation_directory => {
            is => 'String',
            is_optional => 0,
            example_values => ['/gscmnt/gc6122/info/medseq/annotations/copyCat/'],
            doc =>'path to the cn annotation directory',
        },
        per_library => {
            is => 'Boolean',
            is_optional => 1,
            default => 1,
            doc =>'do normalization on a per-library basis',
        },
        per_read_length => {
            is => 'Boolean',
            is_optional => 1,
            default => 1,
            doc =>'do normalization on a per-read-length basis',
        },
        genome_build => {
            is => 'String',
            is_optional => 0,
            doc =>'genome build - one of "36", "37", or "mm9"'
        },
        tumor_samtools_file => {
            is => 'String',
            is_optional => 1,
            doc =>'samtools file which will be used to find het snp sites and id copy-number neutral regions in tumor',
        },
        normal_samtools_file => {
            is => 'String',
            is_optional => 1,
            doc =>'samtools file which will be used to find het snp sites and id copy-number neutral regions in normal',
        },
        processors => {
            is => 'Integer',
            is_optional => 1,
            default => 1,
            doc => "set the number of processors that the parallel steps will use",
        },
        dump_bins => {
            is => 'Boolean',
            is_optional => 1,
            default => 0,
            doc => "write out the corrected bins to a file (pre-segmentation)"
        },
        do_gc_correction => {
            is => 'Boolean',
            is_optional => 1,
            default => 1,
            doc => "use loess correction to account for gc-bias",

        },
        # output_single_sample => {
        #     is => 'Boolean',
        #     is_optional => 1,
        #     default => 0,
        #     doc => "also output single-sample cn calls for each of tumor and normal",
        # }
        min_width => {
            is => 'Integer',
            is_optional => 1,
            default => 3,
            doc => "the minimum number of consecutive windows required in a segment",
        },
        min_mapability => {
            is => 'Number',
            is_optional => 1,
            default => 0.60,
            doc => "the minimum mapability needed to include a window",
        },
        # save_r_data => {
        #     is => 'Boolean',
        #     is_optional => 1,
        #     default => 0,
        #     doc => "save an r data file",
        # },
        ]
};

sub help_brief {
    "Takes two files generated by bam-window. Runs the R copyCat package to correct the data for GC content bias and segment it into regions of copy number loss and gain."
}

sub help_detail {
    "Takes two files generated by bam-window. Runs the R copyCat package to correct the data for GC content bias and segment it into regions of copy number loss and gain."
}

#########################################################################

sub execute {
    my $self = shift;

    my $tumor_window_file = $self->tumor_window_file;
    my $normal_window_file = $self->normal_window_file;
    my $output_directory = $self->output_directory;
    my $annotation_directory = $self->annotation_directory;
    my $per_lib = $self->per_library;
    my $per_read_length = $self->per_read_length;
    my $genome_build = $self->genome_build;
    # my $sex = $self->sex;
    my $tumor_samtools_file = $self->tumor_samtools_file;
    my $normal_samtools_file = $self->normal_samtools_file;
    my $processors = $self->processors;
    my $dump_bins = $self->dump_bins;
    my $min_width = $self->min_width;
    my $min_mapability = $self->min_mapability;
    # #shorthand for sex designation
    # if (lc($sex) eq "m"){
    #     $sex="male";
    # } elsif (lc($sex) eq "f"){
    #     $sex="female";
    # }


    # validate genome build
    if($genome_build eq "36"){
        $genome_build = "hg18";
    } elsif($genome_build eq "37"){
        $genome_build = "hg19";
    } else {
        unless ($genome_build eq "mm9" || $genome_build eq "hg18" || $genome_build eq "hg19" || $genome_build eq "hg19.chr1only" || $genome_build eq "hg19.chr14only"){
            die("ERROR: genome build not recognized\nMust be one of [hg18,36,hg19,37,mm9,hg19.chr1only,hg19.chr14only]");
        }
    }


    #resolve relative paths to full path - makes parsing the R file easier if you want tweaks
    $output_directory = File::Spec->rel2abs($output_directory);
    unless(-d $output_directory){
        `mkdir -p $output_directory`;
    }
    $annotation_directory = File::Spec->rel2abs($annotation_directory);

    if(defined($tumor_samtools_file)){
        $tumor_samtools_file = File::Spec->rel2abs($tumor_samtools_file);
    }
    if(defined($normal_samtools_file)){
        $normal_samtools_file = File::Spec->rel2abs($normal_samtools_file);
    }

    if(defined($normal_window_file)){
        $normal_window_file = File::Spec->rel2abs($normal_window_file);
    }
    if(defined($tumor_window_file)){
        $tumor_window_file = File::Spec->rel2abs($tumor_window_file);
    }
    
    #add the genome build to the anno dir
    $annotation_directory = $annotation_directory . "/" . $genome_build;
    unless(-d $annotation_directory){
        die("annotation directory not found $annotation_directory");
    }


    #make sure the files exist
    unless(-e $normal_window_file){
        die("file not found $normal_window_file");
    }
    unless(-e $tumor_window_file){
        die("file not found $tumor_window_file");
    }
    if(defined($tumor_samtools_file)){
        if(-e $tumor_samtools_file){
            $tumor_samtools_file = "\"$tumor_samtools_file\"";
        } else {
            die("file not found $tumor_samtools_file");
        }
    } else {
        $tumor_samtools_file = "NULL";
    }
    if(defined($normal_samtools_file)){
        if(-e $normal_samtools_file){
            $normal_samtools_file = "\"$normal_samtools_file\"";
        } else {
            die("file not found $normal_samtools_file");
        }
    } else {
        $normal_samtools_file = "NULL";
    }

    if($dump_bins){
        $dump_bins="TRUE";
    } else {
        $dump_bins="FALSE";
    }

    my $gcCorr="TRUE";
    if(!($self->do_gc_correction)){
        $gcCorr="FALSE";
    }
    # my $output_single_sample="FALSE";
    # if($self->output_single_sample){
    #     $output_single_sample="TRUE";
    # }


    #open the r file
    my $rf = open(my $RFILE, ">$output_directory/run.R") || die "Can't open R file for writing.\n";
    print $RFILE "library(copyCat)\n";

    print $RFILE "runPairedSampleAnalysis(annotationDirectory=\"$annotation_directory\",\n";
    print $RFILE "                        outputDirectory=\"$output_directory\",\n";
    print $RFILE "                        normal=\"$normal_window_file\",\n";
    print $RFILE "                        tumor=\"$tumor_window_file\",\n";
    print $RFILE "                        inputType=\"bins\",\n";
    print $RFILE "                        maxCores=$processors,\n";
    print $RFILE "                        binSize=0,\n";
    print $RFILE "                        perLibrary=$per_lib,\n";
    print $RFILE "                        perReadLength=$per_read_length,\n";
    print $RFILE "                        verbose=TRUE,\n";
    print $RFILE "                        minWidth=$min_width,\n";
    print $RFILE "                        minMapability=$min_mapability,\n";
    print $RFILE "                        dumpBins=$dump_bins,\n";
    print $RFILE "                        doGcCorrection=$gcCorr,\n";
#    print $RFILE "                        outputSingleSample=$output_single_sample,\n";
    print $RFILE "                        normalSamtoolsFile=$normal_samtools_file,\n";
    print $RFILE "                        tumorSamtoolsFile=$tumor_samtools_file)\n";


    #drop into the output directory to make running the R script easier
    my $cmd = "Rscript $output_directory/run.R";
    my $return = Genome::Sys->shellcmd(
        cmd => "$cmd",
        );
    unless($return) {
        $self->error_message("Failed to execute: Returned $return");
        die $self->error_message;
    }
    return $return;
}
1;
