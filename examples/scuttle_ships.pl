#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;

use Data::Dumper;
use Getopt::Long;
use Time::HiRes 'sleep';

use Games::Lacuna::Client;

$| = 1;

my %opts;
GetOptions(\%opts,
    'help',
    'config=s',
    'planet=s',
    'type=s',
    'max=i',
) or usage();

usage() if $opts{help} || !(defined $opts{planet} && defined $opts{type});

sub usage {
  say qq^Options:
  --config  FILE
  --planet  PLANET NAME
  --type    SHIP TYPE
  --max     MAX SHIPS
  --help

Both --planet and --type are required.^;
  exit;
}

my $client = Games::Lacuna::Client->new(
    cfg_file => $opts{config} || 'lacuna.yml',
);

my $empire = $client->empire();
my $empire_status = $empire->get_status();
#the following fails if you have multiple planets with the same name
my %planets = map {$empire_status->{empire}{planets}{$_} => $_} keys %{$empire_status->{empire}{planets}};
die 'Planet not found' unless exists $planets{$opts{planet}};
my $buildings = $client->body(id => $planets{$opts{planet}})->get_buildings();
die 'No spaceport found' unless (grep {$_->{url} eq '/spaceport'} values %{$buildings->{buildings}});
my $port = $client->building(id => (grep {$buildings->{buildings}{$_}{url} eq '/spaceport'} keys %{$buildings->{buildings}})[0], type => 'spaceport');
my @ships = map {$_->{id}} grep {$_->{can_scuttle}} @{$port->view_all_ships({no_paging => 1}, {($opts{type} ? ('type' => $opts{type}) : ()), task => 'Docked'})->{ships}};
die 'No matching ships can be scuttled' unless @ships;
@ships = @ships[0..$opts{max} - 1] if ($opts{max} && @ships > $opts{max});
for (0..$#ships) {
  say $_+1 . '/' . scalar @ships;
  $port->scuttle_ship($ships[$_]);
  sleep 1.1; #change this to make use of the rpc limit info returned by the server
}

