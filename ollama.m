## Copyright (C) 2025 Andreas Bertsatos <abertsatos@biol.uoa.gr>
##
## This program is free software; you can redistribute it and/or modify it under
## the terms of the GNU General Public License as published by the Free Software
## Foundation; either version 3 of the License, or (at your option) any later
## version.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
## FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License along with
## this program; if not, see <http://www.gnu.org/licenses/>.

classdef ollama < handle

  properties (Dependent = true)
    runningModels
  endproperties

  properties (GetAccess = public, Protected = true)
    serverURL = '';
    availableModels = {''};
    queryStats = struct ();
    chatHistory = {};
  endproperties

  properties (GetAccess = public)
    activeModel = '';
    readTimeout = 300;
    writeTimeout = 300;
    options = struct ();
  endproperties

  methods (GetAccess = public)

    function this = ollama (serverURL = [])
      ## Parse input
      if (isempty (serverURL))
        serverURL = "http://localhost:11434";
      elseif (ischar (serverURL))
        serverURL = serverURL;
      else
        error ("ollama: invalid serverURL input.");
      endif
      [out, err] = __ollama__ ('listModels', 'cellstr', 'serverURL', serverURL);
      if (err)
        this = [];
        error ("ollama: server is inaccessible at %s.", serverURL);
      else
        this.availableModels = out;
        this.serverURL = serverURL;
      endif
    endfunction

    function [varargout] = listModels (this, mode = 'cellstr')
      [list, err] = do_list_models (this, mode, 'listModels');
      if (err)
        error (err);
      endif
      if (nargout > 0)
        varargout{1} = list;
      elseif (any (strcmp (mode, {'cellstr', 'table'})))
        disp ("The following models are available in this ollama server:");
        disp (list);
      else
        error ("ollama.listModels: output argument is required for 'json'.");
      endif
    endfunction

    function [varargout] = listRunningModels (this, mode = 'cellstr')
      [list, err] = do_list_models (this, mode, 'listRunningModels');
      if (err)
        error (err);
      endif
      if (nargout > 0)
        varargout{1} = list;
      elseif (any (strcmp (mode, {'cellstr', 'table'})))
        disp ("The following models are available in this ollama server:");
        disp (list);
      else
        error ("ollama.listRunningModels: output argument is required for 'json'.");
      endif
    endfunction

    function copyModel (this, model, newmodel)
      if (isnumeric (model))
        if (model <= numel (this.availableModels))
          model = this.availableModels{model};
        else
          error (strcat ("ollama.copyModel: index to 'availableModels'", ...
                         " property is out of range."));
        endif
      elseif (! ischar (model) || isempty (model))
        error (strcat ("ollama.copyModel: MODEL must be a character", ...
                       " vector or an index to 'availableModels'."));
      endif
      if (! ischar (newmodel) || isempty (newmodel))
        error ("ollama.copyModel: NEWMODEL must be a character vector.");
      endif
      [out, err] = __ollama__ ('copyModel', {model, newmodel}, ...
                               'serverURL', this.serverURL);
      if (err)
        error ("ollama.loadModel: MODEL could not be copied.");
      else
        [this.availableModels, err] = __ollama__ ('listModels', 'cellstr', ...
                                                  'serverURL', this.serverURL);
      endif
    endfunction

    function deleteModel (this, model)
      if (isnumeric (model))
        if (model <= numel (this.availableModels))
          model = this.availableModels{model};
        else
          error (strcat ("ollama.deleteModel: index to 'availableModels'", ...
                         " property is out of range."));
        endif
      elseif (! ischar (model) || isempty (model))
        error (strcat ("ollama.deleteModel: MODEL must be a character", ...
                       " vector or an index to 'availableModels'."));
      endif
      [out, err] = __ollama__ ('deleteModel', model, 'serverURL', this.serverURL);
      if (err)
        error ("ollama.loadModel: MODEL could not be deleted.");
      else
        [this.availableModels, err] = __ollama__ ('listModels', 'cellstr', ...
                                                  'serverURL', this.serverURL);
      endif
    endfunction

    function loadModel (this, model)
      if (isnumeric (model))
        if (model <= numel (this.availableModels))
          model = this.availableModels{model};
        else
          error (strcat ("ollama.loadModel: index to 'availableModels'", ...
                         " property is out of range."));
        endif
      elseif (! ischar (model) || isempty (model))
        error (strcat ("ollama.loadModel: MODEL must be a character", ...
                       " vector or an index to 'availableModels'."));
      endif
      [out, err] = __ollama__ ('loadModel', model, 'serverURL', this.serverURL);
      if (err)
        error ("ollama.loadModel: MODEL could not be loaded.");
      else
        this.activeModel = model;
      endif
    endfunction

    function unloadModel (this, model)
      if (isnumeric (model))
        if (model <= numel (this.availableModels))
          model = this.availableModels{model};
        else
          error (strcat ("ollama.unloadModel: index to 'availableModels'", ...
                         " property is out of range."));
        endif
      elseif (! ischar (model) || isempty (model))
        error (strcat ("ollama.unloadModel: MODEL must be a character", ...
                       " vector or an index to 'availableModels'."));
      endif
      [out, err] = __ollama__ ('unloadModel', model, 'serverURL', this.serverURL);
      if (err)
        error ("ollama.unloadModel: MODEL not found.");
      else
        this.activeModel = model;
      endif
    endfunction

    function pullModel (this, model)
      if (! ischar (model))
        error ("ollama.pullModel: MODEL must be a character vector.");
      endif
      [out, err] = __ollama__ ('pullModel', model, 'serverURL', this.serverURL);
      if (err)
        msg = strcat ("If you get a time out error, try to increase the", ...
                      " 'readTimeout' and 'writeTimeout' parameters\n", ...
                      "   to allow more time for ollama server to download", ...
                      " the requested model.");
        error ("ollama.pullModel: %s\n   %s", out, msg);
      else
        [this.availableModels, err] = __ollama__ ('listModels', 'cellstr', ...
                                                  'serverURL', this.serverURL);
      endif
    endfunction

    function setOptions (this, varargin)
      if (mod (numel (varargin), 2) != 0)
        error ("ollama.setOptions: 'options' must be in Name-Value pairs.");
      endif
      while (! isempty (varargin))
        name = varargin{1};
        value = varargin{2};
        if (! ischar (name))
          error ("ollama.setOptions: NAME must be a character vector.");
        endif
        if (! (isscalar (value) && (isnumeric (value) || islogical (value))))
          error ("ollama.setOptions: VALUE must be a numeric or logical scalar.");
        endif
        switch (name)
          case 'num_keep'
            if (fix (value) == value && value >= 0)
              this.options.num_keep = value;
            else
              error ("ollama.setOptions: 'num_keep' must be a non-negative integer.");
            endif
          case 'seed'
            if (fix (value) == value && value >= 0)
              this.options.seed = value;
            else
              error ("ollama.setOptions: 'seed' must be a non-negative integer.");
            endif
          case 'num_predict'
            if (fix (value) == value && value >= 0)
              this.options.num_predict = value;
            else
              error ("ollama.setOptions: 'num_predict' must be a non-negative integer.");
            endif
          case 'top_k'
            if (fix (value) == value && value >= 0)
              this.options.top_k = value;
            else
              error ("ollama.setOptions: 'top_k' must be a non-negative integer.");
            endif
          case 'top_p'
            if (value >= 0 && value <= 1)
              this.options.top_p = value;
            else
              error ("ollama.setOptions: 'top_p' must be between 0 and 1.");
            endif
          case 'min_p'
            if (value >= 0 && value <= 1)
              this.options.min_p = value;
            else
              error ("ollama.setOptions: 'min_p' must be between 0 and 1.");
            endif
          case 'typical_p'
            if (value >= 0 && value <= 1)
              this.options.typical_p = value;
            else
              error ("ollama.setOptions: 'typical_p' must be between 0 and 1.");
            endif
          case 'repeat_last_n'
            if (fix (value) == value && value >= 0)
              this.options.repeat_last_n = value;
            else
              error ("ollama.setOptions: 'repeat_last_n' must be a non-negative integer.");
            endif
          case 'temperature'
            if (value >= 0 && value <= 2)
              this.options.temperature = value;
            else
              error ("ollama.setOptions: 'temperature' must be between 0 and 1.");
            endif
          case 'repeat_penalty'
            if (value >= 0)
              this.options.repeat_penalty = value;
            else
              error ("ollama.setOptions: 'repeat_penalty' must be positive.");
            endif
          case 'frequency_penalty'
            if (value >= 0)
              this.options.frequency_penalty = value;
            else
              error ("ollama.setOptions: 'frequency_penalty' must be positive.");
            endif
          case 'penalize_newline'
            if (islogical (value))
              this.options.penalize_newline = value;
            else
              error ("ollama.setOptions: 'penalize_newline' must be logical.");
            endif
          case 'numa'
            if (islogical (value))
              this.options.numa = value;
            else
              error ("ollama.setOptions: 'numa' must be logical.");
            endif
          case 'num_ctx'
            if (fix (value) == value && value >= 0)
              this.options.num_ctx = value;
            else
              error ("ollama.setOptions: 'num_ctx' must be a non-negative integer.");
            endif
          case 'num_batch'
            if (fix (value) == value && value >= 0)
              this.options.num_batch = value;
            else
              error ("ollama.setOptions: 'num_batch' must be a non-negative integer.");
            endif
          case 'num_gpu'
            if (fix (value) == value && value >= 0)
              this.options.num_gpu = value;
            else
              error ("ollama.setOptions: 'num_gpu' must be a non-negative integer.");
            endif
          case 'main_gpu'
            if (fix (value) == value && value >= 0)
              this.options.main_gpu = value;
            else
              error ("ollama.setOptions: 'main_gpu' must be a non-negative integer.");
            endif
          case 'use_mmap'
            if (islogical (value))
              this.options.use_mmap = value;
            else
              error ("ollama.setOptions: 'use_mmap' must be logical.");
            endif
          case 'num_thread'
            if (fix (value) == value && value >= 0)
              this.options.num_thread = value;
            else
              error ("ollama.setOptions: 'num_thread' must be a non-negative integer.");
            endif
          otherwise
            error ("ollama.setOptions: invalid NAME for custom option.");
        endswitch
        ## Remove parsed arguments
        varargin(1:2) = [];
      endwhile
    endfunction

    function txt = query (this, varargin)
      ## Check active model exists
      if (isempty (this.activeModel))
        error ("ollama.query: no model has been loaded yet.");
      endif
      if (nargin < 2)
        error ("ollama.query: too few input arguments.");
      endif
      ## Validate user prompt
      if (nargin > 1)
        prompt = varargin{1};
        if (! (isvector (prompt) && ischar (prompt)))
          error ("ollama.query: PROMPT must be a character vector.");
        endif
        args = {'prompt', prompt};
      endif
      ## Validate any images
      if (nargin > 2)
        image = varargin{2};
        if (! ischar (image) && ! iscellstr (image) && ! isvector (image))
          error (strcat ("ollama.query: IMAGE must be either a character", ...
                         " vector or a cell array of character vectors."));
        endif
        ## Check for either imageFile or imageBase64 strings
        if (ischar (image))
          if (any ('.' == image))
            type = 'imageFile';
          else
            type = 'imageBase64';
          endif
        else  # cellstr
          fcn = @(x) any ('.' == x);
          TF = cellfun (fcn, image);
          if (all (TF))
            type = 'imageFile';
          elseif (! any (TF))
            type = 'imageBase64';
          else
            error (strcat ("ollama.query: IMAGE must either contain", ...
                           " file names or base64_encoded strings."));
          endif
        endif
        args = [args, {'imageFile', image}];
      endif
      ## Validate prompt
      ## Run inference
      [out, err] = __ollama__ ('model', this.activeModel, ...
                               'serverURL', this.serverURL, ...
                               'readTimeout', this.readTimeout, ...
                               'writeTimeout', this.writeTimeout, ...
                               'options', this.options, args{:});
      if (err)
        msg = strcat ("If you get a time out error, try to increase the", ...
                      " 'readTimeout' and 'writeTimeout' parameters\n", ...
                      "   to allow more time for ollama server to respond.");
        error ("ollama.query: %s\n   %s", out, msg);
      endif
      ## Decode json output
      this.queryStats = jsondecode (out);
      ## Return response text
      txt = this.queryStats.response;
    endfunction
  endmethods

  methods (Hidden)

    ## Class specific display methods
    function display (this)
      in_name = inputname (1);
      if (! isempty (in_name))
        fprintf ('%s =\n', in_name);
      endif
      disp (this);
    endfunction

    function disp (this)
      fprintf ("\n  ollama interface connected at: %s\n\n", this.serverURL);
      fprintf ("%+25s: '%s'\n", 'activeModel', this.activeModel);
      fprintf ("%+25s: %d (sec)\n", 'readTimeout', this.readTimeout);
      fprintf ("%+25s: %d (sec)\n\n", 'writeTimeout', this.writeTimeout);
      if (! isempty (this.availableModels))
        fprintf ("     There are %d available models on this server.\n", ...
                 numel (this.availableModels));
        fprintf ("     Use the 'listModels' method for more information.\n\n");
      else
        fprintf ("     No available models on this server!\n\n");
      endif
    endfunction

    ## Display stats from last query
    function showStats (this)
      QS = this.queryStats;
      if (isempty (fieldnames (QS)))
        disp ("No stats to show. Make a query first or start a chat.");
        return;
      endif
      fprintf ("\n  Query answered by '%s' at: %s\n\n", ...
               QS.model, QS.created_at);
      fprintf ("%+25s: %0.2f (sec)\n", 'Total duration', ...
               round (QS.total_duration / 1e+7) / 100);
      fprintf ("%+25s: %0.2f (sec)\n", 'Load duration', ...
               round (QS.load_duration / 1e+7) / 100);
      fprintf ("%+25s: %0.2f (sec)\n\n", 'Evaluation duration', ...
               round (QS.eval_duration / 1e+7) / 100);
      fprintf ("%+25s: %d (tokens)\n", 'Prompt count', ...
               QS.prompt_eval_count);
      fprintf ("%+25s: %d (tokens)\n\n", 'Evaluation count', QS.eval_count);
    endfunction

    ## Class specific subscripted reference
    function varargout = subsref (this, s)

      chain_s = s(2:end);
      s = s(1);
      switch (s.type)
        case '()' # Use this syntax for making a query
          if (isempty (s.subs))
            varargout{1} = this;
          else
            out = query (this, s.subs{:});
            if (nargout == 0)
              disp ("Response:\n");
              disp (out);
            else
              varargout{1} = out;
            endif
            return;
          endif

        case '{}'
          error ("ollama.subsref: '{}' invalid indexing for ollama object.");

        case '.'
          if (! ischar (s.subs))
            error ("ollama.subsref: '.' indexing requires a character vector.");
          endif
          switch (s.subs)
            case 'serverURL'
              out = this.serverURL;
            case 'runningModels'
              [out, err] = __ollama__ ('listRunningModels', 'cellstr', ...
                                       'serverURL', this.serverURL);
            case 'availableModels'
              out = this.availableModels;
            case 'queryStats'
              out = this.queryStats;
            case 'chatHistory'
              out = this.chatHistory;
            case 'activeModel'
              out = this.activeModel;
            case 'readTimeout'
              out = this.readTimeout;
            case 'writeTimeout'
              out = this.writeTimeout;
            case 'options'
              out = this.options;
            otherwise
              error ("ollama.subsref: unrecongized property: '%s'", s.subs);
          endswitch
      endswitch

      ## Chained references
      if (! isempty (chain_s))
        out = subsref (out, chain_s);
      endif
      varargout{1} = out;

    endfunction

    ## Class specific subscripted assignment
    function this = subsasgn (this, s, val)

      if (numel (s) > 1)
        error ("calendarDuration.subsasgn: chained subscripts not allowed.");
      endif
      switch s.type
        case '()'
          error ("ollama.subsasgn: '()' invalid indexing for ollama object.");

        case '{}'
          error ("ollama.subsasgn: '{}' invalid indexing for ollama object.");

        case '.'
          if (! ischar (s.subs))
            error ("ollama.subsref: '.' indexing requires a character vector.");
          endif
          switch (s.subs)
            case 'serverURL'
              error ("ollama.subsref: 'serverURL' is set a construction.");
            case 'runningModels'
              error ("ollama.subsref: 'runningModels' is read only.");
            case 'availableModels'
              error ("ollama.subsref: 'availableModels' is read only.");
            case 'queryStats'
              error ("ollama.subsref: 'queryStats' is read only.");
            case 'chatHistory'
              error ("ollama.subsref: 'chatHistory' is read only.");
            case 'activeModel'
              loadModel (this, val);
            case 'readTimeout'
              if (isscalar (val) && val > 0 && fix (val) == val)
                this.readTimeout = val;
              else
                error (strcat ("ollama.subsref: 'readTimeout' must be", ...
                               " a scalar with positive integer value."));
              endif
            case 'writeTimeout'
              if (isscalar (val) && val > 0 && fix (val) == val)
                this.writeTimeout = val;
              else
                error (strcat ("ollama.subsref: 'writeTimeout' must be", ...
                               " a scalar with positive integer value."));
              endif
            case 'options'
              if (iscell (val) && numel (val) == 2)
                this = setOptions (this, val{1}, val{2});
              else
                error (strcat ("ollama.subsref: 'options' must be", ...
                               " a 2-element cell array."));
              endif
            otherwise
              error ("ollama.subsasgn: unrecongized property: %s", s.subs);
          endswitch
      endswitch

    endfunction

  endmethods

  methods (Access = private)

    function [list, err] = do_list_models (this, mode, operation)
      if (! any (strcmp (mode, {'cellstr', 'json', 'table'})))
        err = sprintf ("ollama.%s: MODE can be either 'cellstr' or 'json'.", ...
                       operation);
      endif
      if (strcmp (mode, 'table'))
        fcn = @(x) strcmp (x.name, 'datatypes') && x.loaded;
        if (! any (cellfun (fcn, pkg ('list'))))
          err = sprintf ("ollama.%s: the 'datatypes' package is required.", ...
                         operation);
        endif
        mode = 'json';
        return_table = true;
      else
        return_table = false;
      endif
      [list, err] = __ollama__ (operation, mode, 'serverURL', this.serverURL);
      if (err)
        this = [];
        err = sprintf ("ollama.%s: server is inaccessible at %s.", ...
                       operation, serverURL);
      else
        if (strcmp (mode, 'cellstr'))
          if (strcmp (operation, 'listModels'))
            this.availableModels = list;
          else    # listRunningModels
            this.runningModels = list;
          endif
        else
          list = jsondecode (list);
          if (strcmp (operation, 'listModels'))
            if (isempty (list.models))
              this.availableModels = {''};
            else
              this.availableModels = {list.models.model}';
            endif
          else    # listRunningModels
            if (isempty (list.models))
              this.runningModels = {''};
            else
              this.runningModels = {list.models.model}';
            endif
          endif
        endif
        ## Create table if requested
        if (return_table)
          if (isempty (list.models))
            list = table ('Size', [0, 5], 'VariableTypes', {'cellstr', ...
                          'cellstr', 'cellstr', 'cellstr', 'double'}, ...
                          'VariableNames', {'family', 'format', 'parameter', ...
                          'quantization', 'size'});
            if (strcmp (operation, 'listModels'))
              this.availableModels = {''};
            else    # listRunningModels
              this.runningModels = {''};
            endif
          else
            T = struct2table (list.models);
            T = removevars (T, {'digest', 'name'});
            list = struct2table (T.details, 'AsArray', true);
            list = removevars (list, {'families', 'parent_model'});
            list = renamevars (list, 'quantization_level', 'quantization');
            list = renamevars (list, 'parameter_size', 'parameter');
            list = addvars (list, T.size, 'NewVariableNames', 'size');
            list.Properties.RowNames = T.model;
            if (strcmp (operation, 'listModels'))
              this.availableModels = T.model;
            else    # listRunningModels
              this.runningModels = T.model;
            endif
          endif
        endif
      endif
    endfunction
  endmethods

endclassdef
