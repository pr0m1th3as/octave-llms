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

classdef ollama

  properties (GetAccess = public, Protected = true)
    serverURL = '';
    availableModels = {''};
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

    function this = loadModel (this, model)
      if (isnumeric (model))
        if (model <= numel (this.availableModels))
          model = this.availableModels{model};
        endif
      elseif (! ischar (model))
        error (strcat ("ollama.loadModel: MODEL must be a character vector or", ...
                       " a number indexing the 'availableModels' properties."));
      endif
      [out, err] = __ollama__ ('loadModel', model, 'serverURL', this.serverURL);
      if (err)
        error ("ollama.loadModel: %s", out);
      else
        this.activeModel = model;
      endif
    endfunction

    function this = pullModel (this, model)
      if (! ischar (model))
        error ("ollama.loadModel: MODEL must be a character vector.");
      endif
      [out, err] = __ollama__ ('pullModel', model, 'serverURL', this.serverURL);
      if (err)
        msg = strcat ("If you get a time out error, try to increase the", ...
                      " 'readTimeout' and 'writeTimeout' parameters\n", ...
                      "   to allow more time for ollama server to download", ...
                      " the requested model.");
        error ("ollama.loadModel: %s\n   %s", out, msg);
      else
        this.availableModels = [this.availableModels model];
      endif
    endfunction

    function this = setOptions (this, varargin)
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

    function txt = generate (this, varargin)
      if (nargin < 2)
        error ("ollama.generate: too few input arguments.");
      elseif (nargin == 2)
        if (isempty (this.activeModel))
          error ("ollama.generate: no model has been loaded yet.");
        endif
        model = this.activeModel;
        prompt = varargin{1};
      else
        model = varargin{1};
        prompt = varargin{2};
        ## Validate model
        if (isnumeric (model) && fix (model) == model)
          if (model <= numel (this.availableModels) && model > 0)
            model = this.availableModels{model};
          else
            error ("ollama.generate: MODEL index out of range.");
          endif
        elseif (! (ischar (model) && isvector (model) &&
                   any (strcmp (model, this.availableModels))))
          error (strcat ("ollama.generate: MODEL must be a character vector", ...
                         " or a number indexing the 'models' properties."));
        endif
      endif
      ## Validate prompt
      if (! (isvector (prompt) && ischar (prompt)))
        error ("ollama.generate: PROMPT must be a character vector.");
      endif
      ## Run inference
      [out, err] = __ollama__ ('model', model, 'prompt', prompt, ...
                               'serverURL', this.serverURL, ...
                               'readTimeout', this.readTimeout, ...
                               'writeTimeout', this.writeTimeout, ...
                               'options', this.options);
      if (err)
        msg = strcat ("If you get a time out error, try to increase the", ...
                      " 'readTimeout' and 'writeTimeout' parameters\n", ...
                      "   to allow more time for ollama server to respond.");
        error ("ollama.generate: %s\n   %s", out, msg);
      else
        ## Save active model
        this.activeModel = model;
        ## Decode json output
        jsn = jsondecode (out);
        ## Return response text
        txt = jsn.response;
      endif
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
          fprintf ("     There are %d available models on this server.\n\n", ...
                   numel (this.availableModels));
        else
          fprintf ("     No available models on this server!\n\n");
        endif
    endfunction

    ## Class specific subscripted reference
    function varargout = subsref (this, s)

      chain_s = s(2:end);
      s = s(1);
      switch (s.type)
        case '()'
          error ("ollama.subsref: '()' invalid indexing for ollama object.");

        case '{}'
          error ("ollama.subsref: '{}' invalid indexing for ollama object.");

        case '.'
          if (! ischar (s.subs))
            error ("ollama.subsref: '.' indexing requires a character vector.");
          endif
          switch (s.subs)
            case 'serverURL'
              out = this.serverURL;
            case 'availableModels'
              out = this.availableModels;
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
            case 'availableModels'
              error ("ollama.subsref: 'availableModels' are read only.");
            case 'activeModel'
              this = loadModel (this, val);
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

endclassdef
