#!/usr/bin/perl

# John Slee - Fri 10 Jan 2014 14:36:40 EST

use strict;
use warnings;
use Getopt::Long;
use File::Spec::Functions;
use Data::Dumper;

sub usage {
	print "usage: $0 [options] common_name\n";
	exit 1;
}

sub checkfile { 
	my ($CONFIG, $filename) = @_;
	return 1 if $CONFIG->{overwrite};
	! -e $filename;
}

my %CONFIG = (
	country		=> 'AU',
	state		=> 'New South Wales',
	locality	=> 'Sydney',
	company		=> 'TastyCows',
	orgunit		=> 'Cloud',
	email		=> 'email@address',
	name		=> undef,
	challengepw	=> '',
	optcompany	=> '',
	certdir		=> '/etc/pki/tls',
	keydir		=> '/etc/pki/tls/private',
	reqdir		=> '/etc/pki/tls/private',
	overwrite	=> undef,
);

# sort out commandline options
GetOptions(\%CONFIG, qw(country=s locality=s company=s orgunit=s email=s name=s),
	qw(challengepw=s optcompany=s certdir=s keydir=s reqdir=s overwrite)) or usage;
$CONFIG{name} ||= shift(@ARGV) || usage;

# check filenames
$CONFIG{keyfile} = catfile($CONFIG{keydir}, $CONFIG{name} . '.key');
$CONFIG{reqfile} = catfile($CONFIG{reqdir}, $CONFIG{name} . '.req');
$CONFIG{certfile} = catfile($CONFIG{certdir}, $CONFIG{name} . '.crt');
for (@CONFIG{'keyfile', 'reqfile', 'certfile'}) {
	checkfile(\%CONFIG, $_) or die "output file already exists and no --overwrite: $_\n";
}

# generate private key
system(qw(openssl genrsa -out), $CONFIG{keyfile}, "1024") == 0
	or die "OpenSSL key generation failed\n";
chmod 0600, $CONFIG{keyfile}
	or warn "SECURITY WARNING: can't set mode 0600 on $CONFIG{keyfile}: $!\n";

# generate certificate signing request
open(my $pipe, '|-', 'openssl', qw(req -new -key), $CONFIG{keyfile}, qw(-out), $CONFIG{reqfile})
	or die "\ncan't open pipe to OpenSSL to generate certificate signing request: $!\n";
print $pipe join("\n", @CONFIG{qw(country state locality company orgunit name email challengepw optcompany)}), "\n\n"
	or die "\ncan't send data to OpenSSL pipe: $!\n";
close $pipe
	or die $! ? "\nError closing OpenSSL pipe: $!\n" : "Exit status $? from OpenSSL pipe\n";

# generate certificate
system(qw(openssl x509 -req -days 365 -in), $CONFIG{reqfile}, qw(-signkey), $CONFIG{keyfile}, qw(-out), $CONFIG{certfile})
	== 0 or die "\nOpenSSL certificate signing failed\n";

exit 0;
