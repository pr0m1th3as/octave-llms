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
                               'writeTimeout', this.writeTimeout);
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
            otherwise
              error ("ollama.subsasgn: unrecongized property: %s", s.subs);
          endswitch
      endswitch

    endfunction

  endmethods

endclassdef
