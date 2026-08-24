## Copyright (C) 2025-2026 Andreas Bertsatos <abertsatos@biol.uoa.gr>
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

classdef toolFunction
  ## -*- texinfo -*-
  ## @deftp {llms} toolFunction
  ##
  ## A toolFunction object for tool-calling capable models.
  ##
  ## @qcode{toolFunction} is a scalar class object, which contains the full
  ## description of a tool function along with the handle to its corresponding
  ## Octave function, which should be executed after a tool call request from
  ## the model.
  ##
  ## @end deftp

  properties (Access = private)
    ## -*- texinfo -*-
    ## @deftp {toolFunction} {property} name
    ##
    ## The name of the function.
    ##
    ## The name of the function to be identified by the model's tool call.
    ##
    ## @end deftp
    name = '';

    ## -*- texinfo -*-
    ## @deftp {toolFunction} {property} description
    ##
    ## The description of the function.
    ##
    ## The description of the function to be evaluated by the model to decide
    ## whether it should call it.
    ##
    ## @end deftp
    description = '';

    ## -*- texinfo -*-
    ## @deftp {toolFunction} {property} parameters
    ##
    ## The parameters of the function.
    ##
    ## The parameters of the function that are expected by the model's tool call
    ## response and are required to evaluate the undelying function handle.
    ##
    ## @end deftp
    parameters = struct ();

    ## -*- texinfo -*-
    ## @deftp {toolFunction} {property} handle
    ##
    ## The function handle to be evaluated.
    ##
    ## The function handle of the Octave function that will be evaluated once
    ## it is appropriately requested by the model's tool call response.
    ##
    ## @end deftp
    handle = [];

    ## Names carrying a default value.  A parameter with a default is optional:
    ## it is left out of the schema's required list, and a call that omits it is
    ## completed from here rather than dispatched with a gap in its arguments.
    defaults = struct ();

  endproperties

  methods (GetAccess = public)

    ## -*- texinfo -*-
    ## @deftypefn {toolFunction} {@var{tool} =} toolFunction (@var{name}, @var{description}, @var{handle})
    ##
    ## Create a tool function for LLMs.
    ##
    ## @code{@var{tool} = toolFunction (@var{name}, @var{description},
    ## @var{handle})} creates a @qcode{toolFunction} object, which comprises an
    ## identifier specified by @var{name}, a functionality description that can
    ## be understood by the LLM model specified in @var{description} and a
    ## function handle, specified in @var{handle}, which corresponds to an
    ## actual Octave function that will be evaluated along with any input
    ## parameters specified by the LLM's tool calling response.
    ##
    ## By default, @code{toolFunction} does not add any input parameters to the
    ## created object.  Use the @code{addParameters} method to append any input
    ## input parameters that your function handle may require for its successful
    ## evaluation.  Use the @code{evalFunction} to evaluate the underlying
    ## function handle according to the input arguments specified by the LLM.
    ##
    ## @end deftypefn
    function this = toolFunction (fname, description, handle)
      if (nargin < 3)
        error (strcat ("toolFunction: FNAME, DESCRIPTION, and FHANDLE", ...
                       " are required."));
      endif
      if (validateString (fname))
        error ("toolFunction: FNAME must be non-empty character vector.");
      endif
      this.name = fname;
      if (validateString (description))
        error ("toolFunction: DESCRIPTION must be non-empty character vector.");
      endif
      this.description = description;
      if (! is_function_handle (handle))
        error ("toolFunction: FHANDLE must be a function handle.");
      else
        this.handle = handle;
      endif
    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {toolFunction} {@var{tool} =} addParameters (@var{tool}, @var{propName}, @var{propType}, @var{propDescription})
    ## @deftypefnx {toolFunction} {@var{tool} =} addParameters (@var{tool}, @var{propName}, @var{propType}, @var{propDescription}, @var{enum})
    ## @deftypefnx {toolFunction} {@var{tool} =} addParameters (@dots{}, @var{Name}, @var{Value})
    ##
    ## Add an input parameter to the tool function.
    ##
    ## @code{addParameters} appends the parameters of a single input argument
    ## into the @qcode{toolFunction} object so that the LLM can understand the
    ## context of the corresponding input argument of the underlying function
    ## handle when asking for its evaluation.
    ##
    ## @code{addParameters} requires at least four input arguments (and may
    ## accept an optional fifth argument), which are as described below:
    ##
    ## @enumerate
    ## @item @var{tool} (required) A @qcode{toolFunction} object that the
    ## parameters will be appended to.
    ## @item @var{propName} (required) A character vector specifying the name of
    ## the input argument in the undelying function handle to be evaluated.
    ## @item @var{propType} (required) A character vector specifying the data
    ## type of the value corresponding to the input argument specified above.
    ## @item @var{propDescription} (required) A character vector describing the
    ## input argument so that the LLM can understand what value to assign for
    ## evaluation.
    ## @item @var{enum} (optional) A cell array of character vectors specifying
    ## a list of acceptable values that the LLM may chooce from to supply as an
    ## input argument.  Alternatively, @var{enum} can be a cell array of numeric
    ## or logical values.
    ## @end enumerate
    ##
    ## Anything beyond the fourth argument may also be given as @var{Name},
    ## @var{Value} pairs, which is the preferred form: the reader of a tool
    ## declaration is a language model, and a model handles named arguments
    ## reliably where it handles positional ones by luck.  The same holds for
    ## whoever writes the declaration.
    ##
    ## @multitable @columnfractions 0.18 0.02 0.80
    ## @headitem @var{Name} @tab @tab @var{Value}
    ##
    ## @item @qcode{"enum"} @tab @tab As @var{enum} above.
    ##
    ## @item @qcode{"default"} @tab @tab The value the parameter takes when the
    ## model's tool call leaves it out.  A parameter with a default is
    ## @strong{optional}: it is omitted from the @qcode{required} list of the
    ## encoded schema, it is advertised to the model so that leaving it out is
    ## an informed choice, and a call that omits it is completed from the
    ## default rather than dispatched with a gap in its arguments.  When
    ## @qcode{"enum"} is also given, the default must be one of its values.
    ## @end multitable
    ##
    ## Defaults are how optionality is expressed here, in preference to letting
    ## a call arrive with an argument missing.  The function handle is called
    ## positionally, so an absent argument in the middle of the list would
    ## silently shift every later one into the wrong place; filling it from a
    ## declared default means the handle is always called with a complete list.
    ##
    ## @end deftypefn
    function this = addParameters (this, propName, propType, propDescription, varargin)
      if (nargin < 4)
        error (strcat ("toolFunction.addParameters: PROPNAME, PROPTYPE,", ...
                       " and PROPDESCRIPTION are required."));
      endif
      if (validateString (propName))
        error (strcat ("toolFunction.addParameters: PROPNAME must", ...
                       " be a nonempty character vector."));
      endif
      if (validateString (propType))
        error (strcat ("toolFunction.addParameters: PROPTYPE must", ...
                       " be a nonempty character vector."));
      endif
      if (validateString (propDescription))
        error (strcat ("toolFunction.addParameters: PROPDESCRIPTION", ...
                       " must be a nonempty character vector."));
      endif
      ## A lone cell is the original positional ENUM; anything else opens the
      ## name/value list.  A model reads named arguments reliably and positional
      ## ones by luck, and the same is true of whoever writes the declaration.
      enum = [];
      dflt = [];
      hasDefault = false;
      if (numel (varargin) == 1)
        ## A lone fifth argument can only be the original positional ENUM: a
        ## name/value list needs a pair.  Validated below, so the error it
        ## raises is the one this call has always raised.
        enum = varargin{1};
      elseif (! isempty (varargin))
        if (mod (numel (varargin), 2) != 0)
          error (strcat ("toolFunction.addParameters: optional arguments", ...
                         " must be given as NAME, VALUE pairs."));
        endif
        for i = 1:2:numel (varargin)
          key = varargin{i};
          if (! (ischar (key) && isvector (key)))
            error (strcat ("toolFunction.addParameters: optional argument", ...
                           " names must be character vectors."));
          endif
          switch (lower (key))
            case 'enum'
              enum = varargin{i+1};
            case 'default'
              dflt = varargin{i+1};
              hasDefault = true;
            otherwise
              error (strcat ("toolFunction.addParameters: unrecognized", ...
                             " optional argument '%s'."), key);
          endswitch
        endfor
      endif

      this.parameters.(propName).type = propType;
      this.parameters.(propName).description = propDescription;
      if (! isempty (enum))
        if (validateCellString (enum))
          error (strcat ("toolFunction.addParameters: ENUM must be a", ...
                         " cell array of nonempty character vectors."));
        endif
        this.parameters.(propName).enum = enum;
      endif
      if (hasDefault)
        if (! isempty (enum) && ! any (cellfun (@(e) isequal (e, dflt), enum)))
          error (strcat ("toolFunction.addParameters: DEFAULT must be one", ...
                         " of the values listed in ENUM."));
        endif
        ## Also declared in the schema, where it tells the model what it gets
        ## if it says nothing, which is what makes omitting it a decision
        this.parameters.(propName).default = dflt;
        this.defaults.(propName) = dflt;
      endif
    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {toolFunction} {@var{tool_output} =} evalFunction (@var{tool}, @var{tool_call})
    ##
    ## Evaluate the tool function.
    ##
    ## @code{@var{tool_output} = evalFunction (@var{tool}, @var{tool_call})}
    ## evaluates the function handle of the @qcode{toolFunction} object
    ## specified by @var{tool} according to the input arguments described by the
    ## LLM's tool calling response specified in @var{tool_call}, which can be a
    ## character vector containing the appropriate JSON string message or its
    ## equivalent to a scalar structure.  The returned @var{tool_output} is a
    ## @math{1x2} cell array of character vectors, in which the first element
    ## contains the output of the evaluated @qcode{toolFunction} object and the
    ## second element contains its corresponding function name.
    ##
    ## If @var{tool_call} names this tool but supplies arguments that do not
    ## match its parameters, the first element carries a diagnostic naming the
    ## expected and the supplied arguments instead of the function's output.
    ## The function handle is not evaluated.  This is deliberate: the model must
    ## be told what was wrong with its call, because a result it never receives
    ## is one it cannot correct, and it will otherwise repeat the call or invent
    ## an answer.  The order of the supplied arguments is not significant, the
    ## members of a JSON object being unordered.
    ##
    ## If @var{tool_call} names a different tool, an empty character vector is
    ## returned so that a caller can dispatch over several tools.
    ##
    ## @end deftypefn
    function tool_output = evalFunction (this, tool_call)
      if (! isstruct (tool_call))
        if (validateString (tool_call))
          error (strcat ("toolFunction.evalFunction: unless a struct", ...
                         " TOOL_CALL must be a nonempty character vector."));
        endif
        try
          tool_call = jsondecode (tool_call, 'makeValidName', false);
        catch
          error ("toolFunction.evalFunction: invalid JSON string.");
        end_try_catch
      endif
      ## Validate tool call is properly structured for this function
      if (! isfield (tool_call, 'function'))
        error ("toolFunction.evalFunction: invalid TOOL_CALL structure.");
      endif
      if (! strcmp (tool_call.function.name, this.name))
        tool_output = '';
        return;
      endif
      ## Get input arguments and validate their names and types
      ModelArgs = fieldnames (tool_call.function.arguments);
      toolFArgs = fieldnames (this.parameters);
      ## The members of a JSON object are unordered, so a model may supply the
      ## same arguments in any order and often does.  Compare them as sets,
      ## then read the values back in the order the parameters were declared,
      ## which is the order the function handle takes them in.  Comparing the
      ## two lists directly made a correct call fail whenever the model happened
      ## to emit the arguments in a different order, and fail silently.
      reqArgs = toolFArgs(! ismember (toolFArgs, fieldnames (this.defaults)));
      unknown = setdiff (ModelArgs, toolFArgs);
      missing = setdiff (reqArgs, ModelArgs);
      if (! isempty (unknown) || ! isempty (missing))
        ## A mismatch used to return nothing at all, so the tool result never
        ## reached the model: it had asked for a call, nothing ran, and the
        ## conversation carried on as though it had not happened, leaving it to
        ## guess or repeat itself.  The error goes back as the tool result
        ## instead, which is the only form a model can act on.
        if (! isempty (unknown))
          msg = sprintf (strcat ("Error: tool '%s' does not take %s. Its", ...
                                 " parameters are %s. Call it again using", ...
                                 " only those."), this.name, ...
                         argList (unknown), ...
                         paramList (toolFArgs, fieldnames (this.defaults)));
        else
          msg = sprintf (strcat ("Error: tool '%s' is missing %s. Its", ...
                                 " parameters are %s. Call it again", ...
                                 " supplying them."), this.name, ...
                         argList (missing), ...
                         paramList (toolFArgs, fieldnames (this.defaults)));
        endif
        tool_output = {msg, this.name};
        return;
      endif
      ## Every omitted argument is filled from its default, so the handle is
      ## always called with a complete positional list and never with a gap
      fargs = cell (numel (toolFArgs), 1);
      for i = 1:numel (toolFArgs)
        if (isfield (tool_call.function.arguments, toolFArgs{i}))
          fargs{i} = tool_call.function.arguments.(toolFArgs{i});
        else
          fargs{i} = this.defaults.(toolFArgs{i});
        endif
      endfor
      result = this.handle (fargs{:});
      if (! ischar (result))
        ## 'mat2str' keeps a non-scalar result on one row, which 'char' of a
        ## string array does not, and it renders a logical as true/false.
        result = mat2str (result);
      endif
      tool_output = {result, this.name};
    endfunction

  endmethods

  methods (Hidden)

    ## Encode toolFunction into a scalar structure
    function funStruct = encodeFunction (this)
      funStruct.type = "function";
      funStruct.function.name = this.name;
      funStruct.function.description = this.description;
      funStruct.function.parameters.type = "object";
      funStruct.function.parameters.properties = this.parameters;
      names = fieldnames (this.parameters);
      funStruct.function.parameters.required = ...
                              names(! ismember (names, fieldnames (this.defaults)));
    endfunction

    ## Class specific subscripted reference
    function varargout = subsref (this, s)
      chain_s = s(2:end);
      s = s(1);
      switch (s.type)
        case '()'
          error ("toolFunction.subsref: '()' invalid indexing.");
        case '{}'
          error ("toolFunction.subsref: '{}' invalid indexing.");
        case '.'
          switch (s.subs)
            case 'name'
              out = this.name;
            case 'description'
              out = this.description;
            case 'handle'
              out = this.handle;
            otherwise
              error ("toolFunction.subsref: unrecognized property: '%s'", ...
                     s.subs);
          endswitch
      endswitch

      ## Chained references
      if (! isempty (chain_s))
        out = subsref (out, chain_s);
      endif
      varargout{1} = out;
    endfunction
  endmethods

endclassdef

## Name the parameters for a diagnostic, marking the ones that may be omitted.
## The lists are passed in rather than the object: this is a local function, so
## reaching a private property through it would go via the class's own subsref,
## which exposes only the public ones.
function str = paramList (names, dflt)
  for i = 1:numel (names)
    if (ismember (names{i}, dflt))
      names{i} = [names{i} " (optional)"];
    endif
  endfor
  str = argList (names);
endfunction

## Name a set of arguments for a diagnostic the model has to act on
function str = argList (names)
  if (isempty (names))
    str = 'no arguments';
  else
    str = strjoin (names(:)', ', ');
  endif
endfunction

function err = validateString (in)
  if (! (ischar (in) && isvector (in)) || isempty (in))
    err = true;
  else
    err = false;
  endif
endfunction

function err = validateCellString (in)
  fcn = @(x) ! (isnumeric (x) || islogical (x) || ischar (x));
  if (! (iscell (in)))
    err = true;
  elseif (any (cellfun ('isempty', in)))
    err = true;
  elseif (any (cellfun (fcn, in)))
    err = true;
  else
    err = false;
  endif
endfunction
