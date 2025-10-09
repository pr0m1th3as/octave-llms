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

#include "./include/ollama.hpp"

#include <iostream>
#include <string>
#include <functional>
#include <thread>
#include <chrono>
#include <atomic>

#include <octave/oct.h>
#include <octave/Cell.h>
#include <octave/ov-struct.h>

using namespace std;
using json = nlohmann::json;

DEFUN_DLD (__ollama__, args, nargout,
           "-*- texinfo -*-\n\
 @deftypefn {} {[@var{txt}, @{err}] =} __ollama__ (@var{Name}, @var{Value})\n\
\n\
\n\
A compiled interface for ollama server. \n\
\n\
@end deftypefn")
{
  // Initialize output arguments
  if (nargout != 2)
  {
    error ("__ollama__: two output arguments are required.");
  }
  octave_value_list retval (nargout);
  // Check server is running
  bool running = ollama::is_running ();
  retval(1) = ! running;
  // Initialize variables for inference
  string model = "";
  string prompt = "";
  ollama::images images;
  bool has_images = false;
  ollama::options options;
  bool has_options = false;
  ollama::messages messages;
  bool has_messages = false;
  // Initialize variables for handling models and server
  bool query_status = false;
  bool query_version = false;
  string source = "";
  string target = "";
  bool do_loadModel = false;
  bool do_pullModel = false;
  bool do_copyModel = false;
  bool do_deleteModel = false;
  string modelInfoName = "";
  bool do_modelInfo = false;
  bool do_listModels = false;
  bool do_listRunningModels = false;
  bool return_cellstr = false;

  // Validate and parse inputs
  if (args.length () % 2 != 0)
  {
    error ("__ollama__: input arguments must be in Name-Value pairs.");
  }
  for (octave_idx_type p = 0; p < args.length (); p += 2)
  {
    if (args(p).isempty () || args(p+1).isempty ())
    {
      error ("__ollama__: input arguments cannot be empty.");
    }
    if (! args(p).is_string ())
    {
      error ("__ollama__: parameter name must be a character vector.");
    }
    if (args(p).string_value () == "model")
    {
      if (! args(p+1).is_string ())
      {
        error ("__ollama__: 'model' value must be a character vector.");
      }
      model = args(p+1).string_value ();
    }
    else if (args(p).string_value () == "prompt")
    {
      if (! args(p+1).is_string ())
      {
        error ("__ollama__: 'prompt' value must be a character vector.");
      }
      prompt = args(p+1).string_value ();
    }
    else if (args(p).string_value () == "serverURL")
    {
      if (! args(p+1).is_string ())
      {
        error ("__ollama__: 'serverURL' value must be a character vector.");
      }
      ollama::setServerURL (args(p+1).string_value ());
      running = ollama::is_running ();
      if (! running)
      {
        retval(0) = running;
        retval(1) = true; // flag for error
        return retval;
      }
    }
    else if (args(p).string_value () == "readTimeout")
    {
      if (! args(p+1).is_scalar_type () || ! args(p+1).is_double_type ())
      {
        error ("__ollama__: 'readTimeout' value must be a double scalar.");
      }
      ollama::setReadTimeout (args(p+1).double_value ());
    }
    else if (args(p).string_value () == "writeTimeout")
    {
      if (! args(p+1).is_scalar_type () || ! args(p+1).is_double_type ())
      {
        error ("__ollama__: 'writeTimeout' value must be a double scalar.");
      }
      ollama::setWriteTimeout (args(p+1).double_value ());
    }
    else if (args(p).string_value () == "Query")
    {
      // Can be either 'status' or 'version'
      if (! args(p+1).is_string ())
      {
        error ("__ollama__: 'Query' value must be a character vector.");
      }
      if (args(p+1).string_value () == "status")
      {
        query_status = true;
      }
      else if (args(p+1).string_value () == "version")
      {
        query_version = true;
      }
      else
      {
        error ("__ollama__: invalid value for 'Query'.");
      }
    }
    else if (args(p).string_value () == "loadModel")
    {
      if (! args(p+1).is_string ())
      {
        error ("__ollama__: 'loadModel' value must be a character vector.");
      }
      if (do_pullModel || do_copyModel || do_deleteModel)
      {
        error ("__ollama__: either load, pull, copy, or delete a model.");
      }
      source = args(p+1).string_value ();
      do_loadModel = true;
    }
    else if (args(p).string_value () == "pullModel")
    {
      if (! args(p+1).is_string ())
      {
        error ("__ollama__: 'pullModel' value must be a character vector.");
      }
      if (do_loadModel || do_copyModel || do_deleteModel)
      {
        error ("__ollama__: either load, pull, copy, or delete a model.");
      }
      source = args(p+1).string_value ();
      do_pullModel = true;
    }
    else if (args(p).string_value () == "copyModel")
    {
      if (! args(p+1).iscellstr () || args(p+1).cell_value ().numel () != 2)
      {
        error ("__ollama__: 'copyModel' value must be a cellstring with two elements.");
      }
      if (do_loadModel || do_pullModel || do_deleteModel)
      {
        error ("__ollama__: either load, pull, copy, or delete a model.");
      }
      Cell fnames = args(p+1).cell_value ();
      source = fnames(0).string_value ();
      target = fnames(1).string_value ();
      do_copyModel = true;
    }
    else if (args(p).string_value () == "deleteModel")
    {
      if (! args(p+1).is_string ())
      {
        error ("__ollama__: 'deleteModel' value must be a character vector.");
      }
      if (do_loadModel || do_pullModel || do_copyModel)
      {
        error ("__ollama__: either load, pull, copy, or delete a model.");
      }
      source = args(p+1).string_value ();
      do_deleteModel = true;
    }
    else if (args(p).string_value () == "modelInfo")
    {
      if (! args(p+1).is_string ())
      {
        error ("__ollama__: 'modelInfo' value must be a character vector.");
      }
      modelInfoName = args(p+1).string_value ();
      do_modelInfo = true;
    }
    else if (args(p).string_value () == "listModels")
    {
      // Can be either 'string' or 'json'
      if (! args(p+1).is_string ())
      {
        error ("__ollama__: 'listModels' value must be a character vector.");
      }
      if (args(p+1).string_value () == "cellstr")
      {
        return_cellstr = true;
      }
      else if (args(p+1).string_value () != "json")
      {
        error ("__ollama__: invalid value for 'listModels'.");
      }
      if (do_listRunningModels)
      {
        error ("__ollama__: specify either 'listModels' or 'listRunningModels'.");
      }
      do_listModels = true;
    }
    else if (args(p).string_value () == "listRunningModels")
    {
      // Can be either 'string' or 'json'
      if (! args(p+1).is_string ())
      {
        error ("__ollama__: 'listRunningModels' name must be a character vector.");
      }
      if (args(p+1).string_value () == "cellstr")
      {
        return_cellstr = true;
      }
      else if (args(p+1).string_value () != "json")
      {
        error ("__ollama__: invalid value for 'listRunningModels'.");
      }
      if (do_listModels)
      {
        error ("__ollama__: specify either 'listModels' or 'listRunningModels'.");
      }
      do_listRunningModels = true;
    }
    else if (args(p).string_value () == "imageFile")
    {
      if (args(p+1).is_string ())
      {
        ollama::image image = ollama::image::from_file (args(p+1).string_value ());
        images = {image};
      }
      else if (args(p+1).iscellstr ())
      {
        Cell files = args(p+1).cell_value ();
        for (octave_idx_type f = 0; f < files.numel (); f++)
        {
          ollama::image image = ollama::image::from_file (files(f).string_value ());
          images.push_back (image);
        }
      }
      else
      {
        error ("__ollama__: 'imageFile' name must be a character vector or a cell array of character vectors.");
      }
      if (has_images)
      {
        error ("__ollama__: specify either 'imageFile' or 'imageBase64'.");
      }
      has_images = true;
    }
    else if (args(p).string_value () == "imageBase64")
    {
      if (args(p+1).is_string ())
      {
        ollama::image image = ollama::image::from_base64_string (args(p+1).string_value ());
        images = {image};
      }
      else if (args(p+1).iscellstr ())
      {
        Cell files = args(p+1).cell_value ();
        for (octave_idx_type f = 0; f < files.numel (); f++)
        {
          ollama::image image = ollama::image::from_base64_string (files(f).string_value ());
          images.push_back (image);
        }
      }
      else
      {
        error ("__ollama__: 'imageBase64' name must be a character vector or a cell array of character vectors.");
      }
      if (has_images)
      {
        error ("__ollama__: specify either 'imageFile' or 'imageBase64'.");
      }
      has_images = true;
    }
    else if (args(p).string_value () == "options")
    {
      // Must be a scalar structure
      if (! args(p+1).isstruct ())
      {
        error ("__ollama__: 'options' value must be a scalar structure.");
      }
      // Acceptable fields are:
      // "num_keep"       -> integer       "presence_penalty"  -> double
      // "seed"           -> integer       "frequency_penalty" -> double
      // "num_predict"    -> integer       "penalize_newline"  -> logical
      // "top_k"          -> integer       "numa"              -> logical
      // "top_p"          -> double        "num_ctx"           -> integer
      // "min_p"          -> double        "num_batch"         -> integer
      // "typical_p"      -> double        "num_gpu"           -> integer
      // "repeat_last_n"  -> integer       "main_gpu"          -> integer
      // "temperature"    -> double        "use_mmap"          -> logical
      // "repeat_penalty" -> double        "num_thread"        -> integer
      octave_scalar_map opt = args(p+1).scalar_map_value ();
      if (opt.isfield ("num_keep")) {
        options["num_keep"] = opt.contents ("num_keep").int_value ();
        has_options = true; }
      if (opt.isfield ("seed")) {
        options["seed"] = opt.contents ("seed").int_value ();
        has_options = true; }
      if (opt.isfield ("num_predict")) {
        options["num_predict"] = opt.contents ("num_predict").int_value ();
        has_options = true; }
      if (opt.isfield ("top_k")) {
        options["top_k"] = opt.contents ("top_k").int_value ();
        has_options = true; }
      if (opt.isfield ("top_p")) {
        options["top_p"] = opt.contents ("top_p").double_value ();
        has_options = true; }
      if (opt.isfield ("min_p")) {
        options["min_p"] = opt.contents ("min_p").double_value ();
        has_options = true; }
      if (opt.isfield ("typical_p")) {
        options["typical_p"] = opt.contents ("typical_p").double_value ();
        has_options = true; }
      if (opt.isfield ("repeat_last_n")) {
        options["repeat_last_n"] = opt.contents ("repeat_last_n").int_value ();
        has_options = true; }
      if (opt.isfield ("temperature")) {
        options["temperature"] = opt.contents ("temperature").double_value ();
        has_options = true; }
      if (opt.isfield ("repeat_penalty")) {
        options["repeat_penalty"] = opt.contents ("repeat_penalty").double_value ();
        has_options = true; }
      if (opt.isfield ("presence_penalty")) {
        options["presence_penalty"] = opt.contents ("presence_penalty").double_value ();
        has_options = true; }
      if (opt.isfield ("frequency_penalty")) {
        options["frequency_penalty"] = opt.contents ("frequency_penalty").double_value ();
        has_options = true; }
      if (opt.isfield ("penalize_newline")) {
        options["penalize_newline"] = opt.contents ("penalize_newline").bool_value ();
        has_options = true; }
      if (opt.isfield ("numa")) {
        options["numa"] = opt.contents ("numa").bool_value ();
        has_options = true; }
      if (opt.isfield ("num_ctx")) {
        options["num_ctx"] = opt.contents ("num_ctx").int_value ();
        has_options = true; }
      if (opt.isfield ("num_batch")) {
        options["num_batch"] = opt.contents ("num_batch").int_value ();
        has_options = true; }
      if (opt.isfield ("num_gpu")) {
        options["num_gpu"] = opt.contents ("num_gpu").int_value ();
        has_options = true; }
      if (opt.isfield ("main_gpu")) {
        options["main_gpu"] = opt.contents ("main_gpu").int_value ();
        has_options = true; }
      if (opt.isfield ("use_mmap")) {
        options["use_mmap"] = opt.contents ("use_mmap").bool_value ();
        has_options = true; }
      if (opt.isfield ("num_thread")) {
        options["num_thread"] = opt.contents ("num_thread").int_value ();
        has_options = true; }
    }
  }

  // Start communication with ollama server
  // Tasks without inference first
  if (! running)
  {
    retval(0) = false;
    retval(1) = true;
    return retval;
  }
  if (query_status)
  {
    retval(0) = true;
    retval(1) = false;
    return retval;
  }
  if (query_version)
  {
    string version = ollama::get_version ();
    retval(0) = version;
    retval(1) = false;
    return retval;
  }
  if (do_loadModel)
  {
    bool model_loaded = ollama::load_model (source);
    retval(0) = model_loaded;
    retval(1) = ! model_loaded;
    return retval;
  }
  if (do_pullModel)
  {
    bool model_pulled = false;
    try
    {
      model_pulled = ollama::pull_model (source);
      retval(0) = model_pulled;
      retval(1) = false;
    }
    catch (ollama::exception& err)
    {
      string errmsg = err.what ();
      retval(0) = errmsg;
      retval(1) = true;
    }
    return retval;
  }
  if (do_copyModel)
  {
    bool model_copied = false;
    try
    {
      model_copied = ollama::copy_model (source, target);
      retval(0) = model_copied;
      retval(1) = false;
    }
    catch (ollama::exception& err)
    {
      string errmsg = err.what ();
      retval(0) = errmsg;
      retval(1) = true;
    }
    return retval;
  }
  if (do_deleteModel)
  {
    bool model_deleted = false;
    try
    {
      model_deleted = ollama::delete_model (source);
      retval(0) = model_deleted;
      retval(1) = false;
    }
    catch (ollama::exception& err)
    {
      string errmsg = err.what ();
      retval(0) = errmsg;
      retval(1) = true;
    }
    return retval;
  }
  if (do_modelInfo)
  {
    // Check first that model is available to avoid error
    vector<string> models = ollama::list_models ();
    try
    {
      for (int m = 0; m < models.size (); m++)
      {
        if (models[m] == modelInfoName)
        {
          json m_info = ollama::show_model_info (modelInfoName);
          retval(0) = m_info.dump ();
          retval(1) = false;
        }
      }
    }
    catch (ollama::exception& err)
    {
      string errmsg = err.what ();
      retval(0) = errmsg;
      retval(1) = true;
    }
    return retval;
  }
  if (do_listModels)
  {
    try
    {
      if (return_cellstr)
      {
        vector<string> models = ollama::list_models ();
        size_t model_num = models.size ();
        Cell model_names (model_num, 1);
        for (int m = 0; m < model_num; m++)
        {
          model_names(m, 0) = models[m];
        }
        retval(0) = model_names;
        retval(1) = false;
      }
      else
      {
        json json_models = ollama::list_model_json ();
        string models = json_models.dump ();
        retval(0) = models;
        retval(1) = false;
      }
    }
    catch (ollama::exception& err)
    {
      string errmsg = err.what ();
      retval(0) = errmsg;
      retval(1) = true;
    }
    return retval;
  }
  if (do_listRunningModels)
  {
    try
    {
      if (return_cellstr)
      {
        vector<string> models = ollama::list_running_models ();
        size_t model_num = models.size ();
        Cell model_names (model_num, 1);
        for (int m = 0; m < model_num; m++)
        {
          model_names(m, 0) = models[m];
        }
        retval(0) = model_names;
        retval(1) = false;
      }
      else
      {
        json json_models = ollama::running_model_json ();
        string models = json_models.dump ();
        retval(0) = models;
        retval(1) = false;
      }
    }
    catch (ollama::exception& err)
    {
      string errmsg = err.what ();
      retval(0) = errmsg;
      retval(1) = true;
    }
    return retval;
  }

  // Start inference
  if (model.empty ())
  {
    error ("__ollama: 'model' is required.");
  }
  if (prompt.empty () && messages.size () == 0)
  {
    error ("__ollama: either 'prompt' or 'message' paired argument is required.");
  }
  else if (! prompt.empty () && messages.size () != 0)
  {
    error ("__ollama: either 'prompt' or 'message' paired argument can be specified.");
  }
  else if (! prompt.empty ())   // default to generate
  {
    try
    {
      ollama::response response;
      if (has_options || has_images)
      {
        response = ollama::generate (model, prompt, options, images);
      }
      else
      {
        response = ollama::generate (model, prompt);
      }
      string txt = response.as_json_string ();
      retval(0) = txt;
      retval(1) = false;
    }
    catch (ollama::exception& err)
    {
      string errmsg = err.what ();
      retval(0) = errmsg;
      retval(1) = true;
    }
  }
  else  // messages must be specified: default to chat
  {
    try
    {
      ollama::response response;
      if (has_options)
      {
       response = ollama::chat (model, messages, options);
      }
      else
      {
        response = ollama::chat (model, messages);
      }
      string txt = response.as_json_string ();
      retval(0) = txt;
      retval(1) = false;
    }
    catch (ollama::exception& err)
    {
      string errmsg = err.what ();
      retval(0) = errmsg;
      retval(1) = true;
    }
  }
  return retval;
}
