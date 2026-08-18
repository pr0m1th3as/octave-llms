# llms — roadmap

This is where the package is going and why. It is a statement of intent, not a
schedule: milestones are ordered by what unblocks what, and the version tags are
indicative. Anything here may be reordered by what turns out to be needed.

## What the package is for

Three things, in the order they build on each other:

1. **Text and semantic analysis with local models**, coupled with the
   `statistics` package — embeddings as data, and the whole of
   `Nearest_Neighbors`, clustering and classification applied to them.
2. **A framework for agents, harnesses and agentic systems**, written natively
   in Octave rather than driven from another language.
3. **Octave-fluent assistance** — local models competent enough in Octave to be
   genuinely useful in data and statistical analysis.

The third is not a separate track. It is what the first two compose into, and
the roadmap treats it that way.

## Where the package stands

Version 0.1.4 provides an `ollama` handle class with fifteen public methods and
fourteen properties, covering the server-management endpoints, single-turn
`query`, multi-turn `chat`, and `embed`; the `toolFunction` and `toolRegistry`
classes for describing Octave functions to a model and dispatching its calls
back; and `fig2base64` for putting an Octave figure into a prompt to a
vision-capable model. All of it crosses a single `__ollama__` backend built on a
customised `ollama.hpp`, so there is one place where the wire protocol lives.

The transport layer is in good shape and the tool-calling wire format is
complete: the backend constructs genuine `tool`-role messages carrying the
function name, so a full turn — prompt, tool call, evaluation, result, prompt
again — is representable. That is the difficult half of an agent and it is done.

**Self-tests have started, and they are not finished.** `toolFunction`,
`toolRegistry` and the two constructor branches of `ollama` that raise before
the server is contacted now carry 49 built-in self-tests in
`inst/tests/*.m-tst`, covering normal use, the encoded tool schema, and every
error branch those classes raise.

The rest of the `ollama` class is not covered, for a structural reason worth
stating plainly: **its constructor contacts the server**, so no `ollama` object
can be built without one and almost nothing in the class is reachable offline.
Closing that gap means either a seam that allows a fake transport or a suite
that is honest about requiring a running server. Until then the class is
verified by live runs, which is weaker.

The cost of having had none is on record. The tool-calling path shipped in
0.1.4 broken by six independent defects, each sufficient on its own to stop it,
and every one on a branch that only executes when tools are in use. The paths
without tools worked perfectly, which is exactly why it went out. Four of the
six were reachable only by running against a real server.

## Scope

The package covers **inference against a locally hosted model, and the Octave
machinery built directly on it**. Three boundaries follow, and all three are
deliberate:

- It consumes models; it does not make them. Training, fine-tuning and
  quantisation belong elsewhere.
- It produces data; it does not analyse it. Embeddings come back as ordinary
  numeric matrices because that is already the native input to `pdist2`,
  `kmeans`, `hnswSearcher`, `pca` and the classifiers. Nothing in `statistics`
  is reimplemented here.
- Local first. The value of the package is that the model runs on hardware you
  control, on data you are not sending anywhere.

Everything below is checked against those three lines.

## Milestone 1 — ground to build on (0.2.0)

Two pieces of foundation. Neither is glamorous and everything after depends on
both.

**Built-in self-tests.** Started: the tool classes and their every error
branch are covered. What remains is the `ollama` class itself — `setOptions`
validation over every option it accepts, the `subsref` and `subsasgn` property
gating, and response decoding — none of which is reachable while the
constructor requires a live server. That seam is the real work of this item.

**Structured output.** Ollama accepts a JSON schema as a `format` parameter and
will constrain its response to it. Nothing in the package plumbs it through —
not the class, not the backend, not the vendored header.

This is the single most valuable missing primitive, because it is the difference
between a model that produces prose and a model that produces *data*. Ask five
thousand survey responses to be classified without it, and the result is text to
be parsed with regular expressions: unreproducible, silently lossy, and
impossible to validate. With it, the model becomes a function with a declared
return type, and its output goes into a statistical pipeline directly. Every
quantitative use of a language model in this package depends on it.

The cost is small. `ollama::request` derives from `nlohmann::json` and exposes
`operator[]`, so the wire change is a single assignment; the work is in the
class surface and in deciding how an Octave user writes a schema.

**Per-call accounting.** `responseStats` holds only the most recent response. A
single query is fine; an agent run is a dozen calls whose cost is currently
unmeasurable, and a corpus ingest is thousands. A transcript carrying tokens and
duration per call replaces it, without changing what `showStats` shows.

## Milestone 2 — the semantic analysis stack (0.3.0)

The mathematics of semantic analysis is already available: `statistics` supplies
exact and approximate nearest-neighbour search, clustering, dimensionality
reduction and classification, and `embed` already returns the matrix they all
take. What is missing is everything between a directory of documents and that
matrix.

**A vector store with structural provenance.** An embedding is meaningless
without knowing which model and which dimensionality produced it. Two models'
vectors mixed in one store make every distance computed from it wrong —
silently, with no error, and with no way to detect it afterwards. The store
must therefore *refuse* a vector whose provenance does not match, rather than
document that it should not be given one. This is the design constraint the
container is built around, not a feature of it.

**A normalisation policy, stated.** Approximate search defaults to a Euclidean
metric, and unnormalised embeddings rank differently under Euclidean than under
cosine. Either vectors are normalised on ingest or the metric is recorded
alongside them; what is not acceptable is leaving it to the caller to discover.

**Corpus-scale ingestion.** Chunking with overlap, batching, progress and
resume. Embedding a real corpus is a long-running job and needs the machinery of
one.

**Retrieval.** Query by text rather than by vector, with the embedding step
implicit; results carrying their documents, their scores and their provenance.

Taken together this is retrieval-augmented generation, in Octave, over a corpus
you assembled — and it is also what milestone 4 needs.

## Milestone 3 — the agent framework (0.4.0)

The primitives exist. What is missing is the thing that drives them.

**The loop and its governor.** Bounded iteration with a stated maximum, a
stopping condition, and a defined policy for a tool that raises an error — the
error text must return to the model as a tool result so it can correct itself,
not abort the run. Right now every user writes this `while` themselves, and each
one writes it differently.

**A transcript.** An agent run must be inspectable after the fact and
replayable: what was asked, what was called with what arguments, what came back,
what it cost. This is milestone 1's per-call accounting carried up to the level
of a run.

**Independent agents.** `ollama` is a handle class, which is right for something
stateful, and it therefore needs an explicit `copy` — otherwise an agent cannot
spawn a sub-agent without the two sharing one conversation.

**A stated safety policy.** `evalFunction` evaluates a function handle with
arguments chosen by a language model. The registry is a genuine allowlist and
that is the right foundation, but argument coercion and an optional confirmation
hook belong with it, and the policy should be settled before agents become easy
to build rather than after.

## Milestone 4 — Octave-fluent assistance (0.5.0)

No local model is fluent in Octave today. They produce MATLAB-flavoured guesses,
call functions that do not exist, and are confidently wrong about which package
a name lives in. There are two routes to fixing that and fine-tuning is the
expensive one.

The cheap route is that **Octave can check the model's work while it is
working.** `exist`, `help`, `lookfor` and `test` are exactly the kind of cheap,
safe, read-only functions `toolRegistry` was built to hold. A model that can
look a name up stops inventing names. Combined with milestone 2's retrieval
over the documentation that `pkg-octave-doc` already generates for every Octave
package, the model is made competent at inference time instead of at training
time.

This milestone is therefore mostly assembly: a documentation corpus, an
introspection tool set, and an evaluation harness that runs what the model
writes and scores whether it executed and whether it was right. The harness is
worth having for its own sake — it is how any claim about a model's fluency
becomes a measurement — and the transcripts it produces are, incidentally,
precisely the dataset the expensive route would need.

## Protocol track — runs alongside, blocks nothing

**Streaming.** Every request the vendored header builds sets `stream` to false,
so a response arrives whole or not at all. For a single query that is fine. For
a long generation, and especially for an agent run, it means no output until the
end and no way to interrupt. This is the largest single change in the roadmap
and it touches the backend rather than the class, so it is kept off the critical
path deliberately.

**The remaining Ollama surface.** `keep_alive` is fixed at five minutes in the
header and not exposed; model creation and a few management endpoints are not
implemented.

**An OpenAI-compatible transport.** Ollama also serves the OpenAI-compatible
wire protocol, and so do llama.cpp, vLLM and LM Studio. Speaking that protocol
as a second transport behind the same class would let the package drive any
local server rather than one, for a fraction of the cost of a general provider
abstraction. Worth doing once the class surface has settled; not before.

## Deliberately out of scope

| Not here | Why |
|---|---|
| Training, fine-tuning, quantisation | a different discipline with different tooling; the package consumes models |
| Hosted commercial APIs | local-first is the point of the package — the protocol track reaches local servers, not the hosted services |
| Reimplementing `statistics` | embeddings are matrices, and `statistics` already does the mathematics |
| A classical NLP toolbox | stemmers, taggers, parsers and tf-idf are a different package; embeddings are the route taken here |
| A chat GUI | the package is a library; an application built on it is welcome to be someone's |
| A vector database service | the store is a file you own, not a server you run |

## Standing requirements

These apply to every milestone and are not restated in them.

- Correctness first, verified at the edges. For this package the edges are a
  server that is not running, a request that times out, malformed JSON, and a
  response field that is simply absent — that last one is what broke tool
  calling in 0.1.4.
- Built-in self-tests are a deliverable, covering normal use, edge cases and
  every error branch. The offline surface has no excuse.
- Texinfo help must explain the function completely without recourse to the
  source.
- A `%!demo` block wherever one can run without a server, and a documented
  example wherever it cannot.
- Every parameter added to the backend is added to its documented `Name`/`Value`
  list *and* to the class surface. A parameter reachable only from the backend
  is a parameter nobody will find.
- Anything a model can invoke passes through the registry allowlist. No path
  from a model's response to evaluation may bypass it.
