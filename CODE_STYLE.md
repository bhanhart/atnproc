# Shell Code Style Guide

Scope

- Applies to all shell scripts in this repository (Bash / POSIX sh compatible).

General Formatting Rules

- Only use spaces for indentation
- Use indentation level of 4 spaces

Function declarations

- Use the `function name` style for function declarations, not `name()`.
- Example:

  function my_task
  {
      # body
  }

Brace style

- Use Allman brace style for functions: opening brace on its own line.

Control-flow formatting

- Put the `then` keyword on its own line; avoid single-line `if ...; then` forms.
- Put the `do` keyword on its own line; avoid single-line `while ...; do` forms.
- Prefer multi-line bodies. Avoid single-line bodies like `if foo; then bar; fi`.
- Example:

  if condition
  then
      do_something
  else
      do_something_else
  fi

Variables

- Preserve existing variable names when editing.
- Do not use single letter variable names. Use descriptive names for variables.
- Use all uppercase names for global variables
- Never declare multiple variables in a single statement.
- Declare variables as close as possible to their first use.
- Declare readonly local variables using 'local -r'
- For each argument passed in to a functino, declare a local variables using the 'local -r name=$1' syntax

Portability

- Always use `bash` syntax and features. Scripts are not required to be POSIX-compatible.

Scoping rules

- Use the local keyword where appropriate to minimize the scope of variables.

Runtime Environment Assumptions

- Assume standard Linux utilities like 'date' and 'hostname' to be available. Do not add checks for them.
- Add availability checks for utilities that are not standard like 'tcpdump' and 'lsof'.
- Do not add fallback logic in case a required utility is not available.

Tooling (optional)

- Do not use automatic formatters (for example `shfmt`, `beautysh`) in this repository.
- Use linters only. `shellcheck` is the recommended linter.
- Optionally add a pre-commit hook to run `shellcheck` on changed shell scripts.

Notes

- These rules are stylistic preferences for consistency across the codebase. When modifying existing scripts, aim for minimal, mechanical edits and preserve existing behavior.
