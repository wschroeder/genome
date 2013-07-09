package Genome::InstrumentData::Command::Import::WorkFlow::SortBam;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Command::Import::WorkFlow::SortBam { 
    is => 'Command::V2',
    has_input => [
        unsorted_bam_path => {
            is => 'Text',
            doc => 'The path of the unsorted bam to sort.',
        }
    ],
    has_output => [ 
        sorted_bam_path => {
            calculate_from => [qw/ sorted_bam_prefix /],
            calculate => q( $sorted_bam_prefix.'.bam'; ),
            doc => 'The path of the sorted bam.',
        },
    ],
    has_calculated => [
        sorted_bam_prefix => {
            calculate_from => [qw/ unsorted_bam_path /],
            calculate => q( $unsorted_bam_path =~ s/\.bam//; return $unsorted_bam_path.'.sorted'; ),
            doc => 'The prefix for the sorted bam.',
        },
    ],
};

sub execute {
    my $self = shift;
    $self->status_message('Sort bam...');

    my $sort_ok = $self->_sort_bam;
    return if not $sort_ok;

    my $verify_read_count_ok = $self->_verify_read_count;
    return if not $verify_read_count_ok;

    $self->status_message('Sort bam...done');
    return 1;
}

sub _sort_bam {
    my $self = shift;

    my $unsorted_bam_path = $self->unsorted_bam_path;
    $self->status_message("Unsorted bam path: $unsorted_bam_path");
    my $sorted_bam_path = $self->sorted_bam_path;
    my $sorted_bam_prefix = $sorted_bam_path;
    $sorted_bam_prefix =~ s/\.bam$//;
    $self->status_message("Sorted bam prefix: $sorted_bam_prefix");
    $self->status_message("Sorted bam path: $sorted_bam_path");
    my $cmd = "samtools sort -m 3000000000 -n $unsorted_bam_path $sorted_bam_prefix";
    my $rv = eval{ Genome::Sys->shellcmd(cmd => $cmd); };
    if ( not $rv or not -s $sorted_bam_path ) {
        $self->error_message($@) if $@;
        $self->error_message('Failed to run samtools sort!');
        return;
    }

    return 1;
}

sub _verify_read_count {
    my $self = shift;
    $self->status_message('Verify read count...');

    my $helpers = Genome::InstrumentData::Command::Import::WorkFlow::Helpers->get;
    my $unsorted_flagstat = $helpers->load_flagstat($self->unsorted_bam_path.'.flagstat');
    return if not $unsorted_flagstat;

    my $sorted_flagstat = $helpers->validate_bam($self->sorted_bam_path);
    return if not $sorted_flagstat;

    $self->status_message('Sorted bam read count: '.$sorted_flagstat->{total_reads});
    $self->status_message('Unsorted bam read count: '.$unsorted_flagstat->{total_reads});

    if ( $sorted_flagstat->{total_reads} != $unsorted_flagstat->{total_reads} ) {
        $self->error_message('Sorted and unsorted bam read counts do not match!');
        return;
    }

    $self->status_message('Verify read count...done');
    return 1;
}


1;

