#!/usr/bin/env perl
# Copyright 2014 Michal Špaček <tupinek@gmail.com>

# Pragmas.
use strict;
use warnings;

# Modules.
use Database::DumpTruck;
use Encode qw(decode_utf8 encode_utf8);
use English;
use HTML::TreeBuilder;
use LWP::UserAgent;
use URI;

# Don't buffer.
$OUTPUT_AUTOFLUSH = 1;

# URI of service.
my $base_uri = URI->new('http://www.brno.cz/sprava-mesta/urady-a-instituce-v-brne/mestske-organizace-a-spolecnosti/');

# Open a database handle.
my $dt = Database::DumpTruck->new({
	'dbname' => 'data.sqlite',
	'table' => 'data',
});

# Create a user agent object.
my $ua = LWP::UserAgent->new(
	'agent' => 'Mozilla/5.0',
);

# Get base root.
print 'Page: '.$base_uri->as_string."\n";
my $root = get_root($base_uri);

# Process items.
my @div = $root->find_by_attribute('id', 'telo')->content_list;
process_items(@div);

# Get root of HTML::TreeBuilder object.
sub get_root {
	my $uri = shift;
	my $get = $ua->get($uri->as_string);
	my $data;
	if ($get->is_success) {
		$data = $get->content;
	} else {
		die "Cannot GET '".$uri->as_string." page.";
	}
	my $tree = HTML::TreeBuilder->new;
	$tree->parse(decode_utf8($data));
	return $tree->elementify;
}

# Process items.
sub process_items {
	my @div = @_;
	my $type;
	my $company;
	my $company_link;
	my $ownership_interest;
	foreach my $div (@div) {
		my $h2 = $div->find_by_tag_name('h2');
		if ($h2) {
			$type = $h2->as_text;
			$type =~ s/\*$//ms;
			print 'Type: '.encode_utf8($type)."\n";
		}
		my @subdiv = $div->content_list;
		foreach my $subdiv (@subdiv) {
			if (ref $subdiv ne 'HTML::Element') {
				next;
			}
			if (! defined $company) {
				my $h4 = $subdiv->find_by_tag_name('h4');
				if ($h4) {
					$company = $h4->as_text;
					print 'Company: '.encode_utf8($company)."\n";
					$company_link = undef;
				}
			} else {
				my $strong = $subdiv->find_by_tag_name('strong');
				if ($strong && $strong->as_text) {
					save($type, $company, $company_link);
					$company = $strong->as_text;
					if ($company eq decode_utf8('*UPOZORNĚNÍ:')) {
						return;
					}
					print 'Company: '.encode_utf8($company)."\n";
					$company_link = undef;
				}
			}
			my $link_a = $subdiv->find_by_tag_name('a');
			if ($link_a) {
				$company_link = $link_a->attr('href');
			}
		}
	}
	return;
}

# Removing trailing whitespace.
sub remove_trailing {
	my $string_sr = shift;
	${$string_sr} =~ s/^\s*//ms;
	${$string_sr} =~ s/\s*$//ms;
	return;
}

# Save to database.
sub save {
	my ($type, $company, $company_link) = @_;
	$dt->insert({
		'Type' => $type,
		'Company' => $company,
		'Web' => $company_link,
	});
}
