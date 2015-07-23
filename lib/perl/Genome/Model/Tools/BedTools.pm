package Genome::Model::Tools::BedTools;

use strict;
use warnings;

use Genome;

my $BEDTOOLS_DEFAULT = '2.9.0';

class Genome::Model::Tools::BedTools {
    is  => 'Command',
    is_abstract => 1,
    has_input => [
        use_version => {
            is  => 'Version',
            doc => 'BEDTools version to be used.  default_value='. $BEDTOOLS_DEFAULT,
            is_optional   => 1,
            default_value => $BEDTOOLS_DEFAULT,
        },
    ],
};


sub help_brief {
    "Tools to run BedTools.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt bed-tools ...
EOS
}

sub help_detail {
    return <<EOS
More information about the BedTools suite of tools can be found at http://code.google.com/p/bedtools/.
EOS
}

my %BEDTOOLS_VERSIONS = (
    '2.17.0' => Genome::Config::get('sw') . '/bedtools/BEDTools-2.17.0',
    '2.16.2' => Genome::Config::get('sw') . '/bedtools/BEDTools-2.16.2',
    '2.14.3' => Genome::Config::get('sw') . '/bedtools/BEDTools-2.14.3',
    '2.9.0' => Genome::Config::get('sw') . '/bedtools/BEDTools-2.9.0',
    '2.8.3' => Genome::Config::get('sw') . '/bedtools/BEDTools-2.8.3',
    '2.6.1' => Genome::Config::get('sw') . '/bedtools/BEDTools-2.6.1',
    '2.5.4' => Genome::Config::get('sw') . '/bedtools/BEDTools-2.5.4',
    '2.3.2' => Genome::Config::get('sw') . '/bedtools/BEDTools-2.3.2',
);

sub available_bedtools_versions {
    my $sort = sub{ 
        my @a = split(/\./, $_[0]);
        my @b = split(/\./, $_[1]);
        return $a[0] <=> $b[0] || $a[1] <=> $b[1] || $a[2] <=> $b[2];
    }; # could use Sort::Versions it has a lucid pkg
    return sort { $sort->($b, $a) } keys %BEDTOOLS_VERSIONS;
}

sub latest_bedtools_Version {
    return (available_bedtools_versions())[0];
}

sub path_for_bedtools_version {
    my ($class, $version) = @_;
    $version ||= $BEDTOOLS_DEFAULT;
    my $path = $BEDTOOLS_VERSIONS{$version};
    if (Genome::Sys->arch_os =~ /64/) {
        if ($path) {
            my $arch_path = $path .'-64';
            if (-d $arch_path) {
                $path = $arch_path;
            }
        }
    }
    return $path if (defined $path && -d $path);
    die 'No path found for bedtools version: '. $version;
}

sub bedtools_executable_path {
    my $self = shift;
    my $version = shift;
    my $bedtools = File::Spec->catfile(
        $self->path_for_bedtools_version($version),
        "bin",
        "bedtools");
    return $bedtools if (defined $bedtools && -e $bedtools);
    die 'No bedtools executable found for bedtools version: '. $version;
}

sub default_bedtools_version {
    die "default bedtools version: $BEDTOOLS_DEFAULT is not valid" unless $BEDTOOLS_VERSIONS{$BEDTOOLS_DEFAULT};
    return $BEDTOOLS_DEFAULT;
}

sub bedtools_path {
    my $self = shift;
    return $self->path_for_bedtools_version($self->use_version);
}

1;
