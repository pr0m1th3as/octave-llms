/*
Copyright (C) 2025 Andreas Bertsatos <abertsatos@biol.uoa.gr>

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program; if not, see <http://www.gnu.org/licenses/>.
*/

#include <octave/oct.h>
#include <octave/parse.h>

#include "./include/Base64.h"
#include "./include/fpng.h"

using namespace std;

DEFMETHOD_DLD (fig2base64, interp, args, nargout,
           "-*- texinfo -*-\n\
 @deftypefn {} {@var{base64} =} fig2base64 (@var{hfig}) \n\
\n\
\n\
This function returns a PNG base64 encoded string from the figure specified by \
graphics handle HFIG. \
\n\
@end deftypefn")
{
  // Parse input arguments
  if (args.length () != 1)
  {
    error ("fig2base64: invalig number of input arguments.");
  }
  // Get image from figure and save it into a uint8NDArray
  double h = args(0).xdouble_value ("fig2base64: HFIG is not a handle.");
  octave::gh_manager& gh_mgr = interp.get_gh_manager ();
  octave::graphics_object go = gh_mgr.get_object (h);
  if (! go || ! go.isa ("figure"))
  {
    error ("fig2base64: HFIG is not a figure.");
  }
  gh_mgr.process_events ();
  octave_value img = go.get_toolkit ().get_pixels (go);
  uint8NDArray data = img.uint8_array_value ();

  // Map image from uint8NDArray to unsigned char
  size_t bytes = data.numel ();
  size_t rows = data.rows ();
  size_t cols = data.columns ();
  uint32_t ch = 3;
  unsigned char* pixels = new unsigned char[bytes];
  size_t i = 0;
  for (octave_idx_type r = 0; r < rows; r++)
  {
    for (octave_idx_type c = 0; c < cols; c++)
    {
      pixels[i++] = data(r, c, 0);
      pixels[i++] = data(r, c, 1);
      pixels[i++] = data(r, c, 2);
    }
  }

  // Convert image to base64
  vector<unsigned char> buffer;
  // Convert image to png
  fpng::fpng_init();
  bool ok = fpng::fpng_encode_image_to_memory (pixels, cols, rows, ch, buffer);
  if (! ok)
  {
    error ("fig2base64: unable to convert image to PNG.");
  }
  string png_data = string(buffer.begin (), buffer.end ());
  string base64 = macaron::Base64::Encode (png_data);

  // Clear memory
  delete [] pixels;

  // Return string_base64 encoded image
  octave_value_list retval (nargout);
  retval(0) = base64;
  return retval;
}
