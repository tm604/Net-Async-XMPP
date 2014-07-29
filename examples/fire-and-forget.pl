#!/usr/bin/env perl 
use strict;
use warnings;
use IO::Async::Loop;
use Net::Async::XMPP::Client;

use Getopt::Long;

GetOptions(
	"jid=s"           => \my $jid,
	"target|t=s"      => \my $target,
	"message|m=s"     => \my $message,
	"host|h=s"        => \my $host,
	"password|p=s"    => \my $password,
) or die "bad options";

# Obtain a standard event loop
my $loop = IO::Async::Loop->new;

# Create a client object with our event callbacks
my $client = Net::Async::XMPP::Client->new(
); 

my $sent = $loop->new_future;
my $write_finished = $loop->new_future;
$client->configure(
	on_write_finished => sub {
		warn "Had write finished event";
		$write_finished->done unless $write_finished->is_ready;
	},
	on_presence => sub {
		warn "Had presence";
		$client->compose(
			to   => $target,
			body => $message,
		)->send;
		$write_finished = $loop->new_future;
		$sent->done;
	},
);

$loop->add($client);
$client->login(
	jid	=> $jid,
	host => $host,
	password => $password,
	on_connected => sub {
		warn "Connected";
	},
);
$sent->then(sub {
	$write_finished
})->get;
$client->close;
$loop->stop

