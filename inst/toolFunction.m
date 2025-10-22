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

    function this = toolFunction (fname, description, handle = [])
      if (nargin < 2)
        print_usage;
      endif
      if (validateString (fname))
        error ("toolFunction: NAME must be non-empty character vector.");
      endif
      this.name = fname;
      if (validateString (description))
        error ("toolFunction: DESCRIPTION must be non-empty character vector.");
      endif
      this.description = description;
      if (! isempty (handle))
        if (! is_function_handle (handle))
          error ("toolFunction: HANDLE must be a function handle.");
        else
          this.handle = handle;
        endif
      endif
    endfunction

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

    function funStruct = encodeFunction (this)
      funStruct.type = "function";
      funStruct.function.name = this.name;
      funStruct.function.description = this.description;
      funStruct.function.parameters.type = "object";
      funStruct.function.parameters.properties = this.parameters;
      funStruct.function.required = fieldnames (this.parameters);
    endfunction

    function tool_output = evalFunction (this, tool_call)
      if (validateString (tool_call))
        error (strcat ("toolFunction.addParameters: TOOL_CALL", ...
                       " must be a nonempty character vector."));
      endif
      try
        tool_call = jsondecode (tool_call, 'makeValidName', false);
      catch
        error ("toolFunction.evalFunction: invalid JSON string.");
      end_try_catch
      ## Validate tool call is properly structured for this function
      if (! all (ismember (fieldnames (tool_call), {'type', 'function'})))
        error ("toolFunction.evalFunction: invalid TOOL_CALL json string.");
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

endclassdef

function err = validateString (in)
  if (! (ischar (in) && isvector (in)) || isempty (in))
    err = true;
  else
    err = false;
  endif
endfunction

function err = validateCellString (in)
  if (! iscellstr (in))
    err = true;
  elseif (any (cellfun ('isempty', in)))
    err = true;
  else
    err = false;
  endif
endfunction
