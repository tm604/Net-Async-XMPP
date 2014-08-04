requires 'parent', 0;
requires 'curry', 0;
requires 'Future', '>= 0.29';
requires 'Mixin::Event::Dispatch', '>= 1.000';
requires 'IO::Async', '>= 0.60';
requires 'Protocol::XMPP', '>= 0.006';

on 'test' => sub {
	requires 'Test::More', '>= 0.98';
	requires 'Test::Fatal', '>= 0.010';
};

