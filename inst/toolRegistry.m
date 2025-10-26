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

classdef toolRegistry
  ## -*- texinfo -*-
  ## @deftp {llms} toolRegistry
  ##
  ## A toolRegistry object for tool-calling capable models.
  ##
  ## @qcode{toolRegistry} is a scalar class object, which acts as a custom
  ## dictionary for @qcode{toolFunction} objects.  It is useful for defining
  ## a list of uniquely identifiable functions that can be made available to
  ## a tool-capable LLM during a chat session.
  ##
  ## @end deftp

  properties (Access = private)
    ## -*- texinfo -*-
    ## @deftp {toolRegistry} {property} names
    ##
    ## Unique tool name identifiers.
    ##
    ## The uniquely identifiable names of the @qcode{toolFunction} objects that
    ## are available in the tool registry.
    ##
    ## @end deftp
    names = {};
  endproperties

  properties (Access = private, Hidden)
    ## -*- texinfo -*-
    ## @deftp {toolRegistry} {property} tools
    ##
    ## A cell array of @qcode{toolFunction} objects.
    ##
    ## @end deftp
    tools = {};
  endproperties

  methods (GetAccess = public)

    ## -*- texinfo -*-
    ## @deftypefn  {toolRegistry} {@var{reg} =} toolRegistry (@var{tool})
    ## @deftypefnx {toolRegistry} {@var{reg} =} toolRegistry (@var{tool1}, @dots{}, @var{toolN})
    ##
    ## Create a tool registry for LLMs.
    ##
    ## @code{@var{reg} = toolRegistry (@var{tool1}, @dots{}, @var{toolN})}
    ## creates a tool registry, @var{reg}, which comprises a list of
    ## @qcode{toolFunction} objects specified by the input arguments
    ## @qcode{(@var{tool1}, @dots{}, @var{toolN})}, which must be uniquely
    ## identifiable by their function names.
    ##
    ## @end deftypefn
    function this = toolRegistry (varargin)
      if (nargin == 0)
        return;
      endif
      if (any (cellfun (@(x) ! isa (x, 'toolFunction'), varargin)))
        error ("toolRegistry: all inputs must be 'toolFunction' objects.");
      endif
      this.names = cellfun (@(x) x.name, varargin, 'UniformOutput', false);
      if (numel (this.names) != numel (unique (this.names)))
        error (strcat ("toolRegistry: input 'toolFunction'", ...
                       " objects must have unique names."));
      endif
      this.tools = varargin;
    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {toolFunction} {@var{tool_output} =} evalFunction (@var{reg}, @var{tool_call})
    ##
    ## Evaluate the requested tool functions in the tool registry.
    ##
    ## @code{@var{tool_output} = evalFunction (@var{reg}, @var{tool_call})}
    ## evaluates the function handle of each @qcode{toolFunction} object
    ## specified by @var{tool} available in the tool registry @var{reg}
    ## according to the corresponding input arguments described by the LLM's
    ## tool calling response specified in @var{tool_call}, which can be a
    ## character vector containing the appropriate JSON string message or its
    ## equivalent to a scalar structure.  The returned @var{tool_output} is an
    ## @math{Nx2} cell array of character vectors, in which the first column
    ## contains the output of each evaluated @qcode{toolFunction} object and the
    ## second column contains the corresponding function names.
    ##
    ## @end deftypefn
    function tool_output = evalFunction (this, tool_call)
      if (! isstruct (tool_call))
        if (validateString (tool_call))
          error (strcat ("toolRegistry.evalFunction: unless a struct", ...
                         " TOOL_CALL must be a nonempty character vector."));
        endif
        try
          tool_call = jsondecode (tool_call, 'makeValidName', false);
        catch
          error ("toolRegistry.evalFunction: invalid JSON string.");
        end_try_catch
      endif
      ## Validate tool call is properly structured for functions
      if (! all (ismember (fieldnames (tool_call), {'type', 'function'})))
        error ("toolRegistry.evalFunction: invalid TOOL_CALL structure.");
      endif
      tool_output = {};
      for i = 1:numel (tool_call)
        name = tool_call(i).function.name;
        tidx = strcmp (name, this.names);
        if (any (tidx))
          output = evalFunction (this.tools{tidx}, tool_call(i));
          tool_output = [tool_output; output];
        else
          error ("toolRegistry.evalFunction: unavailable toolFunction: '%s'", name);
        endif
      endfor
    endfunction

  endmethods

  methods (Hidden)

    ## Encode toolRegistry into a structure array
    function regStruct = encodeRegistry (this)
      for i = 1:numel (this.names)
        regStruct(i) = encodeFunction (this.tools{i});
      endfor
    endfunction

    ## Class specific subscripted reference
    function varargout = subsref (this, s)
      chain_s = s(2:end);
      s = s(1);
      switch (s.type)
        case '()'
          out = this;
          out.names = this.names(s.subs{:});
          out.tools = this.tools(s.subs{:});

        case '{}'
          if (isscalar (s.subs))
            out  = this.tools{s.subs{:}};
          else
            out = this.tools(s.subs{:});
          endif

        case '.'
          switch (s.subs)
            case 'names'
              out = this.names;
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
