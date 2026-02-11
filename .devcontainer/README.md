# Dev Container

This directory contains the devcontainer.json, Docker configuration, and utility
scripts for building, running, and publishing the development container image
for this project.

## Folder Structure

```none
<root>
└── .devcontainer/
    ├── docker/
    │   ├── Dockerfile          # Multi-stage Dockerfile
    │   ├── README.md
    │   ├── bin/                # Shell scripts for container lifecycle management
    │   ├── helpers/            # Helper "scripts" with useful functions;
    │   │                         meant to be sourced from other scripts
    │   ├── lib-scripts/        # Container installer scripts
    │   ├── profile.d/          # Profile includes
    │   ├── scripts/            # Container user scripts
    │   └── utils/              # Container utility scripts
    ├── devcontainer.json       # VS Code Dev Container configuration
    └── README.md               # This file
```

## Dev Container Configuration

The [devcontainer.json](devcontainer.json) file configures VS Code's
development container environment.

## Basic Configuration

```jsonc
{
  "name": "Starter Project Dev Container",
  "image": "ghcr.io/stairwaytowonderland/starter-project:latest"
  // ...
}
```

### Build Configuration (Optional)

If using the `build` configuration, the `image` configuration must be disabled.

```jsonc
{
  "name": "Starter Project Dev Container",
  "build": {
    "dockerfile": "./docker/Dockerfile",
    "target": "devtools",
    "context": "..",
    "args": {
      "USERNAME": "vscode",
      // Default values, here for reference
      // "USER_UID": "1000",
      // "USER_GID": "1000"
    }
  }
  // ...
}
```

- **dockerfile**: Path to the Dockerfile relative to `.devcontainer/`
- **target**: Multi-stage build target to use (common: `base`, `devtools`, `cloudtools`)
- **context**: Docker build context (parent directory to access workspace files)
- **args**: Build arguments passed to Docker (see [docker/README.md](./docker/README.md) for full list)

### Workspace Configuration

> [!NOTE]
> See the [Dev Container official pre-defined variable reference](https://containers.dev/implementors/json_reference/#variables-in-devcontainerjson)
> for more details.

```jsonc
{
  // ...
 "remoteUser": "vscode",
 "workspaceMount": "source=${localWorkspaceFolder},target=${containerWorkspaceFolder},type=bind,consistency=cached"
 // ...
}
```

#### Properties

- **remoteUser**: `vscode` - User that devcontainer supporting services/tools run as in the container
  (terminals, tasks, debugging). Does not change the container's main user (set via `containerUser`). Defaults to the
  container's running user (often `root`)
- **containerUser** (not shown): User for all operations run inside the container. Defaults to `root` or the last `USER`
  instruction in the Dockerfile. If you want connected tools to use a different user, use `remoteUser`
- **workspaceMount**: Overrides the default local mount point for the workspace. Supports [Docker CLI `--mount` flag](https://docs.docker.com/engine/reference/commandline/run/#mount)
  syntax with environment and pre-defined variables. **Requires `workspaceFolder` to be set**.
- **workspaceFolder** (not shown; set by default): Sets the default path that devcontainer tools should open when
  connecting to the container.
  Currently both are set to `/home/{remoteUser}/workspace`. **Requires `workspaceMount` to be set**.

  > [!NOTE]
  > `${remoteUser}` is write-only; `{remoteUser}` in the example above is just a placeholder.

#### Pre-defined Variables

These variables are available for use in `devcontainer.json`:

- **${localWorkspaceFolder}**: Path of the local folder opened in VS Code (contains `.devcontainer/devcontainer.json`)
- **${containerWorkspaceFolder}**: Path where the workspace files can be found in the container
- **${localWorkspaceFolderBasename}**: Name of the local folder opened in VS Code
- **${containerWorkspaceFolderBasename}**: Name of the folder where workspace files are located in the container

### SSH Keys

Local ssh keys will be mounted, to allow seamless integration with remote servers. Comment out if this behavior is undesired.

```jsonc
{
  // ...
 "mounts": ["source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,consistency=cached"]
 // ...
}
```

### Additional Features

The configuration installs development tools via [devcontainers features](https://containers.dev/features):

- **Languages**: Node.js (LTS), Python 3.x (default: latest; configurable), Terraform 1.4.5 (configurable)
- **Linters/Formatters**: Prettier, Pylint, Black, isort
- **Tools**: Docker-in-Docker (needs to be enabled/uncommented), GitHub CLI, AWS CLI
- **Extensions**: Python, Terraform, Markdown, YAML, ESLint, and more

## Docker

> [!NOTE]
> See the [docker/README.md](./docker/README.md) for a complete reference.

The [Dockerfile](docker/Dockerfile) uses a multi-stage approach to build several targets.

The primary targets for development containers are:

1. **base** - Foundation development environment with essential tools and configuration
2. **devtools** - Full-featured environment with Python, Node.js, and development tools
3. **cloudtools** - Environment with AWS CLI, Terraform, and cloud infrastructure tools
4. **codeserver** - Web-based VS Code instance with development tools
5. **production** - Minimal production-ready container

Most users will use the **base** or **devtools** target for VS Code Dev Containers.

## CLI Tool

For command line integration, install [the dev container cli](https://code.visualstudio.com/docs/devcontainers/devcontainer-cli#_the-dev-container-cli).

See the [official repo](https://github.com/devcontainers/cli) for a complete reference.

### Install

#### npm

```bash
npm install -g @devcontainers/cli

# Or install locally to workspace (i.e. not global):
# npm install @devcontainers/cli
```

#### Homebrew

> [!NOTE]
> No option for local workspace install

```bash
brew install devcontainer
```

### Usage

```bash
devcontainer up --workspace-folder .
```

See the [official repo](https://github.com/devcontainers/cli) for a complete reference.
