# Compiler and language

> **CodeOps Skills Version**: 3.13.0

Select this domain for programming languages, compilers, interpreters, query languages, schemas,
protocol decoders, and any system with formal transformation semantics.

## Semantic closure checklist

- Source encoding, lexical rules, whitespace and comments, reserved words, and error recovery
- Complete grammar, precedence, associativity, ambiguity resolution, and parse-tree shape
- Namespaces, scopes, shadowing, imports, visibility, forward references, and cycles
- Type formation, equivalence, subtyping and coercion, inference, polymorphism, constraints, and
  error types
- Compile-time versus runtime behavior, and phase ordering
- Constant evaluation, effects, evaluation order, overflow, undefined behavior, and determinism
- Ownership, lifetime, and resource semantics where applicable
- IR invariants at every level, and their preservation across lowering passes
- Optimization preconditions and semantic-equivalence obligations
- Linking, modules, ABI, serialization, and version compatibility
- Diagnostics: location, recovery, cascades, stability, and machine-readable forms
- Incremental and parallel compilation: invalidation and cache correctness
- Tooling contracts: formatter, language server, debugger, package manager, build system
- Conformance, golden, differential, property, fuzz, and invalid-program tests

## Required counterexamples

For each semantic rule, find minimal examples at the boundaries: empty forms, recursive and cyclic
forms, shadowing, ambiguous parses, conflicting constraints, order-sensitive effects, overflow,
invalid encodings, partial programs, and cross-module interactions. A prose rule is incomplete
until an example distinguishes it from the plausible alternatives.

## Gate

The semantics gate fails when two conforming implementations could produce observably different
results from the same valid program, or when invalid input has no defined rejection or recovery
class — unless that freedom is an explicit part of the language contract.
