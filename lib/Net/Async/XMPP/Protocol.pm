package Net::Async::XMPP::Protocol;
BEGIN {
  $Net::Async::XMPP::Protocol::VERSION = '0.002';
}
use strict;
use warnings;
use parent qw{IO::Async::Protocol::Stream};

use IO::Async::SSL;
use Socket;
use Protocol::XMPP::Stream;
use Future::Utils 'fmap_void';

=head1 NAME

Net::Async::XMPP::Protocol - common protocol support for L<Net::Async::XMPP>

=head1 VERSION

version 0.002

=head1 METHODS

=cut

=head2 xmpp

Accessor for the underyling XMPP L<Protocol::XMPP::Stream> object.

=cut

sub xmpp {
	my $self = shift;
	unless($self->{xmpp}) {
		$self->{xmpp} = Protocol::XMPP::Stream->new(
			debug => $self->{debug} ? 1 : 0,
			on_queued_write => $self->_capture_weakself(sub {
				my $self = shift;
				$self->{_writing_future} = (fmap_void {
					$self->write($self->xmpp->extract_write);
				} while => sub { $self->xmpp->ready_to_send })->on_ready(sub {
					$self->invoke_event('write_finished');
					delete $self->{_writing_future}
				});
			}),
			on_starttls => $self->_capture_weakself(sub {
				my $self = shift;
				$self->on_starttls;
			}),
		); 
	}
	return $self->{xmpp};
}

=head2 configure

Configure our handlers.

=cut

sub configure {
	my $self = shift;
	my %params = @_;

	$self->{state} ||= {
		connected => 0,
		loggedin => 0
	};
	$self->{debug} = delete $params{debug} if exists $params{debug};

	foreach (qw(on_message on_roster on_contact_request on_contact on_login on_presence on_connected)) {
		if(my $handler = delete $params{$_}) {
			$self->xmpp->{$_} = $self->_replace_weakself($handler);
		}
	}

	$self->SUPER::configure(%params);
}

=head2 on_starttls

Upgrade the underlying stream to use TLS.

=cut

sub on_starttls {
	my $self = shift;
	$self->xmpp->debug("Upgrading to TLS");

	require IO::Async::SSLStream;

	$self->SSL_upgrade(
		on_upgraded => $self->_capture_weakself(sub {
			my ($self) = @_;
			$self->xmpp->on_tls_complete;
		}),
		on_error => sub { die "error @_"; }
	);
}

sub is_connected { shift->{state}{connected} }
sub is_loggedin { shift->{state}{loggedin} }

=head2 on_read

Proxy incoming data through to the underlying L<Protocol::XMPP::Stream>.

=cut

sub on_read {
	my ($self, $buffref, $closed) = @_;

	$self->xmpp->on_data($$buffref);

# Entire buffer is handled by the Protocol object so no need for partial processing here.
	$$buffref = '';
	return 0;
}

=head2 connect

 $protocol->connect(
   on_connected => sub { warn "connected!" },
   host         => 'talk.google.com',
 )

Establish a connection to the XMPP server.

All available arguments are listed above.  C<on_connected> gets passed the
underlying protocol object.

=cut

sub connect {
	my $self = shift;
	my %args = @_;
	my $on_connected = delete $args{on_connected} || $self->{on_connected};

	my $host = exists $args{host} ? delete $args{host} : $self->{host};
	$self->SUPER::connect(
# Default port is 5222, but this can be overridden in %args.
		service		=> 5222,
		socktype	=> SOCK_STREAM,
		host		=> $host,
		%args,
		on_connected	=> sub {
			my $self = shift;
			$self->{state}{connected} = 1;
			$self->xmpp->queue_write($_) for @{$self->xmpp->preamble};
			$on_connected->($self) if $on_connected;
		},
		on_connect_error => sub {
			# TODO Callback
			warn "Connection error";
		},
		on_resolve_error => sub {
			# TODO Callback
			warn "Resolver error";
		},
	);
}

# Proxy methods

BEGIN {
	for my $method (qw(compose subscribe unsubscribe authorise deauthorise)) {
		my $code = sub { shift->xmpp->$method(@_) };
		{ no strict 'refs'; *{__PACKAGE__ . "::$method"} = $code; }
	}
}

1;

__END__

=head1 AUTHOR

Tom Molesworth <cpan@entitymodel.com>

=head1 LICENSE

Copyright Tom Molesworth 2010-2011. Licensed under the same terms as Perl itself.