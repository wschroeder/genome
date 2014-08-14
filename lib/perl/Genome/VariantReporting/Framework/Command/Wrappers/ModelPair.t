#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Genome::VariantReporting::Framework::Command::Wrappers::TestHelpers qw(get_build compare_directories);

my $pkg = "Genome::VariantReporting::Framework::Command::Wrappers::ModelPair";

use_ok($pkg);

my $test_dir = __FILE__.".d";
my $expected_dir = File::Spec->join($test_dir, "expected");
my $output_dir = Genome::Sys->create_temp_directory;

my $roi_name = "test_roi";
my $tumor_sample = Genome::Test::Factory::Sample->setup_object();
my $normal_sample = Genome::Test::Factory::Sample->setup_object(source_id => $tumor_sample->source_id);
my $discovery_build = get_build($roi_name, $tumor_sample, $normal_sample);

is($discovery_build->class, "Genome::Model::Build::SomaticValidation");

my $model_pair = $pkg->create(discovery => $discovery_build,
    validation => $discovery_build,
    #base_output_dir => $expected_dir,
    base_output_dir => $output_dir,
);
is($model_pair->class, "Genome::VariantReporting::Framework::Command::Wrappers::ModelPair");
compare_directories($expected_dir, $output_dir);
done_testing;

