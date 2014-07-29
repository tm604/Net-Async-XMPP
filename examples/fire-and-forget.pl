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
	"debug|d"         => \my $debug,
) or die "bad options";

# Obtain a standard event loop
my $loop = IO::Async::Loop->new;

# Create a client object with our event callbacks
$loop->add(
	my $client = Net::Async::XMPP::Client->new(
		debug => $debug,
	)
);

my $presence = $loop->new_future;
my $sender = $loop->new_future;
$client->configure(
	on_presence => sub {
		return if $presence->is_ready;
		warn "Had presence";
		$presence->done;
		$client->compose(
			to   => $target,
			body => $message,
		)->send->on_ready($sender);
	},
);

$client->login(
	jid	=> $jid,
	host => $host,
	password => $password,
	on_connected => sub {
		warn "Connected";
	},
);
$sender->get;
$client->close;
$loop->stop

