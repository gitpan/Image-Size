###############################################################################
#
# This code lifted almost verbatim from wwwis by Alex Knowles, alex@ed.ac.uk
#
# Minor changes (removed setting of globals) to imgsize() and structuring into
# Perl5 package form by rjray@uswest.com.
#
# Release 1.1:
#   Fixed bug in jpegsize
#   Clarified some comments and docs
# Up to release 1.0:
#   Turned sizing into a library
#   Added two wrappers to pre-format size into HTML or CGI attributes
#   Added cacheing of sizes for multiple calls (I have a script that emits the
#     same image 35+ times!)
#   Simple test suite to test each image type I have a sample of (all save for
#     PNG) and some of the error conditions. MakeMaker utility automatically
#     configures in the test suite.
#
###############################################################################

package Image::Size;

=head1 NAME

Image::Size - read the dimensions of an image in several popular formats

=head1 SYNOPSIS

    use Image::Size;
    # Get the size of globe.gif
    ($globe_x, $globe_y) = imgsize("globe.gif");
    # Assume X=60 and Y=40 for remaining examples

    use Image::Size 'html_imgsize';
    # Get the size as "HEIGHT=X WIDTH=Y" for HTML generation
    $size = html_imgsize("globe.gif");
    # $size == "HEIGHT=60 WIDTH=40"

    use Image::Size 'attr_imgsize';
    # Get the size as a list passable to routines in CGI.pm
    @attrs = attr_imgsize("globe.gif");
    # @attrs == ('-HEIGHT', 60, '-WIDTH', 40)

    use Image::Size;
    # Get the size of an in-memory buffer
    ($buf_x, $buf_y) = imgsize($buf);

=head1 DESCRIPTION

The B<Image::Size> library is based upon the C<wwwis> script written by
Alex Knowles I<(alex@ed.ac.uk)>, a tool to examine HTML and add HEIGHT and
WIDTH parameters to image tags. The sizes are cached internally based on
file name, so multiple calls on the same file name (such as images used
in bulleted lists, for example) do not result in repeated computations.

B<Image::Size> provides three interfaces for possible import:

=over

=item imgsize(I<stream>)

Returns a three-item list of the X and Y dimensions (height and width, in
that order) and image type of I<stream>. Errors are noted by undefined
B<undef> value for the first two elements, and an error string in the third.
The third element can be (and usually is) ignored, but is useful when
sizing data whose type is unknown.

=item html_imgsize(I<stream>)

Returns the height and width (X and Y) of I<stream> pre-formatted as a single
string C<"HEIGHT=X WIDTH=Y"> suitable for addition into generated HTML IMG
tags. If the underlying call to C<imgsize> fails, B<undef> is returned.

=item attr_imgsize(I<stream>)

Returns the height and width of I<stream> as part of a 4-element list useful
for routines that use hash tables for the manipulation of named parameters,
such as the Tk or CGI libraries. A typical return value looks like
C<("-HEIGHT", X, "-WIDTH", Y)>. If the underlying call to C<imgsize> fails,
B<undef> is returned.

=back

By default, only C<imgsize()> is imported. Any one or
combination of the three may be imported, or all three may be with the
tag B<:all>.

=head2 Input Types

The sort of data passed as I<stream> can be one of three forms:

=over

=item string

If an ordinary scalar (string) is passed, it is assumed to be a file name
(either absolute or relative to the current working directory of the
process) and is searched for and opened (if found) as the source of data.
Possible error messages (see DIAGNOSTICS below) may include file-access
problems.

=item scalar reference

If the passed-in stream is a scalar reference, it is interpreted as pointing
to an in-memory buffer containing the image data.

        # Assume that &read_data gets data somewhere (WWW, etc.)
        $img = &read_data;
        ($x, $y, $id) = imgsize(\$img);
        # $x and $y are dimensions, $id is the type of the image

=item IO::File object reference

The third option is to pass in an object of the C<IO::File> class that has
already been instantiated on the target image file. The file pointer will
necessarily move, but will be restored to its original position before
subroutine end.

        # $fh was passed in, is IO::File reference:
        ($x, $y, $id) = imgsize($fh);
        # Same as calling with filename, but more abstract.

=back

=head2 Recognizd Formats

Image::Size understands and sizes data in the following formats:

=over

=item

GIF

=item

JPG

=item

XBM

=item

XPM

=item

PPM family (PPM/PGM/PBM)

=item

PNG

=back

When using the C<imgsize> interface, there is a third, unused value returned
if the programmer wishes to save and examine it. This value is the three-
letter identity of the data type. This is useful when operating on open
file handles or in-memory data, where the type is as unknown as the size.
The two support routines ignore this third return value, so those wishing to
use it must use the base C<imgsize> routine.

=head1 DIAGNOSTICS

The base routine, C<imgsize>, returns B<undef> as the first value in its list
when an error has occured. The third element contains a descriptive
error message.

The other two routines simply return B<undef> in the case of error.

=head1 CAVEATS

This will reliably work on perl 5.002 or newer. Perl versions prior to
5.003 do not have the B<IO::File> module by default, which this module
requires. You will have to retrieve and install it, or upgrade to 5.003,
in which it is included as part of the core.

Caching of size data can only be done on inputs that are file names. Open
file handles and scalar references cannot be reliably transformed into a
unique key for the table of cache data. Buffers could be cached using the
MD5 module, and perhaps in the future I will make that an option. I do not,
however, wish to lengthen the dependancy list by another item at this time.

=head1 SEE ALSO

C<http://www.tardis.ed.ac.uk/~ark/wwwis/> for a description of C<wwwis>
and how to obtain it.

=head1 AUTHORS

Perl module interface by Randy J. Ray I<(rjray@uswest.com)>, original
image-sizing code by Alex Knowles I<(alex@ed.ac.uk)> and Andrew Tong
I<(werdna@ugcs.caltech.edu)>, used with their joint permission.

Some bug fixes submitted by Bernd Leibing I<(bernd.leibing@rz.uni-ulm.de)>.
PPM/PGM/PBM sizing code contributed by Carsten Dominik
I<(dominik@strw.LeidenUniv.nl)>. Tom Metro I<(tmetro@vl.com)> re-wrote the JPG
and PNG code, and also provided a PNG image for the test suite. Dan Klein
I<(dvk@lonewolf.com)> contributed a re-write of the GIF code.

=cut

require 5.002;

use strict qw(vars subs);
use IO::File;
use AutoLoader;
use Exporter;
use vars qw($revision $VERSION $read_in $last_pos);

@Image::Size::ISA         = qw(Exporter AutoLoader);
@Image::Size::EXPORT      = qw(imgsize);
@Image::Size::EXPORT_OK   = qw(imgsize html_imgsize attr_imgsize);
%Image::Size::EXPORT_TAGS = (q/all/ => [@Image::Size::EXPORT_OK]);

$Image::Size::revision    = q$Id: Size.pm,v 1.4 1996/11/29 23:18:55 rjray Exp $;
$Image::Size::VERSION     = "2.1";

# Package lexicals - invisible to outside world, used only in imgsize
#
# Cache of files seen, and mapping of patterns to the sizing routine
my %cache = ();

my %type_map = ( 'GIF8[7,9]a'              => 'gifsize',
                 "\xFF\xD8"                => 'jpegsize',
                 "\x89PNG\x0d\x0a\x1a\x0a" => 'pngsize',
                 "^P[1-6]\n"               => 'ppmsize',
                 '\#define\s+\S+\s+\d+'    => 'xbmsize',
                 '\/\* XPM \*\/'           => 'xpmsize' );

#
# These are lexically-scoped anonymous subroutines for reading the three
# types of input streams. When the input to imgsize() is typed, then the
# lexical "read_in" is assigned one of these, thus allowing the individual
# routines to operate on these streams abstractly.
#

my $read_io = sub {
    my $handle = shift;
    my ($length, $offset) = @_;

    if (defined($offset) && ($offset != $last_pos))
    {
        $last_pos = $offset;
        return '' if (! $handle->seek($offset, 0));
    }

    my ($data, $rtn) = ('', 0);
    $rtn = read $handle, $data, $length;
    $data = '' unless ($rtn);
    $last_pos = $handle->tell;

    $data;
};

my $read_buf = sub {
    my $buf = shift;
    my ($length, $offset) = @_;

    if (defined($offset) && ($offset != $last_pos))
    {
        $last_pos = $offset;
        return '' if ($last_pos > length($$buf));
    }

    my $data = substr($$buf, $last_pos, $length);
    $last_pos += length($data);

    $data;
};
        
1;

sub imgsize
{
    my $stream = shift;

    my ($handle, $header);
    my ($x, $y, $id);
    # These only used if $stream is an existant open FH
    my ($save_pos, $need_restore) = (0, 0);

    $header = '';

    if (ref($stream) eq 'IO::File')
    {
        $handle = $stream;
        $read_in = $read_io;
        $save_pos = $handle->tell;
        $need_restore = 1;

        #
        # First alteration (didn't wait long, did I?) to the existant handle:
        #
        $handle->seek(0, 0);
        read $handle, $header, 80;
        $handle->seek(0, 0);
    }
    elsif (ref($stream) eq "SCALAR")
    {
        $handle = $stream;
        $read_in = $read_buf;
        $header = substr($$handle, 0, 80);
    }
    else
    {
        if (-e "$stream" && exists $cache{$stream})
        {
            return (split(/,/, $cache{$stream}));
        }

        #first try to open the stream
        $handle = new IO::File "< $stream";
        return (undef, undef, "Can't open image file $stream: $!")
            unless (defined $handle);

        read $handle, $header, 80;
        $handle->seek(0, 0);
        $read_in = $read_io;
    }
    $last_pos = 0;

    #
    # Oh pessimism... set the values of $x and $y to the error condition. If
    # the grep() below matches the data to one of the known types, then the
    # called subroutine will override these...
    #
    $id = "Data stream is not gif, xbm, xpm, jpeg, png, ppm, pgm or pbm";
    $x  = undef;
    $y  = undef;

    grep($header =~ /^$_/ && (($x, $y, $id) = &{$type_map{$_}}($handle)),
         keys %type_map);
    
    #
    # Added as an afterthought: I'm probably not the only one who uses the
    # same shaded-sphere image for several items on a bulleted list:
    #
    $cache{$stream} = join(',', $x, $y) unless (ref $stream);

    #
    # If we were passed an existant IO::File object, we need to restore the
    # old filepos:
    #
    $handle->seek($save_pos, 0) if ($need_restore);

    # results:
    ($x, $y, $id);
}

sub html_imgsize
{
    my @args = imgsize(@_);

    return ((defined $args[0]) ?
            sprintf("WIDTH=%d HEIGHT=%d", @args) :
            undef);
}

sub attr_imgsize
{
    my @args = imgsize(@_);

    return ((defined $args[0]) ?
            (('-WIDTH', '-HEIGHT', imgsize(@_))[0, 2, 1, 3]) :
            undef);
}

# This used only in gifsize:
sub img_eof
{
    my $stream = shift;

    return ($last_pos >= length($$stream)) if (ref($stream) eq "SCALAR");

    $stream->eof;
}

__END__

###########################################################################
# Subroutine gets the size of the specified GIF
###########################################################################
sub gifsize
{
    my $stream = shift;

    my ($cmapsize, $buf, $h, $w, $x, $y, $type);
    
    sub gif_blockskip
    {
        my ($skip, $type) = @_;
        my ($lbuf);

        &$read_in($stream, $skip);        # Skip header (if any)
        while (1)
        {
            if (&img_eof($stream))
            {
                return (undef, undef,
                        "Invalid/Corrupted GIF (at EOF in GIF $type)");
            }
            $lbuf = &$read_in($stream, 1);        # Block size
            last if ord($lbuf) == 0;     # Block terminator
            &$read_in($stream, ord($lbuf));  # Skip data
        }
    }

    $type = &$read_in($stream, 6);
    if (length($buf = &$read_in($stream, 7)) != 7 )
    {
        return (undef, undef, "Invalid/Corrupted GIF (bad header)");
    }
    ($x) = unpack("x4 C", $buf);
    if ($x & 0x80)
    {
        $cmapsize = 3 * (2**(($x & 0x07) + 1));
        if (! &$read_in($stream, $cmapsize))
        {
            return (undef, undef,
                    "Invalid/Corrupted GIF (global color map too small?)");
        }
    }

  FINDIMAGE:
    while (1)
    {
        if (&img_eof($stream))
        {
            return (undef, undef,
                    "Invalid/Corrupted GIF (at EOF w/o Image Descriptors)");
        }
        $buf = &$read_in($stream, 1);
        ($x) = unpack("C", $buf);
        if ($x == 0x2c)
        {
            # Image Descriptor (GIF87a, GIF89a 20.c.i)
            if (length($buf = &$read_in($stream, 8)) != 8)
            {
                return (undef, undef,
                        "Invalid/Corrupted GIF (missing image header?)");
            }
            ($x, $w, $y, $h) = unpack("x4 C4", $buf);
            $x += $w * 256;
            $y += $h * 256;
            return ($x, $y, 'GIF');
        }
        if ($type eq "GIF89a")
        {
            if ($x == 0x21)
            {
                # Extension Introducer (GIF89a 23.c.i)
                $buf = &$read_in($stream, 1);
                ($x) = unpack("C", $buf);
                if ($x == 0xF9)
                {
                    # Graphic Control Extension (GIF89a 23.c.ii)
                    &$read_in($stream, 6);    # Skip it
                    next FINDIMAGE;       # Look again for Image Descriptor
                }
                elsif ($x == 0xFE)
                {
                    # Comment Extension (GIF89a 24.c.ii)
                    gif_blockskip(0, "Comment");
                    next FINDIMAGE;       # Look again for Image Descriptor
                }
                elsif ($x == 0x01)
                {
                    # Plain Text Label (GIF89a 25.c.ii)
                    gif_blockskip(13, "text data");
                    next FINDIMAGE;       # Look again for Image Descriptor
                }
                elsif ($x == 0xFF)
                {
                    # Application Extension Label (GIF89a 26.c.ii)
                    gif_blockskip(12, "application data");
                    next FINDIMAGE;       # Look again for Image Descriptor
                }
                else
                {
                    return (undef, undef,
                            sprintf("Invalid/Corrupted GIF (Unknown " .
                                    "extension %#x)", $x));
                }
            }
            else
            { 
                return (undef, undef,
                        sprintf("Invalid/Corrupted GIF (Unknown code %#x)",
                                $x));
            }
        }
        else
        {
            return (undef, undef,
                    "Invalid/Corrupted GIF (missing GIF87a Image Descriptor)");
        }
    } 
}

sub xbmsize
{
    my $stream = shift;

    my $input;
    my ($x, $y, $id) = (undef, undef, "Could not determine XBM size");
    
    $input = &$read_in($stream, 160);
    if ($input =~ /^\#define\s*\S*\s*(\d*)\s*\n\#define\s*\S*\s*(\d*)\s*\n/moi)
    {
        ($x, $y) = ($1, $2);
        $id = 'XBM';
    }

    ($x, $y, $id);
}

# Added by Randy J. Ray, 30 Jul 1996
# Size an XPM file by looking for the "X Y N W" line, where X and Y are
# dimensions, N is the total number of colors defined, and W is the width of
# a color in the ASCII representation, in characters. We only care about X & Y.
sub xpmsize
{
    my $stream = shift;

    my $line;
    my ($x, $y, $id) = (undef, undef, "Could not determine XPM size");

    while ($line = &$read_in($stream, 1024))
    {
        next unless ($line =~ /"(\d+)\s+(\d+)\s+\d+\s+\d+"/mo);
        ($x, $y) = ($1, $2);
        $id = 'XPM';
        last;
    }

    ($x, $y, $id);
}


# pngsize : gets the width & height (in pixels) of a png file
# cor this program is on the cutting edge of technology! (pity it's blunt!)
#
# Re-written and tested by tmetro@vl.com
sub pngsize
{
    my $stream = shift;

    my ($x, $y, $id) = (undef, undef, "could not determine PNG size");
    my ($offset, $length);

    # Offset to first Chunk Type code = 8-byte ident + 4-byte chunk length + 1
    $offset = 12; $length = 4;
    if (&$read_in($stream, $length, $offset) eq 'IHDR')
    {
        # IHDR = Image Header
        $length = 8;
        ($x, $y) = unpack("NN", &$read_in($stream, $length));
        $id = 'PNG';
    }

    ($x, $y, $id);
}

# jpegsize: gets the width and height (in pixels) of a jpeg file
# Andrew Tong, werdna@ugcs.caltech.edu           February 14, 1995
# modified slightly by alex@ed.ac.uk
# and further still by rjray@uswest.com
# optimization and general re-write from tmetro@vl.com
sub jpegsize
{
    my $stream = shift;

    my $MARKER      = "\xFF";       # Section marker.

    my $SIZE_FIRST  = 0xC0;         # Range of segment identifier codes
    my $SIZE_LAST   = 0xC3;         #  that hold size info.

    my ($x, $y, $id) = (undef, undef, "could not determine JPEG size");

    my ($marker, $code, $length);
    my $segheader;

    # Dummy read to skip header ID
    &$read_in($stream, 2);
    while (1)
    {
        $length = 4;
        $segheader = &$read_in($stream, $length);

        # Extract the segment header.
        ($marker, $code, $length) = unpack("a a n", $segheader);

        # Verify that it's a valid segment.
        if ($marker ne $MARKER)
        {
            # Was it there?
            $id = "JPEG marker not found";
            last;
        }
        elsif ((ord($code) >= $SIZE_FIRST) && (ord($code) <= $SIZE_LAST))
        {
            # Segments that contain size info
            $length = 5;
            ($y, $x) = unpack("xnn", &$read_in($stream, $length));
            last;
        }
        else
        {
            # Dummy read to skip over data
            &$read_in($stream, ($length - 2));
        }
    }

    ($x, $y, $id);
}

# ppmsize: gets data on the PPM/PGM/PBM family.
#
# Contributed by Carsten Dominik <dominik@strw.LeidenUniv.nl>
sub ppmsize
{
    my $stream = shift;

    my ($x, $y, $id) = (undef, undef,
                        "Unable to determine size of PPM/PGM/PBM data");
    my $n;

    my $header = &$read_in($stream, 64);

    # PPM file of some sort
    $header =~ s/^\#.*//mg;
    ($n, $x, $y) = ($header =~ /^(P[1-6])\s+(\d+)\s+(\d+)/mo);
    $id = "PBM" if $n eq "P1" || $n eq "P4";
    $id = "PGM" if $n eq "P2" || $n eq "P5";
    $id = "PPM" if $n eq "P3" || $n eq "P6";

    ($x, $y, $id);
}
