# Starter Project

Use this repo as a starting point for other new projects.

## Project Structure

```none
<root>
├── .devcontainer/
│   ├── docker/               # Dev Container Docker files and scripts
│   │   ├── Dockerfile        # Multi-stage Dockerfile
│   │   ├── README.md
│   │   ├── bin/              # Shell scripts for container lifecycle management
│   │   ├── helpers/          # Helper "scripts" with useful functions;
│   │   │                       meant to be sourced from other scripts
│   │   ├── etc/              # etc files to copy
│   │   │   └── profile.d/    # Profile includes
│   │   ├── lib-scripts/      # Container installer scripts
│   │   ├── scripts/          # Container user scripts
│   │   └── utils/            # Container utility scripts
│   ├── devcontainer.json     # VS Code Dev Container configuration
│   └── README.md
├── .vscode/
│   ├── extensions.json       # VS Code recommended extensions file
│   └── settings.json         # VS Code settings file
├── src                       # Source files (example)
├── ...                       # Other project files
└── README.md                 # This file
```

## Getting Started

### Clone this Repo

```bash
git clone git@github.com:stairwaytowonderland/starter-project.git
```

### Create a new repository from the command line

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

# Set remote ...
# To update the url (instead of add), use `git remote set-url origin <GIT_URL>`
git remote add origin git@github.com:<user-or-org>/<new-existing-repo>.git

# Push to remote
git push -u origin main
```

## Essential Tools

- [Visual Studio Code](https://code.visualstudio.com/) (a.k.a. _VS Code_)
- [EditorConfig](https://editorconfig.org/)
- [Prettier](https://prettier.io/)
- [pre-commit](https://pre-commit.com/)

> [!NOTE]
> For a more customized experience, some files might need to be excluded from _Prettier_.
>
> See the [official docs](https://prettier.io/docs/ignore) for details on ignoring code.
