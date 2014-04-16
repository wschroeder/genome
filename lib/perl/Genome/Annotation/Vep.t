#!/usr/bin/env genome-perl

use strict;
use warnings FATAL => 'all';

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above "Genome";
use Sub::Install;
use Genome::Test::Factory::InstrumentData::MergedAlignmentResult;
use Genome::Model::Tools::DetectVariants2::Result::Vcf;
use Genome::Model::Tools::Bed::Convert::VcfToBed;
use Genome::Annotation::Detail::TestHelpers qw(test_cmd_and_result_are_in_sync);

use Test::More;

my $cmd_class = 'Genome::Annotation::Vep';
use_ok($cmd_class) or die;
use_ok('Genome::Db::Ensembl::Command::Run::Vep') or die;

my $cmd = generate_test_cmd();
ok($cmd->isa('Genome::Annotation::Vep'), "Command created correctly");
ok($cmd->execute(), 'Command executed');
is(ref($cmd->software_result), 'Genome::Annotation::Vep::Result', 'Found software result after execution');

test_cmd_and_result_are_in_sync($cmd);

done_testing();

sub generate_test_cmd {
    Sub::Install::reinstall_sub({
        into => 'Genome::Db::Ensembl::Command::Run::Vep',
        as => 'execute',
        code => sub {my $self = shift; my $file = $self->output_file; `touch $file`; return 1;},
    });

    my $input_result_class = 'Genome::Model::Tools::DetectVariants2::Result';
    my $input_vcf_result = $input_result_class->__define__();
    Sub::Install::reinstall_sub({
        into => $input_result_class,
        as => 'output_file_path',
        code => sub {return 'some_file.vcf.gz';},
    });

    Sub::Install::reinstall_sub({
        into => "Genome::FeatureList",
        as => 'get_tabix_and_gzipped_bed_file',
        code => sub { return 'somepath'},
    });

    my $roi = Genome::FeatureList->__define__();
    my $segdup = Genome::FeatureList->__define__();

    my %params = (
        input_vcf_result => $input_vcf_result,
        ensembl_version => "1",
        feature_list_ids_and_tags => [join(":", $roi->id, "ROI"),join(":", $segdup->id, "SEGDUP")],
        variant_type => 'snvs',
        polyphen => 'b',
        sift => 'b',
        condel => 'b',
        plugins_version => 0,
        species => "alien",
        terms => "ensembl",
    );
    my $cmd = $cmd_class->create(%params);
    return $cmd
}
