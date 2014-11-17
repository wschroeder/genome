package Genome::VariantReporting::Framework::Component::Base;

use strict;
use warnings FATAL => 'all';
use Genome;

class Genome::VariantReporting::Framework::Component::Base {
    is_abstract => 1,
    attributes_have => {
        is_structural => {
            is => "Boolean",
            default => 0,
        },
    },
};

sub validate {
    my $self = shift;

    my @errors = $self->__errors__;
    if (@errors) {
        $self->print_errors(@errors);
        die $self->error_message("Failed to validate");
    }
    return;
}

sub print_errors {
    my ($self, @errors) = @_;

    for my $error (@errors) {
        my @properties = $error->properties;
        $self->error_message("Property " .
            join(',', map { "'$_'" } @properties) .
            ': ' . $error->desc);
    }
    return;
}

sub part {
    my $self = shift;
    return (split(/::/, $self->class))[-1];
}

sub properties_in_plan {
    my $class = shift;
    my @properties;
    for my $property ($class->__meta__->properties) {
        next if $property->class_name eq "UR::Object" or $property->class_name eq "Command::V2";
        if (!($property->can("is_structural")) or !($property->is_structural)) {
            push @properties, $property;
        }
    }
    return @properties;
}

sub _get_dummy_params {
    my $class = shift;
    my %params;
    for my $property ($class->properties_in_plan) {
        my $name = $property->property_name;
        if (defined $property->data_type and $property->data_type eq 'ARRAY') {
            $params{$name} = [$name.".n"];
        }
        elsif (defined $property->data_type and $property->data_type eq 'HASH') {
            $params{$name} = {"$name.key" => "$name.value"};
        }
        else {
            $params{$name} = $name;
        }
    }
    return \%params;
}

sub vr_doc_sections {
    my $self = shift;

    my @sections;

    my %overview_section;
    $overview_section{header} = "OVERVIEW";
    $overview_section{items} = [$self->__meta__->doc ? $self->__meta__->doc : "(undocumented)"];

    push @sections, \%overview_section;

    my $properties_section = $self->_properties_section;
    if ($properties_section) {
        push @sections, $properties_section;
    }

    return @sections;
}

sub _properties_section {
    my $self = shift;
    my @properties;
    my %properties_section;
    map {push @properties, _property_to_string($_)} $self->properties_in_plan;
    @properties = grep {$_->[0] ne "id"} @properties;
    for my $row (@properties) {
        push @{$properties_section{items}},
            sprintf(
                "  %s\n%s",
                Term::ANSIColor::colored($row->[0], 'bold'), # . "   " . $row->[1],
                Text::Wrap::wrap(
                    "    ", # 1st line indent,
                    "    ", # all other lines indent,
                    $row->[2],
                    $row->[3] || '',
                ),
            );
    }
    if (@properties) {
        $properties_section{header} = "PROPERTIES";
        return \%properties_section;
    }
    else {
        return;
    }
}

sub _property_to_string {
    my $property_meta = shift;
    my @lines;
    my $param_name = $property_meta->{property_name};
    my $param_type = $property_meta->data_type || '';
    if (defined($param_type) and $param_type !~ m/::/) {
        $param_type = ucfirst(lc($param_type));
    }
    my $doc = $property_meta->doc;
    my $valid_values = $property_meta->valid_values;
    my $example_values = $property_meta->example_values;
    my $max_name_length = 0;
    unless ($doc) {
        eval {
            foreach my $ancestor_class_meta ($property_meta->class_meta->ancestry_class_metas) {
                my $ancestor_property_meta = $ancestor_class_meta->property_meta_for_name($property_meta->property_name);
                if ($ancestor_property_meta and $doc = $ancestor_property_meta->doc) {
                    last;
                }
            }
        };
    }

    if ($doc) {
        push @lines, $doc;
    }
    else {
        if (!$valid_values and !$property_meta->{is_translated}) {
            push @lines, "(undocumented)";
        }
    }
    if ($valid_values) {
        push @lines, "valid values:";
        for my $v (@$valid_values) {
            push @lines, " ". $v;
            $max_name_length = length($v)+2 if $max_name_length < length($v)+2;
        }
    }
    if ($property_meta->{is_translated}) {
        push @lines, "This is a translated property.";
    }
    if ($example_values && @$example_values) {
        push @lines, "example". (@$example_values > 1 and 's') . ":";
        push @lines, join(', ',
            map { ref($_) ? Data::Dumper->new([$_])->Terse(1)->Dump() : $_ } @$example_values
            );
    }
    $max_name_length = length($param_name) if $max_name_length < length($param_name);

    my $default_value = $property_meta->default_value;
    if (defined $default_value) {
        if ($param_type eq 'Boolean') {
            $default_value = $default_value ? "'true'" : "'false'";
        }
        elsif ($property_meta->is_many && ref($default_value) eq 'ARRAY') {
            if (@$default_value) {
                $default_value = "('".join("','",@$default_value)."')";
            }
            else {
                $default_value = "()";
            }
        }
        else {
            $default_value = "'$default_value'";
        }
        $default_value = "\nDefault value $default_value if not specified";
    }
    return [$param_name, $param_type, join("\n", @lines), $default_value];
}

1;
