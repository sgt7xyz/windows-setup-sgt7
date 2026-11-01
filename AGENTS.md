# AGENTS.md

Standing instructions for any AI coding agent (Claude Code, Codex, Cursor, Copilot, Gemini CLI)
working in this repository. This file is self-contained. Copy it into an existing project and
rename it to `AGENTS.md`. Follow these rules on every task. If a rule conflicts with a direct
request from the owner in chat, the chat request wins for that task only.

## 1. Project identity

* Owner: SGT7 LLC
* Focus: DevOps, DevSecOps, Cloud Security, Infrastructure Automation
* Every project must be reproducible, documented, and safe to publish publicly.

## 2. Working in an existing codebase

This project already has code, history, and conventions. These rules sit on top of it and must not
cause churn.

* **Existing conventions win.** Before writing anything, read the surrounding code, the README,
  the linter and formatter configs, and the CI workflows. Match naming, layout, and style already
  in use, even where this file would choose differently.
* **Apply this standard to new and touched code only.** Do not reformat, rename, or restructure
  files you were not asked to change. Do not add file headers or rewrite comments across the
  whole repo in one pass.
* **Keep diffs small.** One logical change per commit. Never mix a standards cleanup with a
  feature or bug fix. If a cleanup is worth doing, propose it as a separate change.
* **Do not move things.** Keep the existing folder layout. Section 3 is a suggestion for gaps,
  not a reason to relocate files.
* **Fill gaps on request.** If the project lacks a README, `FUNCTIONALITY.md`, `.gitignore`
  coverage, or CI checks, report the gap and ask before adding it. Use section 11 as the
  template for any missing document.
* **Tooling already in place stays.** If the project uses a different formatter, linter, or test
  runner than the ones named in section 5, keep using the project's tools.
* **Never rewrite git history** or force push unless the owner explicitly asks.
* **Ask before** deleting files, renaming folders, changing public interfaces, upgrading major
  dependency versions, or adding heavy new dependencies.

## 3. Suggested repository layout

Use this only for new folders and new projects. In an existing repo, keep what is already there
and place new files in the closest matching existing folder. Do not invent new top level folders
without asking.

```text
.
├── AGENTS.md          # This file
├── README.md          # How to run the project
├── FUNCTIONALITY.md   # How the code works, a walkthrough
├── SPEC.md            # Optional build contract for larger new features
├── LICENSE            # PolyForm Small Business 1.0.0 (free for small business and nonprofits)
├── .editorconfig      # Cross-editor indentation, line endings, and whitespace rules
├── .gitignore         # Keeps secrets, state files, and build artifacts out of version control
├── src/               # Application or module code
├── infra/             # Terraform, Packer, Ansible, Kubernetes manifests
├── scripts/           # Helper shell or Python scripts
├── tests/             # Automated tests
├── docs/              # Extra documentation and diagrams
└── .github/workflows/ # CI pipelines
```

## 4. Comment and code style

### 4.1 File header

Add this header to every source file you **create**. Add it to an existing file only when you are
already making substantial changes to it and the file has no header. Use the comment syntax of the
language and keep the same fields and order.

```text
# ---------------------------------------------------------------
# File:     <filename>
# Purpose:  <one sentence describing what this file does>
# Project:  <project name>
# Author:   sgt7 LLC
# ---------------------------------------------------------------
```

### 4.2 Comments

* Explain WHY, not WHAT. The code already shows what it does.
* Every function, module, and Terraform resource block with non obvious intent gets a short
  comment above it.
* Write comments as complete sentences starting with a capital letter.
* Use tagged notes only in these forms: `TODO(sgt7):`, `FIXME(sgt7):`, `SECURITY:`, `NOTE:`.
* Never leave commented out dead code in code you write. Delete it, git remembers.
* Do not use em dashes or en dashes in comments, docs, or commit messages. Use commas or periods.

### 4.3 Naming

Follow the project's existing naming first. For new code with no precedent, use this table.

| Item                               | Convention                                                |
| ---------------------------------- | --------------------------------------------------------- |
| Python files, functions, variables | snake_case                                                |
| Python classes                     | PascalCase                                                |
| Shell scripts                      | kebab-case.sh, functions in snake_case                    |
| Terraform resources and variables  | snake_case                                                |
| Kubernetes and Docker names        | kebab-case                                                |
| Constants and env vars             | UPPER_SNAKE_CASE                                          |
| Git branches                       | `feature/short-name`, `fix/short-name`, `docs/short-name` |

## 5. Language rules

Apply these to new and touched code. If the project already enforces stricter or different rules
through config files, those win.

* **Python:** 3.11 or newer, type hints on all function signatures, Google style docstrings,
  format with `ruff format`, lint with `ruff check`.
* **Bash:** start with `#!/usr/bin/env bash` and `set -euo pipefail`, quote all variables, pass
  `shellcheck`.
* **Terraform:** run `terraform fmt` and `terraform validate`, pin provider versions, every
  variable has a `description` and `type`, every output has a `description`.
* **YAML:** 2 space indent, no tabs, quote strings that could be misread as booleans or numbers.
* **Dockerfiles:** pin base image versions (never `latest`), run as non root, use multi stage
  builds where it reduces size.
* **JavaScript or TypeScript:** strict mode, Prettier defaults, ESLint clean.

## 6. Markdown standard

Applies to every `.md` file you create or substantially edit: README, docs, ADRs, PR descriptions.

### 6.1 Structure

* One `#` H1 per file, matching the file's purpose, at the very top. Never skip a heading level
  (no `##` straight to `####`).
* Headings use ATX style (`#`, `##`, `###`), not Setext (underlined with `===` or `---`).
* Title Case for the H1, sentence case for every heading below it. Example: `# Deployment Guide`
  then `## Rollback procedure`.
* Leave exactly one blank line before and after every heading, list, code block, and table.
* Wrap prose at roughly 100 characters per line in source, except inside tables, code blocks, and
  links. This keeps diffs readable.

### 6.2 Lists

* Use `*` for unordered list items, never `-` or `+`. This keeps lists visually distinct from the
  comma rule in section 4.2.
* Use `1.` for every item in an ordered list and let the renderer number them.
* Indent nested list items with 2 spaces.
* Keep list items parallel in structure (all sentence fragments, or all full sentences, not mixed).

### 6.3 Code

* Always fence code blocks with triple backticks and a language tag: ` ```bash `, ` ```python `,
  ` ```hcl `, ` ```yaml `.
* Use single backticks for inline code, file names, commands, variable names, and flags, for
  example `` `terraform apply` ``.
* Never paste a raw terminal prompt (`$` or `%`) inside a code block meant to be copy pasted.

### 6.4 Links and images

* Use reference style links (`[text][ref]`) in long documents to keep prose readable; inline links
  (`[text](url)`) are fine in short files.
* Link text describes the destination. Never use "click here" or a bare URL as the visible text.
* Every image has alt text: `![Architecture diagram showing VPC and subnets](docs/diagram.png)`.

### 6.5 Tables

* Every table has a header row and a separator row.
* Left align text columns, right align number columns, using standard GFM alignment syntax
  (`:--`, `--:`).
* Keep cell content short. Move long explanations to prose above or below the table.

### 6.6 Emphasis and punctuation

* Use `**bold**` for UI labels, required values, and warnings. Use `*italic*` sparingly, for terms
  introduced for the first time.
* No em dashes or en dashes anywhere in Markdown content. Use a comma or a period instead,
  consistent with section 4.2.
* One space after every sentence-ending period. No trailing whitespace at end of line, except the
  two-space hard break when a hard break is truly needed, which is rare and should be avoided in
  favor of a new paragraph.
* Files end with exactly one trailing newline.

### 6.7 Front matter and metadata

* If a static site generator or docs engine needs YAML front matter, put it at the very top of the
  file between `---` lines, keys in lowercase snake_case.
* Otherwise, skip front matter. Do not add metadata blocks that nothing consumes.

### 6.8 Linting

* Format and check with `markdownlint` (or `markdownlint-cli2`) using default rules plus: `MD013`
  line length off for tables and code, `MD033` inline HTML disallowed except `<br>` inside table
  cells, `MD041` first line must be an H1.
* Run the linter before committing any `.md` file, same as `ruff` or `shellcheck` for code.

## 7. Security defaults (non negotiable)

* Never commit secrets, keys, tokens, passwords, or real account IDs. Use federated identity and
  temporary credentials instead of long-lived secrets. For AWS, use Identity Center (AWS SSO). For
  Azure, use Managed Identities or Entra ID Service Principals. For GCP, use Workload Identity
  Federation or Service Accounts with Application Default Credentials. Never store credentials in
  `.env` or on disk.
* Confirm `.gitignore` covers `.env`, `*.tfstate*`, `*.tfvars` with secrets, `*.pem`, and
  `.terraform/`. If it does not, report the gap and propose the additions (see section 12).
* If you find an existing secret in the repo or its history, **stop and tell the owner**. Do not
  just delete it. The secret must be rotated, and history cleanup is the owner's decision.
* Apply least privilege for IAM, service accounts, and network rules.
* Pin dependency and image versions. Prefer digests for container images in production examples.
* Add a `SECURITY:` comment wherever a choice was made for security reasons.
* Use placeholder values such as `example.com`, `123456789012`, and `192.0.2.0/24` in public
  examples.

## 8. Git and commits

Follow the project's existing commit style if it has one. Otherwise use Conventional Commits,
lowercase, imperative mood, subject under 72 characters.

```text
feat: add vpc module with flow logs
fix: correct security group egress rule
docs: update readme quick start
chore: pin terraform provider versions
```

* Make small, focused commits. One logical change per commit.
* Work on a branch, not directly on the default branch.
* Commit or push only when the owner asks.

## 9. Definition of done

Before telling the owner a task is finished, verify every item and report the result:

- [ ] Code runs or validates without errors (state the command used)
- [ ] Formatter and linter pass for the language in use
- [ ] File headers and comments follow section 4
- [ ] README is current and follows the template
- [ ] FUNCTIONALITY.md is current, file by file and function by function, per section 11
- [ ] No secrets or personal data in any file
- [ ] Tests added or updated where tests exist
* [ ] The diff contains only the requested change, with no unrelated reformatting

## 10. Agent behavior

* Read the existing project files before making changes and match what is already there.
* Do not invent commands, flags, or API fields. If unsure, say so and check documentation.
* Prefer the simplest solution that meets the requirement.
* If the request is ambiguous or touches risky areas (auth, data, infra, production), ask first.
* Finish every task with a short **How it works** summary in plain language: what was created or
  changed, how the pieces connect, and how to run it. The owner uses this to learn and to
  explain the project.
* When the owner says they want to learn, switch to mentor mode: explain each step before doing
  it, and let the owner run key commands.

## 11. Documentation standards

### 11.1 README

If the project has a README, keep its current structure and update it in the same change whenever
behavior, setup steps, or configuration changes. If it has none and the owner approves one, use
these sections in this order. If a section does not apply, keep the heading and write
`Not applicable.`

1. Project name, a one sentence description, and badges
1. Overview
1. Architecture
1. Prerequisites (table of requirement and version)
1. Quick start (clone, copy `.env.example` to `.env`, run)
1. Configuration (table of variable, description, default)
1. Usage
1. Project structure
1. Security considerations
1. Testing
1. Troubleshooting (table of problem and fix)
1. Roadmap
1. License
1. Author, "Built by sgt7 LLC."

### 11.2 FUNCTIONALITY.md

`FUNCTIONALITY.md` is a documented code review, written so someone with no prior exposure to the
codebase can get up to speed quickly. The README explains how to run the project.
`FUNCTIONALITY.md` explains how the code works.

If the project has no `FUNCTIONALITY.md`, offer to create one. Once it exists, keep it current:

* Update it at the end of every coding session, before reporting the task as done.
* Update it whenever a function, module, or file is added, removed, or has its behavior changed.
* Update it in the same commit as the code change. A stale file is treated as a bug.

For an existing codebase, document incrementally. Cover the files you touch plus the entry points
first, and note in "Known limitations" which areas are not yet covered.

Required contents, in this order:

1. **System overview.** What the software does in plain language, before any code detail.
1. **How the pieces connect.** A short narrative of what calls what and how data flows.
1. **File by file walkthrough.** Files in the order a newcomer should read them, not
   alphabetical. Each file entry has a **Purpose** and a **Depends on** line.
1. **Function entries.** One per non trivial function, method, class, or Terraform resource
   block, each stating:
   * **Does:** what it does, in plain language.
   * **Inputs:** parameters or variables, with type or shape.
   * **Outputs:** what it returns, writes, or changes.
   * **Why it exists:** what would break or be missing without it.
   * **Side effects:** network calls, file writes, state mutation, or none.
1. **Known limitations or sharp edges.** Assumptions, unhandled edge cases, workarounds, and
   places flagged with `TODO(sgt7):` or `FIXME(sgt7):`.
1. **Change log.** A table of date and one line summary, newest first.

Style rules:

* Write for a competent developer who has never seen this codebase. Define project jargon once.
* Prefer plain language over restating the code. Do not translate syntax word for word.
* Skip trivial functions, such as a getter that only returns a field.
* Keep entries scannable: a short heading, then two to six sentences.

### 11.3 SPEC.md (optional)

For a sizeable new feature in an existing project, offer to write a short `SPEC.md` (one to three
pages) before coding. Say WHAT to build, keep HOW to a minimum, and lock the stack. Use these
sections:

1. Overview
1. Project type (infrastructure, pipeline, security tooling, or application)
1. Goals and non-goals (be explicit about what NOT to build)
1. Tech stack, fixed (layer, choice, pinned version)
1. Users and core flows
1. Requirements and testable acceptance criteria
1. Data model and interfaces
1. Security requirements (secrets, access, network exposure, data sensitivity, compliance)
1. Environments and deployment
1. Build phases, each a verifiable vertical slice, stopping for review after each
1. Verification commands
1. Definition of done
1. Open questions

When the owner provides a spec, read it before coding and implement only the phase requested.
When a wrong choice is made, fix the spec first, then the code.

## 12. Baseline files to suggest

If these are missing from the project, report it and offer to add them. Never overwrite an existing
version. Merge missing entries into it instead.

### 12.1 .gitignore coverage

Make sure these patterns are covered, adding only the ones that are missing.

```gitignore
# SECURITY: Environment files hold real secrets. Only the fake example file is committed.
.env
.env.*
!.env.example

# SECURITY: Keys and certificates must never be committed.
*.pem
*.key
*.p12
*.pfx
*.crt
*.jks
id_rsa*
id_ed25519*

# SECURITY: Terraform state can contain secrets in plain text.
*.tfstate
*.tfstate.*
crash.log
.terraform/
*.tfplan
override.tf
override.tf.json
*_override.tf
*_override.tf.json
# NOTE: Variable files may hold secrets. Commit only the .example copies.
*.tfvars
*.tfvars.json
!*.tfvars.example
# NOTE: The Terraform lock file is intentionally committed to pin provider versions.

# SECURITY: Cloud and tool credentials.
.aws/
credentials
*.secret
*.secrets
secrets.*
!secrets.example.*
.vault-pass*
*.vault
```

### 12.2 .editorconfig

Add only if the project has none, and only with owner approval. It can change how editors format
files, so avoid it where a formatter already owns whitespace.

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2

[*.py]
indent_size = 4

[Makefile]
indent_style = tab

[*.go]
indent_style = tab
```

### 12.3 .env.example

If the project reads environment variables, document them in `.env.example` using fake values
only, and keep real values in an untracked `.env`.

```bash
# SECURITY: Every value below is a placeholder. Do not put real secrets in this file.
APP_ENV=development
DATABASE_URL=postgresql://app_user:change-me@localhost:5432/app_db
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=123456789012
API_BASE_URL=https://api.example.com
API_KEY=replace-with-your-key
```

## 13. Adoption checklist

Run this once when this file is first added to a project, and report the results to the owner
without making changes:

1. List which of README, `FUNCTIONALITY.md`, `.gitignore` secret coverage, `.editorconfig`,
   `.env.example`, tests, and CI exist.
1. Identify the formatter, linter, and test commands the project already uses.
1. Scan for committed secrets, keys, and state files.
1. Note where existing conventions differ from this file.
1. Propose, in priority order, the smallest set of follow up changes, each as its own commit.

Then wait for the owner to choose what to do.
