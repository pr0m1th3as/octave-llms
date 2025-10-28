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

classdef toolFunction
  ## -*- texinfo -*-
  ## @deftp {toolFunction} toolFunction
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
      if (nargin != 3)
        print_usage;
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
    ## @end deftypefn
    function this = addParameters (this, propName, propType, propDescription, enum = [])
      if (nargin < 4 || nargin > 5)
        print_usage;
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
      this.parameters.(propName).type = propType;
      this.parameters.(propName).description = propDescription;
      if (! isempty (enum))
        if (validateCellString (enum))
          error (strcat ("toolFunction.addParameters: ENUM must be a", ...
                         " cell array of nonempty character vectors."));
        endif
        this.parameters.(propName).enum = enum;
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
      if (! all (ismember (fieldnames (tool_call), {'type', 'function'})))
        error ("toolFunction.evalFunction: invalid TOOL_CALL structure.");
      endif
      if (! strcmp (tool_call.function.name, this.name))
        tool_output = '';
        return;
      endif
      ## Get input arguments and validate their names and types
      ModelArgs = fieldnames (tool_call.function.arguments);
      toolFArgs = fieldnames (this.parameters);
      if (! isequal (ModelArgs, toolFArgs))
        tool_output = '';
        return;
      endif
      fargs = cellfun (@(fnames) tool_call.function.arguments.(fnames), ...
                       ModelArgs, 'UniformOutput', false);
      result = char (string (this.handle (fargs{:})));
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
      funStruct.function.required = fieldnames (this.parameters);
    endfunction

    ## Class specific subscripted reference
    function varargout = subsref (this, s)
      chain_s = s(2:end);
      s = s(1);
      switch (s.type)
        case '()'
          error ("toolFunction.subsref: '()}' invalid indexing.");
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
          endswitch
      endswitch
    endfunction
  endmethods

endclassdef

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
