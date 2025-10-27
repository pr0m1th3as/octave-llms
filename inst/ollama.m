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
  ## -*- texinfo -*-
  ## @deftp {llms} ollama
  ##
  ## An ollama object interface with a running ollama server.
  ##
  ## @qcode{ollama} is a scalar handle class object, which allows communication
  ## with an ollama server running either locally or across a network.  The
  ## heavy lifting, interfacing with the ollama API, is done by the compiled
  ## @code{__ollama__} function, which should not be called directly.
  ##
  ## An ollama interface object should be considered as a session to the ollama
  ## server by holding any user defined settings along with the chat history (if
  ## opted) and other custom parameters to be parsed to the LLM model during
  ## inference.  You can initialize several ollama interface objects pointing to
  ## the same ollama server and use them concurently to implement more complex
  ## schemes such as RAG, custom tooling, etc.
  ##
  ## @seealso{calendarDuration, datetime}
  ## @end deftp

  properties (Dependent = true)
    ## -*- texinfo -*-
    ## @deftp {ollama} {property} runningModels
    ##
    ## Display running models.
    ##
    ## Displays the models that are currently loaded in ollama server's memory.
    ##
    ## @end deftp
    runningModels
  endproperties

  properties (GetAccess = public, Protected = true)
    ## -*- texinfo -*-
    ## @deftp {ollama} {property} mode
    ##
    ## Inference mode.
    ##
    ## Specifies the inference mode that the ollama interface object will use
    ## to send requests to the ollama server.  Currently, only @qcode{'query'}
    ## and @qcode{'chat'} modes are implemented.
    ##
    ## @end deftp
    mode = 'query';

    ## -*- texinfo -*-
    ## @deftp {ollama} {property} serverURL
    ##
    ## URL of the ollama server.
    ##
    ## Specifies the network IP address and the port at which the ollama
    ## interface object is connected to.
    ##
    ## @end deftp
    serverURL = '';

    ## -*- texinfo -*-
    ## @deftp {ollama} {property} availableModels
    ##
    ## Display available models.
    ##
    ## Displays the models that are currently available in ollama server.
    ##
    ## @end deftp
    availableModels = {''};

    ## -*- texinfo -*-
    ## @deftp {ollama} {property} responseStats
    ##
    ## Response Statistics of LLM.
    ##
    ## Contains various metrics about the last processed request and the
    ## response returned from the ollama server.
    ##
    ## @end deftp
    responseStats = struct ();

    ## -*- texinfo -*-
    ## @deftp {ollama} {property} chatHistory
    ##
    ## Chat history of current session.
    ##
    ## Contains an @math{Nx3} cell array with the history of user prompts,
    ## images (if any), and models response for a given chat session. The first
    ## column contains character vectors with the user's prompts, the second
    ## column contains a nested cell array with any images attached to the
    ## corresponding user prompt (otherwise it is empty), and the third column
    ## contains the model's responses.  By default, @qcode{chatHistory} is an
    ## empty cell array, and it is only populated while in  @qcode{'chat'} mode.
    ##
    ## @end deftp
    chatHistory = {};
  endproperties

  properties (GetAccess = public)
    ## -*- texinfo -*-
    ## @deftp {ollama} {property} activeModel
    ##
    ## The model to be used for any user request for inference.
    ##
    ## The name of the model that will be used for generating the response to
    ## the next user request.  This is empty upon construction and it must be
    ## specified before requesting any inference from the ollama server.
    ##
    ## @end deftp
    activeModel = '';

    ## -*- texinfo -*-
    ## @deftp {ollama} {property} readTimeout
    ##
    ## Network read timeout.
    ##
    ## The time in seconds that the ollama interface object will wait for a
    ## server response before closing the connection with an error.
    ##
    ## @end deftp
    readTimeout = 300;

    ## -*- texinfo -*-
    ## @deftp {ollama} {property} writeTimeout
    ##
    ## Network write timeout.
    ##
    ## The time in seconds that the ollama interface object will wait for a
    ## request to be successfully sent to the server before closing the
    ## connection with an error.
    ##
    ## @end deftp
    writeTimeout = 300;

    ## -*- texinfo -*-
    ## @deftp {ollama} {property} options
    ##
    ## Custom options.
    ##
    ## A structure containing fields as optional parameters to be passed to a
    ## model for inference at runtime.  By default, this is an empty structure,
    ## in which case the model utilizes its default parameters as specified in
    ## the respective model file in the ollama server.  See the
    ## @code{setOptions} method for more information about the custom parameters
    ## you can specify.
    ##
    ## @end deftp
    options = struct ();

    ## -*- texinfo -*-
    ## @deftp {ollama} {property} systemMessage
    ##
    ## System message.
    ##
    ## A character vector containing the system message, which may be used to
    ## provide crucial context and instructions that guide how the model behaves
    ## during your interactions.  By default, @qcode{systemMessage = 'default'},
    ## in which case the model utilizes its default system prompt as specified
    ## in the respective model file in the ollama server.  Specifying  a system
    ## message results in the @code{query} or @code{chat} methods parsing the
    ## customized system message to the model in every interaction.  The system
    ## message cannot be modified during a chat session.  Use dot notation to
    ## access and/or modify the default value of the system message.
    ##
    ## @end deftp
    systemMessage = 'default';

    ## -*- texinfo -*-
    ## @deftp {ollama} {property} thinking
    ##
    ## Flag for thinking.
    ##
    ## A logical scalar or a character vector specifying the thinking status of
    ## the active model.  By default, the thiking status is set to @qcode{true}
    ## for capable models and to @qcode{false} for models that do not support
    ## thiking capabilities.  In special cases, where models support categorical
    ## states of thinking capabilities (such ass the GPT-OSS model family), then
    ## you must specify the thinking status of your choice explicitly, because
    ## the default @qcode{true} value is ignored by the ollama server.  Unless
    ## an active model is set, the @qcode{thinking} property is empty.  Use dot
    ## notation to access and/or modify the default value of the thinking flag.
    ##
    ## Setting a value to the thinking flag when there is no active model or for
    ## an active model that does not have thinking capabilities results to an
    ## error.
    ##
    ## @end deftp
    thinking = [];

    ## -*- texinfo -*-
    ## @deftp {ollama} {property} tools
    ##
    ## Function tools for tool-capable models.
    ##
    ## A @qcode{toolFunction} object or a @qcode{toolRegistry} object (merely an
    ## indexed collection of toolFunction objects), which are available to the
    ## active model explicitly during chat sessions.  By default, no tools are
    ## available.  Unless an active model capable of tool calling is set, the
    ## @qcode{tools} property is empty.  Moreover, tools can only be assigned
    ## when the active model is tool capable.  Use dot notation to access and/or
    ## assign a @qcode{toolFunction} object or a @qcode{toolRegistry} object.
    ##
    ## @end deftp
    tools = [];

    ## -*- texinfo -*-
    ## @deftp {ollama} {property} muteThinking
    ##
    ## Flag for displaying thinking.
    ##
    ## A logical scalar specifying whether to display thinking text or not.  It
    ## only applies when @qcode{thinking} is enabled and no output argument is
    ## requested from @code{query} and @code{chat} methods.  It also applies to
    ## the @code{showHistory} method, when model responses contain thinking
    ## text. By default, @qcode{muteThinking} is @qcode{true}.  Use dot notation
    ## to access and/or modify the default value.
    ##
    ## @end deftp
    muteThinking = false;
  endproperties

  methods (GetAccess = public)

    ## -*- texinfo -*-
    ## @deftypefn  {ollama} {@var{llm} =} ollama (@var{serverURL})
    ## @deftypefnx {ollama} {@var{llm} =} ollama (@var{serverURL}, @var{model})
    ## @deftypefnx {ollama} {@var{llm} =} ollama (@var{serverURL}, @var{model}, @var{mode})
    ##
    ## Create an ollama interface object.
    ##
    ## @code{@var{llm} = ollama (@var{serverURL})} creates an ollama interface
    ## object, which allows communication with an ollama server accesible at
    ## @var{serverURL}, which must be a character vector specifying a uniform
    ## resource locator (URL).  If @var{serverURL} is empty or @qcode{ollama} is
    ## called without any input arguments, then it defaults to
    ## @code{http://localhost:11434}.
    ##
    ## @code{@var{llm} = ollama (@var{serverURL}, @var{model})} also specifies
    ## the active model of the ollama interface @var{llm} which will be used for
    ## inference.  @var{model} must be a character vector specifying an existing
    ## model at the ollama server.  If the requested model is not available, a
    ## warning is emitted and no model is set active, which is the default
    ## behavior when @code{ollama} is called with fewer arguments.  An active
    ## model is mandatory before starting any communication with the ollama
    ## server.  Use the @code{listModels} class method to see the all models
    ## available in the server instance that @var{llm} is interfacing with.  Use
    ## the @code{loadModel} method to set an active model in an ollama interface
    ## object that has been already created.
    ##
    ## @code{@var{llm} = ollama (@var{serverURL}, @var{model}, @var{mode})} also
    ## specifies the inference mode of the ollama interface.  @var{mode} can be
    ## specified as @qcode{'query'}, for generating responses to single prompts,
    ## @qcode{'chat'}, for starting a conversation with a model by retaining the
    ## entire chat history during inference, and @qcode{'embed'} for generating
    ## embedings for given prompts.  By default, the @code{ollama} interface is
    ## initialized in query mode, unless an embedding model has ben requested,
    ## in which case it defaults to embedding mode.  @qcode{'embed'} is only
    ## valid for embedding models, otherwise @code{ollama} returns an error.
    ## Loading an embedding model overrides any value specified in @var{mode}.
    ##
    ## @seealso{fig2base64}
    ## @end deftypefn
    function this = ollama (serverURL = [], model = '', mode = 'query')
      ## Parse inputs
      if (! any (strcmpi (mode, {'query', 'chat', 'embed'})))
        error ("ollama: unsupported mode option '%s'.", mode);
      endif
      this.mode = tolower (mode);
      if (isempty (serverURL))
        serverURL = "http://localhost:11434";
      elseif (ischar (serverURL))
        serverURL = serverURL;
      else
        error ("ollama: invalid serverURL input.");
      endif
      ## Get list of available models
      [out, err] = __ollama__ ('listModels', 'cellstr', 'serverURL', serverURL);
      if (err)
        this = [];
        error ("ollama: server is inaccessible at %s.", serverURL);
      else
        this.availableModels = out;
        this.serverURL = serverURL;
      endif
      ## Make a model active (if requested AND if available)
      if (! isempty (model) && ischar (model) && isvector (model))
        this.activeModel = model;
        if (checkEmbedding (this))
          [out, err] = __ollama__ ('loadModel', model, ...
                                   'embeddingModel', true, ...
                                   'serverURL', this.serverURL);
          this.mode = 'embed';
        else
          if (strcmp (this.mode, 'embed'))
            error ("ollama: '%s' is not an embedding model.", model);
          endif
          [out, err] = __ollama__ ('loadModel', model, ...
                                   'serverURL', this.serverURL);
        endif
        if (err)
          this.activeModel = '';
          error ("ollama: model '%s' is not available.", model);
        endif
        ## Query active model for information and set default thinking
        ## to true if model is capable of thinking, unless mode == 'embed'
        if (! strcmp (this.mode, 'embed'))
          if (checkThinking (this))
            this.thinking = true;
          else
            this.thinking = false;
          endif
        endif
      endif
    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {ollama} {@var{list} =} listModels (@var{llm})
    ## @deftypefnx {ollama} {@var{list} =} listModels (@var{llm}, @var{outtype})
    ## @deftypefnx {ollama} {} listModels (@dots{})
    ##
    ## List available models in ollama server.
    ##
    ## @code{@var{list} = listModels (@var{llm})} returns a cell array of
    ## character vectors in @var{list} with the names of the models, which are
    ## available on the ollama server that @var{llm} interfaces with.  This is
    ## equivalent to accessing the @qcode{availableModels} property with the
    ## syntax @code{@var{list} = @var{llm}.availableModels}.
    ##
    ## @code{@var{list} = listModels (@var{lllm}, @var{outtype})} also specifies
    ## the data type of the output argument @var{list}.  @var{outtype} must be a
    ## character vector with any of the following options:
    ##
    ## @itemize
    ## @item @qcode{'cellstr'} (default) returns @var{list} as a cell array of
    ## character vectors.  Use this option to see available models for selecting
    ## an active model for inference.
    ## @item @qcode{'json'} returns @var{list} as a character vector containing
    ## the json string response returned from the ollama server.  Use this
    ## option if you want to access all the details about the models available
    ## in the ollama server.
    ## @item @qcode{'table'} returns @var{list} as a table with the most
    ## important information about the available models in specific table
    ## variables.
    ## @end itemize
    ##
    ## @code{listModels (@dots{})} will display the output requested according
    ## to the previous syntaxes to the standard output instead of returning it
    ## to an output argument.  This syntax is not valid for the @qcode{'json'}
    ## option, which requires an output argument.
    ##
    ## @end deftypefn
    function [varargout] = listModels (this, outtype = 'cellstr')
      [list, err] = do_list_models (this, outtype, 'listModels');
      if (err)
        error (err);
      endif
      if (nargout > 0)
        varargout{1} = list;
      elseif (any (strcmp (outtype, {'cellstr', 'table'})))
        disp ("The following models are available in the ollama server:");
        disp (list);
      else
        error ("ollama.listModels: output argument is required for 'json'.");
      endif
    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {ollama} {@var{list} =} listRunningModels (@var{llm})
    ## @deftypefnx {ollama} {@var{list} =} listRunningModels (@var{llm}, @var{outtype})
    ## @deftypefnx {ollama} {} listRunningModels (@dots{})
    ##
    ## List currently running models in ollama server.
    ##
    ## @code{@var{list} = listRunningModels (@var{llm})} returns a cell array of
    ## character vectors in @var{list} with the names of the models, which are
    ## currently loaded in memory at the ollama server that @var{llm} interfaces
    ## with.  This is equivalent to accessing the @qcode{runningModels} property
    ## with the syntax @code{@var{list} = @var{llm}.runningModels}.
    ##
    ## @code{@var{list} = listRunningModels (@var{lllm}, @var{outtype})} also
    ## specifies the data type of the output argument @var{list}.  @var{outtype}
    ## must be a character vector with any of the following options:
    ##
    ## @itemize
    ## @item @qcode{'cellstr'} (default) returns @var{list} as a cell array of
    ## character vectors.  Use this option to see which models are currently
    ## running on the ollama server for better memory management.
    ## @item @qcode{'json'} returns @var{list} as a character vector containing
    ## the json string response returned from the ollama server.  Use this
    ## option if you want to access all the details about currnently running
    ## models.
    ## @item @qcode{'table'} returns @var{list} as a table with the most
    ## important information about the currently running models in specific
    ## table variables.
    ## @end itemize
    ##
    ## @code{listModels (@dots{})} will display the output requested according
    ## to the previous syntaxes to the standard output instead of returning it
    ## to an output argument.  This syntax is not valid for the @qcode{'json'}
    ## option, which requires an output argument.
    ##
    ## @end deftypefn
    function [varargout] = listRunningModels (this, outtype = 'cellstr')
      [list, err] = do_list_models (this, outtype, 'listRunningModels');
      if (err)
        error (err);
      endif
      if (nargout > 0)
        varargout{1} = list;
      elseif (any (strcmp (outtype, {'cellstr', 'table'})))
        disp ("The following models are running in the ollama server:");
        disp (list);
      else
        error ("ollama.listRunningModels: output argument is required for 'json'.");
      endif
    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {ollama} {} copyModel (@var{llm}, @var{source}, @var{target})
    ##
    ## Copy model in ollama server.
    ##
    ## @code{copyModel (@var{llm}, @var{source}, @var{target})} copies the model
    ## specified by @var{source} into a new model named after @var{target} in
    ## the ollama server interfaced by @var{llm}.  Both @var{source} and
    ## @var{target} must be character vectors, and @var{source} must specify an
    ## existing model in the ollama server.  If successful, the available models
    ## in the @qcode{@var{llm}.availableModels} property are updated, otherwise,
    ## an error is returned.
    ##
    ## Alternatively, @var{source} may also be an integer scalar value indexing
    ## an existing model in @qcode{@var{llm}.availableModels}.
    ##
    ## @end deftypefn
    function copyModel (this, model, newmodel)
      if (isnumeric (model))
        if (fix (model) != model)
          error ("ollama.copyModel: index must be an integer value.");
        elseif (model <= numel (this.availableModels) && model > 0)
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

    ## -*- texinfo -*-
    ## @deftypefn {ollama} {} deleteModel (@var{llm}, @var{target})
    ##
    ## Delete model in ollama server.
    ##
    ## @code{deleteModel (@var{llm}, @var{target})} deletes the model specified
    ## by @var{target} in the ollama server interfaced by @var{llm}.
    ## @var{source} can be either a character vector with the name of the model
    ## or an integer scalar value indexing an existing model in
    ## @qcode{@var{llm}.availableModels}.  If successful, the available models
    ## in the @qcode{@var{llm}.availableModels} property are updated, otherwise,
    ## an error is returned.
    ##
    ## @end deftypefn
    function deleteModel (this, model)
      if (isnumeric (model))
        if (fix (model) != model)
          error ("ollama.deleteModel: index must be an integer value.");
        elseif (model <= numel (this.availableModels) && model > 0)
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
      if (strcmp (model, this.activeModel))
        this.activeModel = '';
        this.thinking = [];
        this.tools = [];
      endif
    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {ollama} {} loadModel (@var{llm}, @var{target})
    ##
    ## Load model in ollama server.
    ##
    ## @code{loadModel (@var{llm}, @var{target})} loads the model specified by
    ## @var{target} in the ollama server interfaced by @var{llm}.  This syntax
    ## is equivalent to assigning a value to the @qcode{activeModel} property as
    ## in @qcode{@var{llm}.activeModel = @var{target}}.  If successful,
    ## the specified model is also set as the active model for inference in the
    ## @qcode{@var{llm}.activeModel} property.  @var{target} can be either a
    ## character vector with the name of the model or an integer scalar value
    ## indexing an existing model in @qcode{@var{llm}.availableModels}.
    ##
    ## If loading a model fails, an error message is returned and the properties
    ## @qcode{activeModel}, @qcode{thinking}, and @qcode{tools} are reset to
    ## their default values.
    ##
    ## You can load multiple models conncurently and you are only limited by the
    ## hardware specifications of the ollama server, which @var{llm} interfaces
    ## with.  However, since each time a new model is loaded it is also set as
    ## the active mode for inference, keep in mind that only a single model can
    ## be set active at a time for a given ollama interface object.  The active
    ## model for for inference will always be the latest loaded model.
    ##
    ## @end deftypefn
    function loadModel (this, model)
      if (isnumeric (model))
        if (fix (model) != model)
          error ("ollama.loadModel: index must be an integer value.");
        elseif (model <= numel (this.availableModels) && model > 0)
          model = this.availableModels{model};
        else
          error (strcat ("ollama.loadModel: index to 'availableModels'", ...
                         " property is out of range."));
        endif
      elseif (! ischar (model) || isempty (model))
        error (strcat ("ollama.loadModel: MODEL must be a character", ...
                       " vector or an index to 'availableModels'."));
      endif
      this.activeModel = model;
      if (checkEmbedding (this))
        [out, err] = __ollama__ ('loadModel', model, ...
                                 'embeddingModel', true, ...
                                 'serverURL', this.serverURL);
        this.mode = 'embed';
      else
        [out, err] = __ollama__ ('loadModel', model, ...
                                 'serverURL', this.serverURL);
      endif
      if (err)
        this.activeModel = '';
        this.thinking = [];
        this.tools = [];
        error ("ollama.loadModel: MODEL could not be loaded.");
      endif
      ## Query active model for information and set default thinking
      ## to true if model is capable of thinking, unless mode == 'embed'
      if (! strcmp (this.mode, 'embed'))
        if (checkThinking (this))
          this.thinking = true;
        else
          this.thinking = false;
        endif
      endif
    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {ollama} {} unloadModel (@var{llm}, @var{target})
    ##
    ## Unload model in ollama server.
    ##
    ## @code{unloadModel (@var{llm}, @var{target})} unloads the model specified
    ## by @var{target} from memory of the ollama server interfaced by @var{llm}.
    ## @var{target} can be either a character vector with the name of the model
    ## or an integer scalar value indexing an existing model in
    ## @qcode{@var{llm}.availableModels}.  Use this method to free resources in
    ## the ollama server.  By default, the ollama server unloads any idle model
    ## from memory after five minutes, unless otherwise instructed.
    ##
    ## If the model you unload is also the active model in the ollama interface
    ## object, then the @qcode{activeModel} property is also cleared.  You need
    ## to set an active model before inference.
    ##
    ## @end deftypefn
    function unloadModel (this, model)
      if (isnumeric (model))
        if (fix (model) != model)
          error ("ollama.unloadModel: index must be an integer value.");
        elseif (model <= numel (this.availableModels) && model > 0)
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
      elseif (strcmp (this.activeModel, model))
        this.activeModel = '';
        this.thinking = [];
        this.tools = [];
      endif
    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {ollama} {} pullModel (@var{llm}, @var{target})
    ##
    ## Download model from the ollama library into ollama server.
    ##
    ## @code{pullModel (@var{llm}, @var{target})} downloads the model specified
    ## by @var{target} from the ollama library into the ollama server interfaced
    ## by @var{llm}.  If successful, the model is appended to list of available
    ## models in the @qcode{@var{llm}.availableModels} property.  @var{target}
    ## must be a character vector.
    ##
    ## @end deftypefn
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

    ## -*- texinfo -*-
    ## @deftypefn {ollama} {} setOptions (@var{llm}, @var{name}, @var{value})
    ##
    ## Set custom options for model inference.
    ##
    ## @code{setOptions (@var{llm}, @var{name}, @var{value})} sets custom
    ## options to be parsed to the ollama server in order to tailor the
    ## behavior of the model according to specific needs.  The options must be
    ## specified as @var{name}, @var{value} paired arguments, where @var{name}
    ## is a character vector naming the option to be customized, and @var{value}
    ## can be either numeric or logical scalars depending on the values each
    ## option requires.
    ##
    ## The following options may be customized in any order as paired input
    ## arguments.
    ##
    ## @multitable @columnfractions 0.25 0.02 0.15 0.02 0.56
    ## @headitem @var{name} @tab @tab @var{value} @tab @tab @var{description}
    ## @item @qcode{'num_keep'} @tab @tab integer @tab @tab Specifies how many
    ## of the most recent tokens or responses should be kept in memory for
    ## generating the next output.  Higher values can improve relevance of the
    ## generated text by providing more context.
    ## @item @qcode{'seed'} @tab @tab integer @tab @tab Controls the randomness
    ## of token selection during text generation so that similar responses are
    ## reproduced for the same requests.
    ## @item @qcode{'num_predict'} @tab @tab integer @tab @tab Specifies the
    ## maximum number of tokens to predict when geneerating text.
    ## @item @qcode{'top_k'} @tab @tab integer @tab @tab Limits the number of
    ## possible choices for each next token when generating responses by
    ## specifying how many of the most likely options to consider.
    ## @item @qcode{'top_p'} @tab @tab double @tab @tab Sets the cumulative
    ## probability for nucleus sampling. It must be in the range @math{[0,1]}.
    ## @item @qcode{'min_p'} @tab @tab double @tab @tab Adjusts the sampling
    ## threshold in accordance with the model's confidence. Specifically, it
    ## scales the probability threshold based on the top token's probability,
    ## allowing the model to focus on high-confidence tokens when certain, and
    ## to consider a broader range of tokens when less confident.  It must be in
    ## the range @math{[0,1]}.
    ## @item @qcode{'typical_p'} @tab @tab double @tab @tab Controls how
    ## conventional or creative the responses from a language model will be.  A
    ## higher typical_p value results in more expected and standard responses,
    ## while a lower value allows for more unusual and creative outputs.  It
    ## must be in the range @math{[0,1]}.
    ## @item @qcode{'repeat_last_n'} @tab @tab integer @tab @tab Defines how far
    ## back the model looks to avoid repetition.
    ## @item @qcode{'temperature'} @tab @tab double @tab @tab Controls the
    ## randomness of the generated out by determining how the model leverages
    ## the raw likelihoods of the tokens under consideration for the next words
    ## in a sequence.  It ranges from 0 to 2 with higher values corresponding to
    ## more chaotic output.
    ## @item @qcode{'repeat_penalty'} @tab @tab double @tab @tab Adjusts the
    ## penalty for repeated phrases; higher values discourage repetition.
    ## @item @qcode{'presence_penalty'} @tab @tab double @tab @tab Controls the
    ## diversity of the generated text by penalizing new tokens based on whether
    ## they appear in the text so far.
    ## @item @qcode{'frequency_penalty'} @tab @tab double @tab @tab Controls how
    ## often the same words should be repeated in the generated text.
    ## @item @qcode{'penalize_newline'} @tab @tab logical @tab @tab Discourages
    ## the model from generating newlines in its responses.
    ## @item @qcode{'numa'} @tab @tab logical @tab @tab Allows for non-uniform
    ## memory access to enhance performance.  This can significantly improve
    ## processing speeds on multi-CPU systems.
    ## @item @qcode{'num_ctx'} @tab @tab integer @tab @tab Sets the context
    ## window length (in tokens) determining how much previous text the model
    ## considers.  This should be kept in mind especially in chat seesions.
    ## @item @qcode{'num_batch'} @tab @tab integer @tab @tab Controls the number
    ## of input samples processed in a single batch during model inference.
    ## Reducing this value can help prevent out-of-memory (OOM) errors when
    ## working with large models.
    ## @item @qcode{'num_gpu'} @tab @tab integer @tab @tab Specifies the number
    ## of GPU devices to use for computation.
    ## @item @qcode{'main_gpu'} @tab @tab integer @tab @tab Specified which GPU
    ## device to use for inference.
    ## @item @qcode{'use_mmap'} @tab @tab logical @tab @tab Allows for
    ## memory-mapped file access, which can improve performance by enabling
    ## faster loading of model weights from disk.
    ## @item @qcode{'num_thread'} @tab @tab integer @tab @tab Specifies the
    ## number of threads to use during model generation, allowing you to
    ## optimize performance based on your CPU's capabilities.
    ## @end multitable
    ##
    ## Specified customized options are preserved in the ollama interface object
    ## for all subsequent requests for inference until they are altered or reset
    ## to the model's default value by removing them.  To remove a custom option
    ## pass an empty value to the @var{name}, @var{value} paired argument, as in
    ## @code{setOptions (@var{llm}, 'seed', [])}.
    ##
    ## Use the @code{showOptions} method to display any custom options that may
    ## be currently set in the ollama interface object.  Alternatively, you can
    ## retrieve the custom options as a structure through the @qcode{options}
    ## property as in @code{@var{opts} = @var{llm}.options}, where each field in
    ## @var{opts} refers to a custom property  If no custom options are set,
    ## then @var{opts} is an empty structure.
    ##
    ## You can also set or clear a single custom option with direct assignment
    ## to the @qcode{options} property of the ollama inteface object by passing
    ## the @var{name}, @var{value} paired argument as a 2-element cell array.
    ## The equivalent syntax of @code{setOptions (@var{llm}, 'seed', []} is
    ## @code{@var{llm}.options = @{'seed', []@}}.
    ##
    ## @end deftypefn
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
        if (! isempty (value))
          if (! (isscalar (value) && (isnumeric (value) || islogical (value))))
            error ("ollama.setOptions: VALUE must be a numeric or logical scalar.");
          endif
        endif
        switch (name)
          case 'num_keep'
            if (isfield (this.options, 'num_keep') && isempty (value))
              this.options = rmfield (this.options, 'num_keep');
            elseif (fix (value) == value && value >= 0)
              this.options.num_keep = value;
            else
              error ("ollama.setOptions: 'num_keep' must be a non-negative integer.");
            endif
          case 'seed'
            if (isfield (this.options, 'seed') && isempty (value))
              this.options = rmfield (this.options, 'seed');
            elseif (fix (value) == value && value >= 0)
              this.options.seed = value;
            else
              error ("ollama.setOptions: 'seed' must be a non-negative integer.");
            endif
          case 'num_predict'
            if (isfield (this.options, 'num_predict') && isempty (value))
              this.options = rmfield (this.options, 'num_predict');
            elseif (fix (value) == value && value >= 0)
              this.options.num_predict = value;
            else
              error ("ollama.setOptions: 'num_predict' must be a non-negative integer.");
            endif
          case 'top_k'
            if (isfield (this.options, 'top_k') && isempty (value))
              this.options = rmfield (this.options, 'top_k');
            elseif (fix (value) == value && value >= 0)
              this.options.top_k = value;
            else
              error ("ollama.setOptions: 'top_k' must be a non-negative integer.");
            endif
          case 'top_p'
            if (isfield (this.options, 'top_p') && isempty (value))
              this.options = rmfield (this.options, 'top_p');
            elseif (value >= 0 && value <= 1)
              this.options.top_p = value;
            else
              error ("ollama.setOptions: 'top_p' must be between 0 and 1.");
            endif
          case 'min_p'
            if (isfield (this.options, 'min_p') && isempty (value))
              this.options = rmfield (this.options, 'min_p');
            elseif (value >= 0 && value <= 1)
              this.options.min_p = value;
            else
              error ("ollama.setOptions: 'min_p' must be between 0 and 1.");
            endif
          case 'typical_p'
            if (isfield (this.options, 'typical_p') && isempty (value))
              this.options = rmfield (this.options, 'typical_p');
            elseif (value >= 0 && value <= 1)
              this.options.typical_p = value;
            else
              error ("ollama.setOptions: 'typical_p' must be between 0 and 1.");
            endif
          case 'repeat_last_n'
            if (isfield (this.options, 'repeat_last_n') && isempty (value))
              this.options = rmfield (this.options, 'repeat_last_n');
            elseif (fix (value) == value && value >= 0)
              this.options.repeat_last_n = value;
            else
              error ("ollama.setOptions: 'repeat_last_n' must be a non-negative integer.");
            endif
          case 'temperature'
            if (isfield (this.options, 'temperature') && isempty (value))
              this.options = rmfield (this.options, 'temperature');
            elseif (value >= 0 && value <= 2)
              this.options.temperature = value;
            else
              error ("ollama.setOptions: 'temperature' must be between 0 and 1.");
            endif
          case 'repeat_penalty'
            if (isfield (this.options, 'repeat_penalty') && isempty (value))
              this.options = rmfield (this.options, 'repeat_penalty');
            elseif (value >= 0)
              this.options.repeat_penalty = value;
            else
              error ("ollama.setOptions: 'repeat_penalty' must be positive.");
            endif
          case 'presence_penalty'
            if (isfield (this.options, 'presence_penalty') && isempty (value))
              this.options = rmfield (this.options, 'presence_penalty');
            elseif (value >= 0)
              this.options.presence_penalty = value;
            else
              error ("ollama.setOptions: 'presence_penalty' must be positive.");
            endif
          case 'frequency_penalty'
            if (isfield (this.options, 'frequency_penalty') && isempty (value))
              this.options = rmfield (this.options, 'frequency_penalty');
            elseif (value >= 0)
              this.options.frequency_penalty = value;
            else
              error ("ollama.setOptions: 'frequency_penalty' must be positive.");
            endif
          case 'penalize_newline'
            if (isfield (this.options, 'penalize_newline') && isempty (value))
              this.options = rmfield (this.options, 'penalize_newline');
            elseif (islogical (value))
              this.options.penalize_newline = value;
            else
              error ("ollama.setOptions: 'penalize_newline' must be logical.");
            endif
          case 'numa'
            if (isfield (this.options, 'numa') && isempty (value))
              this.options = rmfield (this.options, 'numa');
            elseif (islogical (value))
              this.options.numa = value;
            else
              error ("ollama.setOptions: 'numa' must be logical.");
            endif
          case 'num_ctx'
            if (isfield (this.options, 'num_ctx') && isempty (value))
              this.options = rmfield (this.options, 'num_ctx');
            elseif (fix (value) == value && value >= 0)
              this.options.num_ctx = value;
            else
              error ("ollama.setOptions: 'num_ctx' must be a non-negative integer.");
            endif
          case 'num_batch'
            if (isfield (this.options, 'num_batch') && isempty (value))
              this.options = rmfield (this.options, 'num_batch');
            elseif (fix (value) == value && value >= 0)
              this.options.num_batch = value;
            else
              error ("ollama.setOptions: 'num_batch' must be a non-negative integer.");
            endif
          case 'num_gpu'
            if (isfield (this.options, 'num_gpu') && isempty (value))
              this.options = rmfield (this.options, 'num_gpu');
            elseif (fix (value) == value && value >= 0)
              this.options.num_gpu = value;
            else
              error ("ollama.setOptions: 'num_gpu' must be a non-negative integer.");
            endif
          case 'main_gpu'
            if (isfield (this.options, 'main_gpu') && isempty (value))
              this.options = rmfield (this.options, 'main_gpu');
            elseif (fix (value) == value && value >= 0)
              this.options.main_gpu = value;
            else
              error ("ollama.setOptions: 'main_gpu' must be a non-negative integer.");
            endif
          case 'use_mmap'
            if (isfield (this.options, 'use_mmap') && isempty (value))
              this.options = rmfield (this.options, 'use_mmap');
            elseif (islogical (value))
              this.options.use_mmap = value;
            else
              error ("ollama.setOptions: 'use_mmap' must be logical.");
            endif
          case 'num_thread'
            if (isfield (this.options, 'num_thread') && isempty (value))
              this.options = rmfield (this.options, 'num_thread');
            elseif (fix (value) == value && value >= 0)
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

    ## -*- texinfo -*-
    ## @deftypefn {ollama} {} showOptions (@var{llm})
    ##
    ## Show custom options.
    ##
    ## @code{showOptions (@var{llm})} displays any custom options that may be
    ## specified in the ollama inteface object @var{llm}.
    ##
    ## @end deftypefn
    function showOptions (this)
      opts = fieldnames (this.options);
      nopt = numel (opts);
      if (nopt)
        for i = 1:nopt
          name = sprintf ("'%s'", opts{i});
          value = this.options.(opts{i});
          if (islogical (value))
            if (value)
              value = 'true';
            else
              value = 'false';
            endif
            fprintf ("%+25s: '%s'\n", name, value);
          elseif (fix (value) == value)
            fprintf ("%+25s: %d\n", name, value);
          else
            fprintf ("%+25s: %f\n", name, value);
          endif
        endfor
      else
        disp ("No custom options are specified.");
      endif
    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {ollama} {} query (@var{llm}, @var{prompt})
    ## @deftypefnx {ollama} {} query (@var{llm}, @var{prompt}, @var{image})
    ## @deftypefnx {ollama} {@var{txt} =} query (@dots{})
    ## @deftypefnx {ollama} {} query (@var{llm})
    ##
    ## Query a model in ollama server.
    ##
    ## @code{query (@var{llm}, @var{prompt})} uses the @qcode{"api/generate"}
    ## API end point to make a request to the ollama server interfaced by
    ## @var{llm} to generate text based on the user's input specified in
    ## @var{prompt}, which must be a character vector.  When no output argument
    ## is requested, @code{query} prints the response text in the standard
    ## output (command window) with a custom display method so that words are
    ## not split between lines depending on the terminal size.  If an output
    ## argument is requested, the text is returned as a character vector and
    ## nothing gets displayed in the terminal.
    ##
    ## @code{query (@var{llm}, @var{prompt}, @var{image})} also specifies an
    ## image or multiple images to be passed to the model along with the user's
    ## prompt.  For a single image, @var{image} must be a character vector
    ## specifying either the filename of an image or a base64 encoded image.
    ## @code{query} distinguishes between the two by scanning @var{image} for
    ## a period character (@qcode{'.'}), which is commonly used as a separator
    ## between base-filename and extension, but it is an invalid character for
    ## base64 encoded strings.  For multiple images, @var{image} must be a cell
    ## array of character vectors explicitly containing either multiple
    ## filenames or mulitple base64 encoded string representations of images.
    ##
    ## @code{@var{txt} = query (@dots{})} returns the generated text to the
    ## output argument @var{txt} instead of displaying it to the terminal for
    ## any of the previous syntaxes.
    ##
    ## @code{query (@var{llm})} does not make a request to the ollama server,
    ## but it sets the @qcode{'mode'} property in the ollama interface object
    ## @var{llm} to @qcode{'query'} for future requests.  Use this syntax to
    ## switch from another inteface mode to query mode without making a request
    ## to the server.
    ##
    ## An alternative method of calling the @code{query} method is by using
    ## direct subscripted reference to the ollama interface object @var{llm} as
    ## long as it already set in query mode. The table below lists the
    ## equivalent syntaxes.
    ##
    ## @multitable @columnfractions 0.5 0.02 0.48
    ## @headitem @var{method calling} @tab @tab @var{object subscripted reference}
    ## @item @qcode{query (@var{llm}, @var{prompt})} @tab @tab
    ## @qcode{@var{llm}(@var{prompt})}
    ## @item @qcode{query (@var{llm}, @var{prompt}, @var{image})} @tab @tab
    ## @qcode{@var{llm}(@var{prompt}, @var{image})}
    ## @item @qcode{query (@var{llm}, @var{prompt}, @var{image})} @tab @tab
    ## @qcode{@var{llm}(@var{prompt}, @var{image})}
    ## @item @qcode{@var{txt} = query (@var{llm}, @var{prompt})} @tab @tab
    ## @qcode{@var{txt} = @var{llm}(@var{prompt})}
    ## @item @qcode{@var{txt} = query (@var{llm}, @var{prompt}, @var{image})}
    ## @tab @tab @qcode{@var{txt} = @var{llm}(@var{prompt}, @var{image})}
    ## @end multitable
    ##
    ## @end deftypefn
    function [varargout] = query (this, varargin)
      ## Check active model exists
      if (isempty (this.activeModel))
        error ("ollama.query: no model has been loaded yet.");
      endif
      ## Allow mode selection
      if (nargin < 2 && nargout == 0)
        this.mode = 'query';
        return;
      elseif (nargin < 2)
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
        args = [args, {type, image}];
      endif
      ## Get thinking status
      if (islogical (this.thinking))
        if (this.thinking)
          think = 'true';
        else
          think = 'false';
        endif
      else
        think = this.thinking;
      endif
      ## Run inference
      [out, err] = __ollama__ ('model', this.activeModel, ...
                               'serverURL', this.serverURL, ...
                               'readTimeout', this.readTimeout, ...
                               'writeTimeout', this.writeTimeout, ...
                               'options', this.options, ...
                               'systemMessage', this.systemMessage, ...
                               'think', think, args{:});
      if (err)
        error ("ollama.query: %s", out);
      endif
      ## Decode json output
      this.responseStats = jsondecode (out);
      ## Get output
      if (this.thinking)
        out = {strtrim(this.responseStats.response); ...
               strtrim(this.responseStats.thinking)};
      else
        out = strtrim (this.responseStats.response);
      endif
      ## Return response text
      if (nargout > 0)
        varargout{1} = out;
      else
        if (this.thinking)
          if (this.muteThinking)
            disp ("Response:\n");
            __disp__ (out{1});
          else
            disp ("<thinking>");
            __disp__ (out{2});
            disp ("</thinking>\n\nResponse:\n");
            __disp__ (out{1});
          endif
        else
          disp ("Response:\n");
          __disp__ (out);
        endif
      endif
    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {ollama} {} chat (@var{llm}, @var{prompt})
    ## @deftypefnx {ollama} {} chat (@var{llm}, @var{prompt}, @var{image})
    ## @deftypefnx {ollama} {} chat (@var{llm}, @{@var{tool_output}@})
    ## @deftypefnx {ollama} {@var{txt} =} chat (@dots{})
    ## @deftypefnx {ollama} {} chat (@var{llm})
    ##
    ## Query a model in ollama server.
    ##
    ## @code{chat (@var{llm}, @var{prompt})} uses the @qcode{"api/chat"} API
    ## end point to make a request to the ollama server interfaced by
    ## @var{llm} to generate text based on the user's input specified in
    ## @var{prompt} along with all previous requests and responses, made by the
    ## user and models during the same chat session, which is stored in the
    ## @qcode{'chatHistory'} property of the ollama interface object @var{llm}.
    ## @var{prompt} must a character vector specifying the content in the user's
    ## message parsed in the request as @qcode{"role":"user"}.  When no output
    ## argument is requested, @code{chat} prints the response text in the
    ## standard output (command window) with a custom display method so that
    ## words are not split between lines depending on the terminal size.  If an
    ## output argument is requested, the text is returned as a character vector
    ## and nothing gets displayed in the terminal.  In either case, the response
    ## text is appended to the history chat, which can be displayed with the
    ## @code{showHistory} method or return as a cell array from
    ## @qcode{@var{llm}.chatHistory}.  If you want to start a new chat session,
    ## you can either clear the chat history with the @code{clearHistory} method
    ## or create a new ollama interface object.
    ##
    ## @code{chat (@var{llm}, @var{prompt}, @var{image})} also specifies an
    ## image or multiple images to be passed to the model along with the user's
    ## prompt.  For a single image, @var{image} must be a character vector
    ## specifying either the filename of an image or a base64 encoded image.
    ## @code{chat} distinguishes between the two by scanning @var{image} for
    ## a period character (@qcode{'.'}), which is commonly used as a separator
    ## between base-filename and extension, but it is an invalid character for
    ## base64 encoded strings.  For multiple images, @var{image} must be a cell
    ## array of character vectors, which can contain both multiple filenames and
    ## mulitple base64 encoded string representations of images.  Any images
    ## supplied along with a prompt during a chat session are also stored in the
    ## chat history.
    ##
    ## @code{chat (@var{llm}, @var{tool_output}) syntax may be used to pass the
    ## output results of a single @qcode{toolFunction} object or mulitple
    ## @qcode{toolFunction} objects contained in a @qcode{toolRegistry}, which
    ## have been evaluated after a previous @qcode{"tool_calls"} request by the
    ## model, to the next message.  This syntax requires the @var{tool_output}
    ## input argument to be a  @math{Nx2} cell array of character vectors, in
    ## which the first column contains the output of each evaluated
    ## @qcode{toolFunction} object and the second column contains its respective
    ## function name.  Each row in @var{tool_output} corresponds to a separate
    ## function, when multiple @qcode{toolFunction} objects have been evaluated.
    ##
    ## @code{@var{txt} = chat (@dots{})} returns the generated text to the
    ## output argument @var{txt} instead of displaying it to the terminal for
    ## any of the previous syntaxes.  If thinking is enabled, then @var{txt} is
    ## a @math{2x1} cell array of character vectors with the first element
    ## containing the final answer and the second element the thinking process.
    ##
    ## @code{chat (@var{llm})} does not make a request to the ollama server,
    ## but it sets the @qcode{'mode'} property in the ollama interface object
    ## @var{llm} to @qcode{'chat'} for future requests.  Use this syntax to
    ## switch from another inteface mode to chat mode without making a request
    ## to the server.  Switching to chat mode does not clear any existing chat
    ## history in @var{llm}.
    ##
    ## An alternative method of calling the @code{chat} method is by using
    ## direct subscripted reference to the ollama interface object @var{llm} as
    ## long as it already set in chat mode. The table below lists the
    ## equivalent syntaxes.
    ##
    ## @multitable @columnfractions 0.5 0.02 0.48
    ## @headitem @var{method calling} @tab @tab @var{object subscripted reference}
    ## @item @qcode{chat (@var{llm}, @var{prompt})} @tab @tab
    ## @qcode{@var{llm}(@var{prompt})}
    ## @item @qcode{chat (@var{llm}, @var{prompt}, @var{image})} @tab @tab
    ## @qcode{@var{llm}(@var{prompt}, @var{image})}
    ## @item @qcode{chat (@var{llm}, @var{prompt}, @var{image})} @tab @tab
    ## @qcode{@var{llm}(@var{prompt}, @var{image})}
    ## @item @qcode{@var{txt} = chat (@var{llm}, @var{prompt})} @tab @tab
    ## @qcode{@var{txt} = @var{llm}(@var{prompt})}
    ## @item @qcode{@var{txt} = chat (@var{llm}, @var{prompt}, @var{image})}
    ## @tab @tab @qcode{@var{txt} = @var{llm}(@var{prompt}, @var{image})}
    ## @end multitable
    ##
    ## @end deftypefn
    function [varargout] = chat (this, varargin)
      ## Check active model exists
      if (isempty (this.activeModel))
        error ("ollama.chat: no model has been loaded yet.");
      endif
      ## Allow mode selection
      if (nargin < 2 && nargout == 0)
        this.mode = 'chat';
        return;
      elseif (nargin < 2)
        error ("ollama.chat: too few input arguments.");
      endif
      ## Initialize new chat or use previous history
      message = {'', {'', ''}, {''; ''; ''}};
      if (! isempty (this.chatHistory))
        message = [this.chatHistory; message];
      endif
      ## Validate first input either as "role:user" or as "role:tool"
      if (nargin > 1)
        prompt = varargin{1};
        if (isempty (this.tools))
          if (isvector (prompt) && ischar (prompt))
            message(end, 1) = prompt;
          else
            error ("ollama.chat: PROMPT must be a character vector.");
          endif
        else
          if (isvector (prompt) && ischar (prompt))
            message(end, 1) = prompt;
          elseif (columns (prompt) == 2 && iscellstr (prompt))
            message(end, 1) = prompt;
          else
            error ("ollama.chat: first input argument must be either", ...
                   " a character vector or a two-column cell array", ...
                   " of character vectors.");
          endif
        endif
      endif
      ## Validate any images
      if (nargin > 2)
        image = varargin{2};
        if (! ischar (image) && ! iscellstr (image) && ! isvector (image))
          error (strcat ("ollama.chat: IMAGE must be either a character", ...
                         " vector or a cell array of character vectors."));
        endif
        ## Check for either imageFile or imageBase64 strings
        if (ischar (image))
          if (any ('.' == image))
            message{end, 2}(1) = 'imageFile';
          else
            message{end, 2}(1) = 'imageBase64';
          endif
          message{end, 2}(2) = image;
        else  # cellstr
          fcn = @(x) any ('.' == x);
          TF = cellfun (fcn, image);
          for img = 1:numel (TF)
            if (TF(img))
              message{end, 2}(img, 1) = 'imageFile';
            else
              message{end, 2}(img, 1) = 'imageBase64';
            endif
            message{end, 2}(img, 2) = image{img};
          endfor
        endif
      endif
      ## Get thinking status
      if (islogical (this.thinking))
        if (this.thinking)
          think = 'true';
        else
          think = 'false';
        endif
      else
        think = this.thinking;
      endif
      ## Handle tools
      if (isempty (this.tools))
        tools = "NA";
      elseif (isa (this.tools, 'toolFunction'))
        tools = jsonencode ({encodeFunction(this.tool)});
      else # it must be a toolRegistry
        tools = jsonencode (encodeRegistry(this.tool));
      endif
      ## Run inference
      [out, err] = __ollama__ ('model', this.activeModel, ...
                               'serverURL', this.serverURL, ...
                               'readTimeout', this.readTimeout, ...
                               'writeTimeout', this.writeTimeout, ...
                               'options', this.options, ...
                               'message', message, ...
                               'systemMessage', this.systemMessage, ...
                               'think', think, 'tools', tools);
      if (err)
        error ("ollama.chat: %s", out);
      endif
      ## Decode json output
      this.responseStats = jsondecode (out, 'makeValidName', false);
      ## Grab tool_calls (if any)
      tool_calls = '';
      if (! isempty (this.tools))
        if (ismember (fieldnames (this.responseStats.message), 'tool_calls'))
          tool_calls = this.responseStats.message.tool_calls;
        endif
      endif
      ## Add response to chat history
      if (this.thinking || ! isempty (tool_calls))
        message{end,3}(1) = strtrim (this.responseStats.message.content);
        message{end,3}(2) = strtrim (this.responseStats.message.thinking);
        message{end,3}(3) = jsonencode (tool_calls);
      else
        message(end,3) = strtrim (this.responseStats.message.content);
      endif
      this.chatHistory = message;
      ## Return response text
      if (nargout > 0)
        varargout{1} = message{end,3};
      else
        if (this.thinking)
          if (this.muteThinking)
            disp ("Response:\n");
            if (isempty (tool_calls))
              __disp__ (message{end,3}{1});
            else
              __json__ (tool_calls);
            endif
          else
            disp ("<thinking>");
            __disp__ (message{end,3}{2});
            disp ("</thinking>\n\nResponse:\n");
            if (isempty (tool_calls))
              __disp__ (message{end,3}{1});
            else
              __json__ (tool_calls);
            endif
          endif
        else
          disp ("Response:\n");
          if (isempty (tool_calls))
            __disp__ (message{end,3}{1});
          else
            __json__ (tool_calls);
          endif
        endif
      endif
    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {ollama} {@var{vectors} =} embed (@var{llm}, @var{input})
    ## @deftypefnx {ollama} {@var{vectors} =} embed (@var{llm}, @var{input}, @var{dims})
    ##
    ## Generate embeddings.
    ##
    ## @code{@var{vectors} = embed (@var{llm}, @var{input})} generates embedding
    ## @var{vectors} corresponding to the user's @var{input}, which can either
    ## be a character vector or a cell array of character vectors.  By default,
    ## when @var{input} is a character vector, @var{vectors} is a row vector
    ## with its length specified by the model's default values, whereas if
    ## @var{input} is a cell array of character vectors, then @var{vectors} is a
    ## matrix with each row corresponding to a linearly indexed element of the
    ## cell array.
    ##
    ## @code{@var{vectors} = embed (@var{llm}, @var{input}, @var{dims})} also
    ## specifies the length of the generated embedding vectors.  @var{dims} must
    ## be a positive integer value, which overrides the default settings of the
    ## embedding model.
    ##
    ## @end deftypefn
    function vectors = embed (this, input, dims = 0)
      ## Check active model exists and has embeding capabilities
      if (isempty (this.activeModel))
        error ("ollama.embed: no model has been loaded yet.");
      endif
      if (! strcmp (this.mode, 'embed'))
        error ("ollama.embed: active model has no embedding capabilities.");
      endif
      ## Check input
      if (isempty (input))
        error ("ollama.embed: INPUT cannot be empty.");
      endif
      if (ischar (input) && isvector (input) || isa (input, 'string'))
        input = cellstr (input);
      endif
      if (! iscellstr (input) || any (cellfun ('isempty', input)))
        error (strcat ("ollama.embed: INPUT must be a non-empty character", ...
                       " vector or a cell array of non-empty character vectors."));
      endif
      ## Check dims
      if (! isscalar (dims) || fix (dims) != dims || dims < 0)
        error ("ollama.embed: DIMS must be a nonnegative integer scalar value.");
      endif
      ## Run inference
      [out, err] = __ollama__ ('model', this.activeModel, ...
                               'serverURL', this.serverURL, ...
                               'readTimeout', this.readTimeout, ...
                               'writeTimeout', this.writeTimeout, ...
                               'options', this.options, ...
                               'input', input, 'dimensions', int16 (dims));
      if (err)
        error ("ollama.embed: %s", out);
      endif
      ## Decode json output
      this.responseStats = jsondecode (out, 'makeValidName', false);
      ## Return embedding vectors
      vectors = this.responseStats.embeddings;
    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {ollama} {} showStats (@var{llm})
    ##
    ## Show response statistics.
    ##
    ## @code{showStats (@var{llm})} displays the response statistics of the last
    ## response returned from the ollama server intefaced by @var{llm}.  The
    ## type of request (e.g. query, chat, embed) does not alter the displayed
    ## statistics, which include the following parameters:
    ##
    ## @itemize
    ## @item total duration: the total time in seconds to process the request
    ## and return the response.
    ## @item load duration: the time in seconds to load the user's request into
    ## the model.
    ## @item evaluation duration: the time in seconds for the model to generate
    ## the response base on the user's request.
    ## @item prompt count: the number of tokens comprising the user's request.
    ## @item evaluation count: the number of tokens comprising the model's
    ## response.
    ## @end itemize
    ##
    ## @end deftypefn
    function showStats (this)
      RS = this.responseStats;
      if (isempty (fieldnames (RS)))
        disp ("No stats to show. Make a query first or start a chat.");
        return;
      endif
      fprintf ("\n  Query answered by '%s' at: %s\n\n", ...
               RS.model, RS.created_at);
      fprintf ("%+25s: %0.2f (sec)\n", 'Total duration', ...
               round (RS.total_duration / 1e+7) / 100);
      fprintf ("%+25s: %0.2f (sec)\n", 'Load duration', ...
               round (RS.load_duration / 1e+7) / 100);
      fprintf ("%+25s: %0.2f (sec)\n\n", 'Evaluation duration', ...
               round (RS.eval_duration / 1e+7) / 100);
      fprintf ("%+25s: %d (tokens)\n", 'Prompt count', ...
               RS.prompt_eval_count);
      fprintf ("%+25s: %d (tokens)\n\n", 'Evaluation count', RS.eval_count);
    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {ollama} {} showHistory (@var{llm})
    ## @deftypefnx {ollama} {} showHistory (@var{llm}, @qcode{'all'})
    ## @deftypefnx {ollama} {} showHistory (@var{llm}, @qcode{'last'})
    ## @deftypefnx {ollama} {} showHistory (@var{llm}, @qcode{'first'})
    ## @deftypefnx {ollama} {} showHistory (@var{llm}, @var{idx})
    ##
    ## Display chat history.
    ##
    ## @code{showHistory (@var{llm})} displays the entire chat history stored in
    ## the ollama interface object @var{llm}.  The chat history is displayed in
    ## chronological order alternating between user's requests and the model's
    ## responses.  For any user's request that contained images, the filenames
    ## or the number of images (in case of base64 encoded images) are also
    ## listed below the corresponding request and before the subsequent
    ## response.
    ##
    ## @code{showHistory (@var{llm}), @qcode{'all'}} is exactly the same as
    ## @code{showHistory (@var{llm})}.
    ##
    ## @code{showHistory (@var{llm}), @qcode{'last'}} displays only the last
    ## user-model interaction of the current chat session.
    ##
    ## @code{showHistory (@var{llm}), @qcode{'first'}} displays only the first
    ## user-model interaction of the current chat session.
    ##
    ## @code{showHistory (@var{llm}), @var{idx}} displays the user-model
    ## interactions specified by @var{idx}, which must be a scalar or a vector
    ## of integer values indexing the rows of the @math{Nx3} cell array
    ## comprising the @qcode{chatHistory} property in @var{llm}.
    ##
    ## @code{showHistory} is explicitly used for displaying the chat history and
    ## does not return any output argument.  If you want to retrieve the chat
    ## history in a cell array, you can access the @qcode{chatHistory} property
    ## directly, as in @code{@var{hdata} = @var{llm}.chatHistory}.
    ##
    ## @end deftypefn
    function showHistory (this, idx = 'all')
      H = this.chatHistory;
      if (isempty (H))
        disp ("No chat history to show. Start a chat first.");
        return;
      endif
      ## Get history length
      Hidx = rows (H);
      if (strcmp (idx, 'all'))
        index = [1:Hidx];
      elseif (strcmp (idx, 'first'))
        index = 1;
      elseif (strcmp (idx, 'last'))
        index = Hidx;
      elseif (isnumeric (idx) && isvector (idx) && all (diff (idx) == 0) &&
              all (fix (idx) == idx) && all (idx > 0) && all (idx <= Hidx))
        index = idx;
      else
        error ("ollama.showHistory: invalid IDX input.");
      endif
      for idx = index
        disp ("User prompt:");
        __disp__ (H{idx,1});
        if (! isempty (H{idx,2}{1}))
          img = H{idx,2};
          TFi = cellfun (@(x)strcmp (x, 'imageFile'), q(:,1));
          isfile = sum (TFi);
          isbase = sum (! TFi);
          temp_s = repmat (" '%s',", 1, isfile)(1:end-1);
          ss = '';
          if (isfile)
            if (isfile > 1)
              ss = 's';
            endif
            fprintf (strcat ("\n User supplied image file%s:", temp_s, "\n"), ...
                     ss, img{TFi,2});
          endif
          if (isbase)
            if (isbase > 1)
              ss = 's';
            endif
            fprintf ("\n User supplied %d Base64 image%s.\n", ss, isbase);
          endif
        endif
        disp ("Model response:");
        if (iscell (H{idx,3}))
          if (this.muteThinking)
            if (isempty (H{idx,3}{3}))
              __disp__ (H{idx,3}{1});
            else
              __json__ (jsondecode (H{idx,3}{3}, 'makeValidName', false));
            endif
          else
            disp ("<thinking>");
            __disp__ (H{idx,3}{2});
            disp ("</thinking>\n\nResponse:\n");
            if (isempty (H{idx,3}{3}))
              __disp__ (H{idx,3}{1});
            else
              __json__ (jsondecode (H{idx,3}{3}, 'makeValidName', false));
            endif
          endif
        else
          __disp__ (H{idx,3});
        endif
      endfor
    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {ollama} {} clearHistory (@var{llm})
    ##
    ## Clear chat history.
    ##
    ## @code{clearHistory (@var{llm})} deletes the entire chat history in the
    ## ollama interface object @var{llm}.  Use this method to initialize a new
    ## chat session.
    ##
    ## @code{clearHistory (@var{llm}), @qcode{'all'}} is exactly the same as
    ## @code{clearHistory (@var{llm})}.
    ##
    ## @code{clearHistory (@var{llm}), @qcode{'last'}} deletes the last
    ## user-model interaction from the current chat session.  Use this option if
    ## you want to rephrase or modify the last request without clear the entire
    ## chat history.
    ##
    ## @code{showHistory (@var{llm}), @qcode{'first'}} removes only the first
    ## user-model interaction from the current chat session.  Use this option if
    ## you want to discard the initial user-model interaction in order to
    ## experiment with the model's context size.
    ##
    ## @code{showHistory (@var{llm}), @var{idx}} deletes the user-model
    ## interactions specified by @var{idx}, which must be a scalar or a vector
    ## of integer values indexing the rows of the @math{Nx3} cell array
    ## comprising the @qcode{chatHistory} property in @var{llm}.
    ##
    ## Note that selectively deleting user-model interactions from the chat
    ## history also removes any images that may be integrated with the selected
    ## requests.
    ##
    ## @end deftypefn
    function clearHistory (this, idx = 'all')
      H = this.chatHistory;
      if (isempty (H))
        return;
      endif
      ## Get history length
      Hidx = rows (H);
      if (strcmp (idx, 'all'))
        this.chatHistory = {};
      elseif (strcmp (idx, 'first'))
        index = 1;
      elseif (strcmp (idx, 'last'))
        index = Hidx;
      elseif (isnumeric (idx) && isvector (idx) && all (diff (idx) == 0) &&
              all (fix (idx) == idx) && all (idx > 0) && all (idx <= Hidx))
        index = idx;
      else
        error ("ollama.clearHistory: invalid IDX input.");
      endif
      this.chatHistory(index,:) = [];
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
      fprintf ("\n  ollama interface in '%s' mode connected at: %s\n\n", ...
               this.mode, this.serverURL);
      fprintf ("%+25s: '%s'\n", 'activeModel', this.activeModel);
      if (islogical (this.thinking))
        if (this.thinking)
          fprintf ("%+25s: true\n", 'thinking');
        else
          fprintf ("%+25s: false\n", 'thinking');
        endif
      elseif (ischar (this.thinking))
        fprintf ("%+25s: '%s'\n", 'thinking', this.thinking);
      endif
      fprintf ("%+25s: %d (sec)\n", 'readTimeout', this.readTimeout);
      fprintf ("%+25s: %d (sec)\n", 'writeTimeout', this.writeTimeout);
      if (length (this.systemMessage) <= 60)
        fprintf ("%+25s: '%s'\n", 'systemMessage', this.systemMessage);
      else
        fprintf ("%+25s: '%s...'\n", 'systemMessage', this.systemMessage(1:60));
      endif
      if (numel (fieldnames (this.options)))
        fprintf ("%+25s: %s\n\n", 'options', 'custom');
      else
        fprintf ("%+25s: %s\n\n", 'options', 'default');
      endif
      if (! isempty (this.availableModels))
        fprintf ("    There are %d available models on this server.\n", ...
                 numel (this.availableModels));
        fprintf (strcat ("    Use 'listModels' and 'listRunningModels'", ...
                         " methods for more information.\n"));
        if (isempty (this.activeModel))
          fprintf ("    Use 'loadModel' to set an active model for inference.\n");

        endif
      else
        fprintf ("    No available models on this server!\n");
        fprintf ("    Use 'pullModel' to download a model from the Ollama library.\n\n");
      endif
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
            if (strcmp (this.mode, 'query'))
              if (nargout == 0)
                query (this, s.subs{:});
              else
                varargout{1} = query (this, s.subs{:});
              endif
            else  # chat mode
              if (nargout == 0)
                chat (this, s.subs{:});
              else
                varargout{1} = chat (this, s.subs{:});
              endif
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
            case 'mode'
              out = this.mode;
            case 'serverURL'
              out = this.serverURL;
            case 'runningModels'
              [out, err] = __ollama__ ('listRunningModels', 'cellstr', ...
                                       'serverURL', this.serverURL);
            case 'availableModels'
              out = this.availableModels;
            case 'responseStats'
              out = this.responseStats;
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
            case 'system'
              out = this.system;
            case 'thinking'
              out = this.thinking;
            case 'tools'
              out = this.tools;
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
            case 'mode'
              error ("ollama.subsref: 'mode' is read only.");
            case 'serverURL'
              error ("ollama.subsref: 'serverURL' is set a construction.");
            case 'runningModels'
              error ("ollama.subsref: 'runningModels' is read only.");
            case 'availableModels'
              error ("ollama.subsref: 'availableModels' is read only.");
            case 'responseStats'
              error ("ollama.subsref: 'responseStats' is read only.");
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
                setOptions (this, val{1}, val{2});
              else
                error (strcat ("ollama.subsref: 'options' must be", ...
                               " a 2-element cell array."));
              endif
            case 'systemMessage'
              if (ischar (val) && isvector (val))
                if (strcmp (this.mode, 'chat') && ! isempty (this.chatHistory))
                  error (strcat ("ollama.subsref: 'systemMessage' cannot", ...
                                 " be modifed during a chat session."));
                endif
                this.systemMessage = val;
              else
                error ("ollama.subsref: 'system' must be a character vector.");
              endif
            case 'thinking'
              if (isscalar (val) && islogical (val) || ischar (val) && ivector (val))
                if (isempty (this.activeModel))
                  error (strcat ("ollama.subsref: cannot assign 'thinking'", ...
                                 " without an active model."));
                endif
                ## Query active model for information and assign
                ## value only if model is capable of thinking
                if (! checkThinking (this))
                  error (strcat ("ollama.subsref: currently active", ...
                                 " model does not support 'thinking'"));
                endif
                this.thinking = val;
              else
                error (strcat ("ollama.subsref: 'thinking' must be either", ...
                               " a logical scalar or a character vector."));
              endif
            case 'tools'
              if (isa (val, 'toolFunction') || isa (val, 'toolRegistry'))
                if (isempty (this.activeModel))
                  error (strcat ("ollama.subsref: cannot assign", ...
                                 " 'tools' without an active model."));
                endif
                ## Query active model for information and assign
                ## value only if model is capable of thinking
                if (! checkToolCalling (this))
                  error (strcat ("ollama.subsref: currently active", ...
                                 " model does not support 'tools'"));
                endif
                this.tools = val;
              else
                error (strcat ("ollama.subsref: 'tool' must be either a", ...
                               " 'toolFunction' or a 'toolRegistry' object."));
              endif
            otherwise
              error ("ollama.subsasgn: unrecongized property: %s", s.subs);
          endswitch
      endswitch

    endfunction

  endmethods

  methods (Access = private)

    ## Function for check if the active model has embedding capabilities
    function out = checkEmbedding (this)
      [out, err] = __ollama__ ('modelInfo', this.activeModel, ...
                               'serverURL', this.serverURL);
      if (err)
        error ("ollama: could not get MODEL info for '%s'", model);
      else
        ## Search the capabilities field for thiking
        if (ismember ('embedding', jsondecode (out).capabilities))
          out = true;
        else
          out = false;
        endif
      endif
    endfunction

    ## Function for check if the active model has thinking capabilities
    function out = checkThinking (this)
      [out, err] = __ollama__ ('modelInfo', this.activeModel, ...
                               'serverURL', this.serverURL);
      if (err)
        error ("ollama: could not get MODEL info for '%s'", model);
      else
        ## Search the capabilities field for thiking
        if (ismember ('thinking', jsondecode (out).capabilities))
          out = true;
        else
          out = false;
        endif
      endif
    endfunction

    ## Function for check if a model has tool-calling capabilities
    function out = checkToolCalling (this)
      [out, err] = __ollama__ ('modelInfo', this.activeModel, ...
                               'serverURL', this.serverURL);
      if (err)
        error ("ollama: could not get MODEL info for '%s'", model);
      else
        ## Search the capabilities field for thiking
        if (ismember ('tools', jsondecode (out).capabilities))
          out = true;
        else
          out = false;
        endif
      endif
    endfunction

    ## Helper function for listing available and running models
    function [list, err] = do_list_models (this, mode, operation)
      if (! any (strcmp (mode, {'cellstr', 'json', 'table'})))
        err = sprintf ("ollama.%s: MODE can be either 'cellstr' or 'json'.", ...
                       operation);
      endif
      if (strcmp (mode, 'table'))
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

## Private function for printing inference text output within the screen's limit
function __disp__ (txt)
  ## Get screen size to trim lines to
  cols = terminal_size ()(2) - 4;
  ## Split text by paragraphs
  ptxt = strsplit (txt, "\n");
  pnum = numel (ptxt);
  for i = 1:pnum
    ## Split text by whitespaces and print in each line as many words as they
    ## can fit without exceeding the screen size and push the remaining words
    ## into the next line.
    wtxt = strsplit (strtrim (ptxt{i}));
    wlen = cellfun (@(x) numel (x) + 1, wtxt);
    while (! isempty (find (cumsum (wlen) >= cols, 1)))
      sidx = find (cumsum (wlen) >= cols, 1) - 1;
      disp (strjoin (wtxt(1:sidx)));
      wtxt(1:sidx) = [];
      wlen = cellfun (@(x) numel (x) + 1, wtxt);
    endwhile
    if (numel (wtxt) > 0)
      disp (strjoin (wtxt));
    endif
    if (i < pnum)
      disp ('');
    endif
  endfor
endfunction

## Private function for printing tool_calls in structured json format
function __json__ (tool_calls)
  toolnum = numel (tool_calls);
  if (toolnum == 1)
    disp ("The following toolFunction object must be evaluated:");
    fprintf ("%+25s: '%s'\n", 'name', tool_calls.function.name);
    ModelArgs = fieldnames (tool_calls.function.arguments);
    fargs = cellfun (@(fnames) tool_calls.function.arguments.(fnames), ...
                     ModelArgs, 'UniformOutput', false);
    fprintf ("%+25s: {'%s': '%s'}\n", 'arguments', ModelArgs{1}, fargs{1});
    for i = 2:numel (ModelArgs)
      fprintf ("%+26s {'%s': '%s'}\n", '', ModelArgs{i}, fargs{i});
    endfor
  else
    disp ("The following toolFunction objects must be evaluated:");
    for t = 1:toolnum
      fprintf ("%+25s: '%s'\n", 'name', tool_calls(t).function.name);
      ModelArgs = fieldnames (tool_calls(t).function.arguments);
      fargs = cellfun (@(fnames) tool_calls(t).function.arguments.(fnames), ...
                       ModelArgs, 'UniformOutput', false);
      fprintf ("%+25s: {'%s': '%s'}\n", 'arguments', ModelArgs{1}, fargs{1});
      for i = 2:numel (ModelArgs)
        fprintf ("%+26s {'%s': '%s'}\n", '', ModelArgs{i}, fargs{i});
      endfor
    endfor
  endif
endfunction
