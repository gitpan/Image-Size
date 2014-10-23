#!/usr/bin/perl -w

use IO::File;
use Image::Size qw(:all);
use Test::More tests => 17;

($dir = $0) =~ s/\w+\.t$//o;

#
# Phase one: basic types tested on files.
#
($x, $y) = imgsize("${dir}test.gif");
ok(($x == 60 && $y == 40), 'Basic GIF format test');

$html = html_imgsize("${dir}letter_T.jpg");
ok(($html =~ /width="52"\s+height="54"/oi),
   'Test html_imgsize and basic JPG format');

@attrs = attr_imgsize("${dir}xterm.xpm");
ok(($attrs[1] == 64 && $attrs[3] == 38),
   'Test attr_imgsize and basic XPM format');

($x, $y) = imgsize("${dir}spacer50.xbm");
ok(($x == 50 && $y == 10), 'Basic XBM format test');

($x, $y, $err) = imgsize("some non-existant file");
ok(($err =~ /can\'t open/oi), 'Test non-existent file error catching');

# The Pak-38 is actually a valid GIF, but this should work:
($x, $y) = imgsize("${dir}pak38.jpg");
ok(($x == 333 && $y == 194), 'Test format/file-extension mis-match');

# Test PNG image supplied by Tom Metro:
($x, $y) = imgsize("${dir}pass-1_s.png");
ok(($x == 90 && $y == 60), 'Basic PNG format test');

# Test PPM image code supplied by Carsten Dominik:
($x, $y, $id) = imgsize("${dir}letter_N.ppm");
ok(($x == 66 && $y == 57 && $id eq 'PPM'), 'Basic PPM format test');

# Test TIFF image code supplied by Cloyce Spradling
($x, $y, $id) = imgsize("${dir}lexjdic.tif");
ok(($x == 35 && $y == 32 && $id eq 'TIF'), 'Basic TIFF format test (1)');
($x, $y, $id) = imgsize("${dir}bexjdic.tif");
ok(($x == 35 && $y == 32 && $id eq 'TIF'), 'Basic TIFF format test (2)');

# Test BMP code from Aldo Calpini
($x, $y, $id) = imgsize("${dir}xterm.bmp");
ok(($x == 64 && $y == 38 && $id eq 'BMP'), 'Basic BMP format test');

# Test SWF code from Dmitry Dorofeev <dima@yasp.com>
($x, $y, $id) = imgsize("${dir}yasp.swf");
ok(($x == 85 && $y == 36 && $id eq 'SWF'), 'Basic SWF format test');

# Test CWS patch from mrj@mrj.spb.ru
($x, $y, $id) = imgsize("${dir}8.swf");
ok(($x == 280 && $y == 140 && $id eq 'CWS'), 'Basic CWS format test');

# Test the PSD code (orig. contributer unknown)
($x, $y, $id) = imgsize("${dir}468x60.psd");
ok(($x == 468 && $y == 60 && $id eq 'PSD'), 'Basic PSD format test');

#
# Phase two: tests on in-memory strings.
#
$fh = new IO::File "< ${dir}test.gif";
$data = '';
read $fh, $data, (stat "${dir}test.gif")[7];
$fh->close;
($x, $y, $id) = imgsize(\$data);
ok(($x == 60 && $y == 40 && $id eq 'GIF'), 'Test in-memory image data');

#
# Phase three: tests on open IO::File objects.
#
$fh = new IO::File "< ${dir}test.gif";
($x, $y, $id) = imgsize($fh);
ok(($x == 60 && $y == 40 && $id eq 'GIF'), 'Test open IO::File object');

# Reset to head
$fh->seek(0, 0);
# Move somewhere
$fh->seek(128, 0);
# Do it again. This time when we check results, $fh->tell should be 128
($x, $y, $id) = imgsize($fh);
ok(($x == 60 && $y == 40 && $id eq 'GIF' && ($fh->tell == 128)),
   'Test that it leaves open IO::File object in the same position');

$fh->close;

exit;
