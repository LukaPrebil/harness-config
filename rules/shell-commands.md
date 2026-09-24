# Shell Commands

**When to apply:** running a shell command through a tool.

The pi permission gate floors command wrappers to an approval prompt. Write the command directly.

**why-no-hook:** the model picks the command text; no path or linter sees it.

- Use `printenv`, not a bare `env` `(review-time: see section note)`
- Use the tool timeout, not a `timeout <cmd>` prefix `(review-time: see section note)`
- Drop `nohup`, `time`, and `xargs`; use a loop or the find and ls tools `(review-time: see section note)`
- Run it directly, not `bash -c` or `zsh -lic` `(review-time: see section note)`
- Write a long body to a file, not a heredoc piped to `tail` `(review-time: see section note)`
