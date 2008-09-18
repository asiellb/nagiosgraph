#!/usr/bin/perl
use FindBin;
use lib "$FindBin::Bin/../etc";
use strict;
use CGI qw/:standard/;
use Data::Dumper;
use File::Find;
use Test;
use ngshared;
my ($log, $result, @result, $testvar, @testdata, %testdata, $ii);

BEGIN {
    plan tests => 94;
}

sub testdebug { # Test the logger.
	open LOG, '+>', \$log;
	$Config{debug} = 1;
	debug(0, "test message");
	ok($log, qr/02ngshared.t none - test message$/);
	close LOG;
	open LOG, '+>', \$log;
	debug(2, "test no message");
	ok($log, "");
	close LOG;
}

sub testdumper { # Test the list/hash output debugger.
	open LOG, '+>', \$log;
	$testvar = 'test';
	dumper(0, 'test', \$testvar);
	ok($log, qr/02ngshared.t none - test = .'test';$/);
	close LOG;
	open LOG, '+>', \$log;
	$testvar = ['test'];
	dumper(0, 'test', $testvar);
	ok($log, qr/02ngshared.t none - test = \[\s+'test'\s+\];$/s);
	close LOG;
	open LOG, '+>', \$log;
	$testvar = {test => 1};
	dumper(0, 'test', $testvar);
	ok($log, qr/02ngshared.t none - test = \{\s+'test' => 1\s+\};$/s);
	close LOG;
	open LOG, '+>', \$log;
	dumper(2, 'test', $testvar);
	ok($log, '');
	close LOG;
	$Config{debug} = 0;
}

sub testgetdebug {
	$Config{debug} = -1;
	getdebug('test');
	ok($Config{debug}, -1);		# not configured, so no change

	# just program tests
	$Config{debug_test} = 1;
	getdebug('test');
	ok($Config{debug}, 1);		# configured, so change
	$Config{debug} = -1;
	getdebug('test', 'testbox', 'ping');
	ok($Config{debug}, 1);		# _host and _service not set, so change
	$Config{debug} = -1;

	# just program and hostname tests
	$Config{debug_test_host} = 'testbox';
	getdebug('test', 'testbox', 'ping');
	ok($Config{debug}, 1);		# _host set to same hostname, so change
	$Config{debug} = -1;
	getdebug('test', 'testing', 'ping');
	ok($Config{debug}, -1);		# _host set to different hostname, so no change
	$Config{debug} = -1;

	# program, hostname and service tests
	$Config{debug_test_service} = 'ping';
	getdebug('test', 'testbox', 'ping');
	ok($Config{debug}, 1);		# _host and _service same, so change
	$Config{debug} = -1;
	getdebug('test', 'testbox', 'smtp');
	ok($Config{debug}, -1);		# _host same, but _service not, so no change
	$Config{debug} = -1;
	getdebug('test', 'testing', 'ping');
	ok($Config{debug}, -1);		# _service same, but _host not, so no change
	$Config{debug} = -1;
	getdebug('test', 'testing', 'smtp');
	ok($Config{debug}, -1);		# neither _host or _service not, so no change
	$Config{debug} = -1;

	# just program and service tests
	delete $Config{debug_test_host};
	getdebug('test', 'testbox', 'ping');
	ok($Config{debug}, 1);		# _service same, so change
	$Config{debug} = -1;
	getdebug('test', 'testbox', 'smtp');
	ok($Config{debug}, -1);		# _service not, so no change
	$Config{debug} = 0;
}

sub testurl { # Test encoding a URL and the decoding it.
	%testdata = ('http://wiki.nagiosgraph.sourceforge.net/' => 'http%3A%2F%2Fwiki%2Enagiosgraph%2Esourceforge%2Enet%2F',
		'Partition: /' => 'Partition%3A%20%2F');
	foreach $ii (keys %testdata) {
		$result = urlencode($ii);
		ok($result, $testdata{$ii});
		$result = urldecode($result);
		ok($result, $ii);
	}
}

sub testgetfilename { # Test getting the file and directory for a database.
	# Make rrddir where we run from, since the 'subdir' configuration wants to
	# create missing subdirectories
	$Config{rrddir} = $FindBin::Bin;
	$Config{dbseparator} = '';
	@result = getfilename('testbox', 'Partition: /');
	ok($result[0], $FindBin::Bin);
	ok($result[1], 'testbox_Partition%3A%20%2F_');
	@result = getfilename('testbox', 'Partition: /', 'diskgb');
	ok($result[0], $FindBin::Bin);
	ok($result[1], 'testbox_Partition%3A%20%2F_diskgb.rrd');
	$Config{dbseparator} = 'subdir';
	@result = getfilename('testbox', 'Partition: /');
	ok($result[0], $FindBin::Bin . '/testbox');
	ok($result[1], 'Partition%3A%20%2F___');
	@result = getfilename('testbox', 'Partition: /', 'diskgb');
	ok($result[0], $FindBin::Bin . '/testbox');
	ok($result[1], 'Partition%3A%20%2F___diskgb.rrd');
	ok(-d $result[0]);
	rmdir $result[0] if -d $result[0];
}

sub testHTMLerror { # We can't really test HTMLerror, since it just prints to STDOUT.
	# I tried this:
	#open SAVEOUT, ">&STDOUT";
	#open STDOUT, '+>', \$log;
	#HTMLerror('test');
	#ok($result, '');
	#close STDOUT;
	#open STDOUT, ">&SAVEOUT";
}

sub testhashcolor { # With 16 generated colors, the default rainbow and one custom.
	@testdata = ('FF0333', '3300CC', '990033', 'FF03CC', '990333', 'CC00CC', '000099', '6603CC');
	for ($ii = 0; $ii < 8; $ii++) {
		$result = hashcolor('Current Load', $ii + 1);
		ok($result, $testdata[$ii - 1]);
	}
	@testdata = ('CC0300', 'FF0399', '990000', '330099', '990300', '660399', '990000', 'CC0099');
	for ($ii = 1; $ii < 9; $ii++) {
		$result = hashcolor('PLW', $ii);
		ok($result, $testdata[$ii - 1]);
	}
	$Config{color} = ['123', 'ABC'];
	@testdata = ('123', 'ABC', '123');
	for ($ii = 0; $ii < 3; $ii++) {
		$result = hashcolor('test', 9);
		ok($result, $testdata[$ii]);
	}
}

sub testgetgraphlist { # Does two things: verifies directores and .rrd files.
	$_ = '..';
	getgraphlist();
	ok(%Navmenu, 0, 'Nothing should be set yet');
	$_ = 'test';
	mkdir($_, 0755);
	getgraphlist();
	ok(%Navmenu, 0, 'Nothing should be set yet');
	$_ = 'test/test1';
	open TMP, ">$_";
	print TMP "test1\n";
	close TMP;
	getgraphlist();
	ok(%Navmenu, 0, 'Nothing should be set yet');
	$_ = 'test';
	getgraphlist();
	ok($Navmenu{$_}{NAME}, 'test');
	$_ = 'test/test1.rrd';
	open TMP, ">$_";
	print TMP "test1\n";
	close TMP;
	$File::Find::dir = $FindBin::Bin;
	getgraphlist();
	ok(Dumper($Navmenu{$FindBin::Bin}{SERVICES}), qr"'test/test1.rrd' => \\1"); 
	unlink 'test/test1';
	unlink 'test/test1.rrd';
	rmdir 'test';
}

sub testlisttodict { # Split a string separated by a configured value into hash.
	$Config{testsep} = ',';
	$Config{test} = 'Current Load,PLW,Procs: total,User Count';
	$testvar = listtodict('test');
	foreach $ii ('Current Load','PLW','Procs: total','User Count') {
		ok($testvar->{$ii});
	}
}

sub testcheckdirempty { # Test with an empty directory, then one with a file.
	mkdir 'checkdir', 0770;
	ok(checkdirempty('checkdir'), 1);
	open TMP, '>checkdir/tmp';
	print TMP "test\n";
	close TMP;
	ok(checkdirempty('checkdir'), 0);
	unlink 'checkdir/tmp';
	rmdir 'checkdir';
}

sub testreadconfig { # Check the default configuration
	open LOG, '+>', \$log;
	readconfig('read');
	ok($Config{colorscheme}, 1);
	ok($Config{minimums}{'Mem: free'});
	close LOG;
}

sub testdbfilelist { # Check getting a list of rrd files
	$Config{debug} = 5;
	open LOG, '+>', \$log;
	$Config{rrddir} = $FindBin::Bin;
	$Config{dbseparator} = '';
	@result = dbfilelist('testbox', 'Partition: /');
	ok(@result, 0);
	my $file = "$FindBin::Bin/testbox_Partition%3A%20%2F_test.rrd";
	open TEST, ">$file";
	print TEST "test\n";
	close TEST;
	@result = dbfilelist('testbox', 'Partition: /');
	ok(@result, 1);
	unlink $file;
	close LOG;
	$Config{debug} = 0;
}

sub testgraphinfo { # Depends on testcreaterrd making files
	$Config{debug} = 5;
	open LOG, '+>', \$log;
	$Config{rrddir} = $FindBin::Bin;
	$Config{dbseparator} = '';
	$result = graphinfo('testbox', 'procs', 'procs');
	my $file = $FindBin::Bin . '/testbox_procs_procs.rrd';
	skip(! -f $file, $result->[0]->{file}, 'testbox_procs_procs.rrd');
	skip(! -f $file, $result->[0]->{line}->{uwarn}, 1);
	unlink $file if -f $file;
	$file = $FindBin::Bin . '/testbox_procs_procs.rrd';
	unlink  $file if -f $file;
	close LOG;
	open LOG, '+>', \$log;
	$Config{dbseparator} = 'subdir';
	$result = graphinfo('testbox', 'PING', 'ping');
	$file = $FindBin::Bin . '/testbox/PING___ping.rrd';
	skip(! -f $file, $result->[0]->{file}, 'testbox/PING___ping.rrd');
	skip(! -f $file, $result->[0]->{line}->{rta}, 1);
	close LOG;
	$Config{debug} = 0;
}

sub testrrdline { # TODO: rrdline
}

sub testprintNavMenu { # printNavMenu is like HTMLerror--not really testable.
}

sub testgraphsizes {
	$Config{debug} = 5;
	open LOG, '+>', \$log;
	@result = graphsizes(''); # defaults
	ok($result[0][0], 'dai');
	ok($result[1][2], 604800);
	@result = graphsizes('year month quarter'); # comes back in length order
	ok($result[0][0], 'month');
	ok($result[1][2], 7776000);
	@result = graphsizes('test junk week'); # only returns week
	ok(@result, 1);
	close LOG;
	$Config{debug} = 0;
}

sub testgetlabels {
	$Config{debug} = 5;
	open LOG, '+>', \$log;
	$result = getlabels('diskgb', 'test,junk');
	ok($result->[0], 'Disk Usage');
	$result = getlabels('testing', 'tested,Mem%3A%20swap,junk');
	ok($result->[0], 'Swap Utilization');
	close LOG;
	$Config{debug} = 0;
}

sub testprintlabels { # printlabels isn't testable either.
}

sub testinputdata {
	@testdata = (
		'1221495633||testbox||HTTP||CRITICAL - Socket timeout after 10 seconds||',
		'1221495690||testbox||PING||PING OK - Packet loss = 0%, RTA = 37.06 ms ||losspct: 0%, rta: 37.06'
	);
	# $ARGV[0] array input test, which will only be one line of data
	$ARGV[0] = $testdata[1];
	@result = main::inputdata();
	ok(Dumper($result[0]), Dumper($testdata[1]));
	$Config{perflog} = $FindBin::Bin . '/perfdata.log';
	# a test without data
	delete $ARGV[0];
	open LOG, ">$Config{perflog}";
	close LOG;
	@result = main::inputdata();
	ok(@result, 0);
	# $Config{perflog} input test
	open LOG, ">$Config{perflog}";
	foreach $ii (@testdata) {
		print LOG "$ii\n"; 
	}
	close LOG;
	@result = main::inputdata();
	chomp $result[0];
	ok($result[0], $testdata[0]);
	chomp $result[1];
	ok($result[1], $testdata[1]);
	unlink $Config{perflog};
}

sub testgetRRAs {
	@testdata = (1, 2, 3, 4);
	# $Config{maximums}
	@result = main::getRRAs('Current Load', @testdata);
	ok(Dumper(\@result), "\$VAR1 = [\n          'RRA:MAX:0.5:1:1',\n          'RRA:MAX:0.5:6:2',\n          'RRA:MAX:0.5:24:3',\n          'RRA:MAX:0.5:288:4'\n        ];\n");
	# $Config{minimums}
	@result = main::getRRAs('APCUPSD', @testdata);
	ok(Dumper(\@result), "\$VAR1 = [\n          'RRA:MIN:0.5:1:1',\n          'RRA:MIN:0.5:6:2',\n          'RRA:MIN:0.5:24:3',\n          'RRA:MIN:0.5:288:4'\n        ];\n");
	# default
	@result = main::getRRAs('other value', @testdata);
	ok(Dumper(\@result), "\$VAR1 = [\n          'RRA:AVERAGE:0.5:1:1',\n          'RRA:AVERAGE:0.5:6:2',\n          'RRA:AVERAGE:0.5:24:3',\n          'RRA:AVERAGE:0.5:288:4'\n        ];\n");
}

sub testcreaterrd {
	open LOG, '+>', \$log;
	$Config{rrddir} = $FindBin::Bin;
	# test creation of a separate file for specific data
	$Config{dbseparator} = '';
	$testvar = ['procs', ['users', 'GAUGE', 1], ['uwarn', 'GAUGE', 5] ];
	$Config{hostservvar} = 'testbox,procs,users';
	$Config{hostservvarsep} = ';';
	$Config{hostservvar} = listtodict('hostservvar');
	ok($Config{hostservvar}->{testbox}->{procs}->{users}, 1);
	@result = createrrd('testbox', 'procs', 1221495632, $testvar);
	ok($result[0]->[1], 'testbox_procsusers_procs.rrd');
	ok(-f $FindBin::Bin . '/testbox_procsusers_procs.rrd');
	ok(-f $FindBin::Bin . '/testbox_procs_procs.rrd');
	# test creation of a default data file
	$Config{dbseparator} = 'subdir';
	$testvar = ['ping', ['losspct', 'GAUGE', 0], ['rta', 'GAUGE', .006] ];
	@result = createrrd('testbox', 'PING', 1221495632, $testvar);
	ok($result[0]->[0], 'PING___ping.rrd');
	ok($result[1]->[0]->[0], 0);
	ok($result[1]->[0]->[1], 1);
	close LOG;
}

sub testrrdupdate { # depends on testcreaterrd making a file
	$Config{debug} = 3;
	open LOG, '+>', \$log;
	rrdupdate($result[0]->[0], 1221495633, $testvar, 'testbox', $result[1]->[0]);
	skip(! -f $FindBin::Bin . '/testbox/PING___ping.rrd', $log, "");
	close LOG;
}

sub testgetrules {
	$Config{debug} = 3;
	open LOG, '+>', \$log;
	getrules("$FindBin::Bin/../etc/map");
	ok($log, "");
	ok(*evalrules);
	close LOG;
}

sub testprocessdata { # depends on testcreatedd and testgetrules
	$Config{debug} = 3;
	open LOG, '+>', \$log;
	my @perfdata = ('1221495634||testbox||PING||PING OK - Packet loss = 0%, RTA = 37.06 ms ||losspct: 0%, rta: 37.06');
	processdata(@perfdata);
	skip(! -f $FindBin::Bin . '/testbox/PING___ping.rrd', $log, "");
	close LOG;
	unlink $FindBin::Bin . '/testbox/PING___ping.rrd';
	rmdir $FindBin::Bin . '/testbox';
}

sub testtrans {
	$Config{debug} = 5;
	open LOG, '+>', \$log;
	ok(trans('day'), 'Today');
	close LOG;
	$Config{debug} = 0;
}

testdebug();
testdumper();
testgetdebug();
testurl();
testgetfilename();
testhashcolor();
testgetgraphlist();
testlisttodict();
testcheckdirempty();
testreadconfig();
testdbfilelist();
testgraphsizes();
testgetlabels();
testinputdata();
testgetRRAs();
testcreaterrd();
testrrdupdate();
testgetrules();
testgraphinfo();
testprocessdata();
testtrans();