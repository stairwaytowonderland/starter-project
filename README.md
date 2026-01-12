# Simple Project

Use this repo as a starting point for other new projects.

## Project Structure

```
<root>
├── .devcontainer/
│   ├── docker/               # Dev Container Docker files and scripts
│   ├── devcontainer.json     # VS Code Dev Container configuration
│   └── README.md
├── .vscode/
│   ├── Brewfile              # Brew bundle file to easily install the vscode extensions
│   └── settings.json         # The VS Code settings file
├── src                       # Source files
├── ...                       # Other project files
└── README.md                 # This file
```

## Getting Started

### Clone this Repo

```bash
git clone git@github.com:stairwaytowonderland/simple-project.git
```

### Create a new repository on the command line

```bash
# Delete the .git folder from cloned starter project
rm -rf .git

# Overwrite README with your content
echo "# my-fun-project" >> README.md

# Initialize new git local repository
git init

# Set default branch
git branch -M main

# Make first commit empty to allow easier rebasing
git commit --no-verify --allow-empty -m "Initial empty commit"

# Install pre-commit hooks
# (make sure `pre-commit` is installed ... install it using `pip` or `brew`)
pre-commit install

# Add all files (make sure your .gitignore file is properly configured)
git add .

# Second commit
git commit -m "chore: Adding initial files"

# Set remote ... To update the url (instead of add), use `git remote set-url origin <GIT_URL>`
git remote add origin git@github.com:<user-or-org>/<new-existing-repo>.git

# Push to remote
git push -u origin main
```

## Essential Tools

- [Visual Studio Code](https://code.visualstudio.com/) (a.k.a. _VS Code_)
- [EditorConfig](https://editorconfig.org/)
- [Prettier](https://prettier.io/)
- [pre-commit](https://pre-commit.com/)

## Tool Notes

### General

#### pre-commit

Install with `pip` or `brew`.

> [!NOTE]
> The _VS Code_ `settings.json` file supports [`jsonc`](https://jsonc.org/) syntax (JSON with comments), however the file itself cannot be renamed to a `.jsonc` extension.

To prevent the _pre-commit_ [`pre-commit/check-json`](./.pre-commit-config.yaml) hook from complaining about improper JSON formatting (i.e. comments) in the workspace [.vscode/settings](./.vscode/settings.json) file, it's best to ignore it entirely:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v6.0.0
    hooks:
      - id: check-json
        exclude: ^(\.vscode/.*\.json|devcontainer\.json)$
```

See the [official docs](https://pre-commit.com/) for more details.

#### Prettier

For a more customized experience, some files might need to be excluded from _Prettier_.

See the [official docs](https://prettier.io/docs/ignore) for details on ignoring code.

### Python

#### _Black_ Formatter

The _Black_ formatter uses a `pyproject.toml` as its configuration file, in a `[tool.black]` section.

Use the following to generate a `pyproject.toml`:

```bash
cat > pyproject.toml <<EOF
# Sample pyproject.toml
[tool.black]
line-length = 88
target-version = ['py310', 'py311', 'py312']
include = '\.pyi?$'
EOF
```

#### Pylint

##### <ins>Installing</ins>

Install with `pip` or `brew`.

See the [official docs](https://pylint.readthedocs.io/en/latest/) for more details.

##### <ins>Configuration file</ins>

Generate an **_rc_** (_ini_) style file:

```bash
pylint --generate-rcfile > .pylintrc
```

> [!IMPORTANT]
> Depending on your version of `pylint`/`python`, the `check-fixme-in-docstring` option might need to be commented out.

See the [official docs](https://pylint.readthedocs.io/en/stable/user_guide/usage/run.html) for more details.

## **_VS Code_** as an Editor

> [!NOTE]
> For convenience, a [`Brewfile`](./.vscode/Brewfile) (_located at `./.vscode/Brewfile`_) is provided, which can be used to install all the following extensions.
>
> To install from the Brewfile:
>
> ```bash
> brew bundle install
> ```
>
> See the [official docs](https://docs.brew.sh/Brew-Bundle-and-Brewfile) for more details.

### Language Support Extensions

Essential language support.

#### Python

- [Python](https://marketplace.visualstudio.com/items?itemName=ms-python.python)
- [Python Environments](https://marketplace.visualstudio.com/items?itemName=ms-python.vscode-python-envs)
- [Docstring Highlighter](https://marketplace.visualstudio.com/items?itemName=rodolphebarbanneau.python-docstring-highlighter)

### Code Format Extensions

Essential code formatting extensions.

#### General Purpose

- [EditorConfig](https://marketplace.visualstudio.com/items?itemName=EditorConfig.EditorConfig)
- [Prettier](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode)

#### Configuration Languages

- [TOML](https://marketplace.visualstudio.com/items?itemName=tamasfe.even-better-toml)
- [YAML](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml)

#### Python

- [Black Formatter](https://marketplace.visualstudio.com/items?itemName=ms-python.black-formatter)
- [isort](https://marketplace.visualstudio.com/items?itemName=ms-python.isort)
- [Pylint](https://marketplace.visualstudio.com/items?itemName=ms-python.pylint)

#### IaC

- [Terraform](https://marketplace.visualstudio.com/items?itemName=HashiCorp.terraform)

### Markdown Extensions

Some handy extensions for markdown.

#### General Purpose

- [Code Spell Checker](https://marketplace.visualstudio.com/items?itemName=streetsidesoftware.code-spell-checker) _by streetsidesoftware_ -- About as close as you can get to a proper spell checker when writing markdown
- [Mermaid Markdown Syntax Highlighting](https://marketplace.visualstudio.com/items?itemName=bpruitt-goddard.mermaid-markdown-syntax-highlighting) _by Brian Pruitt-Goddard_ -- enables color coding for Mermaid charting language

#### GitHub Markdown Support

- [GitHub Markdown Preview](https://marketplace.visualstudio.com/items?itemName=bierner.github-markdown-preview) _by Matt Bierner_ -- changes _VS Code_'s built-in markdown preview to match GitHub (install full extension pack)
- [Markdown Preview for Github Alerts](https://marketplace.visualstudio.com/items?itemName=yahyabatulu.vscode-markdown-alert) _by Yahya Batulu_ -- enables GitHub style [alerts](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#alerts)

#### 3rd Party Markdown Support

- [Markdown Admonitions](https://marketplace.visualstudio.com/items?itemName=TomasDahlqvist.markdown-admonitions) _by tomasdahlqvist_ -- enables [MkDocs-style admonitions](https://squidfunk.github.io/mkdocs-material/reference/admonitions/#usage) in the _VS Code_ preview
