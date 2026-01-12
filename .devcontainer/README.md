# Dev Container

This directory contains the devcontainer.json, Docker configuration, and utility scripts for building, running, and publishing the development container image for this project.

## Folder Structure

```
<root>
└── .devcontainer/
    ├── docker/
    │   ├── Dockerfile          # Multi-stage Dockerfile for building the development container
    │   └── bin/                # Shell scripts for container lifecycle management
    │       ├── build.sh
    │       ├── run.sh
    │       ├── publish.sh
    │       └── clean.sh
    ├── devcontainer.json       # VS Code Dev Container configuration
    └── README.md               # This file
```

## Dev Container Configuration

The [devcontainer.json](devcontainer.json) file configures VS Code's development container environment. Key aspects:

### Build Configuration

```jsonc
"build": {
  "dockerfile": "./docker/Dockerfile",
  "target": "devcontainer",
  "context": "..",
  "args": {
    "USERNAME": "vscode",
    "USER_UID": "1000",
    "USER_GID": "1000"
  }
}
```

- **dockerfile**: Path to the Dockerfile relative to `.devcontainer/`
- **target**: Multi-stage build target to use (see Dockerfile section below)
- **context**: Docker build context (parent directory to access workspace files)
- **args**: Build arguments passed to Docker (see Dockerfile Build Arguments section)

### Workspace Configuration

```jsonc
{
	"remoteUser": "vscode",
	"workspaceFolder": "/home/<remoteUser>/workspace",
	"workspaceMount": "source=${localWorkspaceFolder},target=/home/vscode/workspace,type=bind,consistency=cached"
}
```

- **remoteUser**: `vscode` - Non-root user for development (matches USERNAME build arg)
- **workspaceFolder**: `/home/<remoteUser>/workspace` - Container path where workspace is mounted
- **workspaceMount**: Bind mount configuration with cached consistency for performance

### SSH Keys

Local ssh keys will be mounted, to allow seamless integration with remote servers. Comment out if this behavior is undesired.

```jsonc
{
	"mounts": ["source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,consistency=cached"]
}
```

### Additional Features

The configuration installs development tools via [devcontainers features](https://containers.dev/features):

- **Languages**: Node.js (LTS), Python 3.11 (configurable), Terraform 1.4.5 (configurable)
- **Linters/Formatters**: Prettier, Pylint, Black, isort
- **Tools**: Docker-in-Docker, GitHub CLI, AWS CLI
- **Extensions**: Python, Terraform, Markdown, YAML, ESLint, and more

## Docker

The [Dockerfile](docker/Dockerfile) uses a multi-stage build with two targets:

### Build Targets

1. **base** - Minimal Debian-based image with essential packages (build tools, git, sudo, etc.)
1. **devcontainer** - Extends base with a non-root user, Homebrew, and development tools
1. **codeserver** - A [Coder (code-server)](https://coder.com/docs/code-server) instance (_experimental_)
1. **production** - Minimal production image based on base (includes tini for proper signal handling)

### Build Arguments

The Dockerfile accepts several build arguments that can be customized:

| Argument     | Default        | Target     | Description                            |
| ------------ | -------------- | ---------- | -------------------------------------- |
| `IMAGE_NAME` | `ubuntu`       | base       | Base image name (must be Debian-based) |
| `VARIANT`    | `latest`       | base       | Base image tag/version                 |
| `USERNAME`   | `devcontainer` | base       | Non-root user name to create           |
| `USER_UID`   | `1000`         | base       | User ID for the non-root user          |
| `USER_GID`   | `$USER_UID`    | base       | Group ID for the non-root user         |
| `BIND_ADDR`  | `0.0.0.0:8080` | codeserver | Group ID for the non-root user         |

> [!NOTE]
> As of Ubuntu 24+, a non-root `ubuntu` user exists. The Dockerfile automatically removes the default `ubuntu` user (UID 1000) to avoid conflicts when creating a custom user.
>
> See the [official docs](https://code.visualstudio.com/remote/advancedcontainers/add-nonroot-user) for more details on non-root users.

### Quick Start

The recommended workflow for working with the container image is:

1. **Build** the image locally
2. **Run** the container to test it
3. **Publish** the image to GitHub Container Registry
4. **Run** again using the published GHCR URL (optional verification)

### Scripts

#### build.sh

Builds the Docker image from the Dockerfile.

##### <ins>Usage</ins>

```
build.sh <image-name[:build_target]> [build-args...] [options] [context]
```

**Arguments:**

- `image-name[:build_target]` - Image name with optional build target (e.g., `simple-project:devcontainer`)
- `build-args` - Build arguments passed to `docker build` (e.g., `--build-arg USERNAME=vscode`)
- `options` - Additional Docker build options (e.g., `--no-cache`, `--progress=plain`)
- `context` - Docker build context path (default: workspace root)

**Environment Variables:**

- `IMAGE_NAME` - Override image name
- `DOCKER_TARGET` - Override build target (default: `devcontainer`)
- `DOCKER_CONTEXT` - Override build context path
- `REMOTE_USER` - Override remote user (sets `--build-arg USERNAME=$REMOTE_USER`)

**Examples:**

```bash
# Build with default settings
./.devcontainer/docker/bin/build.sh simple-project

# Build with standard user and context
./.devcontainer/docker/bin/build.sh simple-project vscode .

# Build with build args and options
./.devcontainer/docker/bin/build.sh simple-project \
  --build-arg VARIANT=jammy \
  --no-cache \
  --progress=plain

# Build custom target
./.devcontainer/docker/bin/build.sh simple-project:production

# Using environment variables
IMAGE_NAME=simple-project \
DOCKER_TARGET=devcontainer \
REMOTE_USER=vscode \
DOCKER_CONTEXT=. \
./.devcontainer/docker/bin/build.sh
```

#### run.sh

Runs the Docker container with the workspace mounted.

##### <ins>Usage</ins>

```
run.sh <image-name[:build_target]> [remote-user] [commands] [context]
```

**Arguments:**

- `image-name[:build_target]` - Image name with optional build target (required)
- `remote-user` - Username inside container (default: `devcontainer`)
- `context` - Local directory to mount as workspace (default: workspace root)

**Environment Variables:**

- `IMAGE_NAME` - Override image name
- `DOCKER_TARGET` - Override build target (default: `devcontainer`)
- `DOCKER_CONTEXT` - Override context path
- `REMOTE_USER` - Override remote user

**Examples:**

```bash
# Run with short form (adds :devcontainer automatically)
./.devcontainer/docker/bin/run.sh simple-project

# Run custom target
./.devcontainer/docker/bin/run.sh simple-project:production

# Run from GitHub Container Registry
./.devcontainer/docker/bin/run.sh \
  ghcr.io/stairwaytowonderland/simple-project:latest

# Run with custom user and context
./.devcontainer/docker/bin/run.sh simple-project vscode .
```

#### publish.sh

Publishes the Docker image to GitHub Container Registry. Also performs cleanup by removing dangling images after tagging.

> [!NOTE]
> In order to publish to the github package registry, an access token is **required** for authentication.
>
> See the [official docs](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#authenticating-with-a-personal-access-token-classic) for more details on **authenticating with a personal access token**.

##### <ins>Usage</ins>

```
publish.sh <image-name[:build_target]> [github-username] [image-version]
```

**Arguments:**

- `image-name[:build_target]` - Image name with optional build target (required)
- `github-username` - GitHub username (required, can use `GITHUB_USER` env var)
- `image-version` - Version tag for the image (default: `latest`)

**Environment Variables:**

- `IMAGE_NAME` - Override image name
- `DOCKER_TARGET` - Override build target (default: `devcontainer`)
- `GITHUB_USER` - GitHub username (alternative to argument)
- `IMAGE_VERSION` - Override version tag
- `CR_PAT` - GitHub Personal Access Token (required)

**Examples:**

```bash
# Publish with short form
./.devcontainer/docker/bin/publish.sh \
  simple-project \
  stairwaytowonderland

# Publish with all arguments
CR_PAT=<your-github-token> ./.devcontainer/docker/bin/publish.sh \
    simple-project:devcontainer \
    stairwaytowonderland \
    latest

# Using only environment variables
GITHUB_USER=<your-github-user> \
CR_PAT=<your-github-token> \
IMAGE_NAME=simple-project \
./.devcontainer/docker/bin/publish.sh

# Using GitHub CLI token
export CR_PAT=$(gh auth token)
./.devcontainer/docker/bin/publish.sh \
  simple-project \
  stairwaytowonderland
```

#### clean.sh

Removes all dangling (untagged) Docker images that are not associated with any container. These are typically intermediate images left over from builds or retagging operations.

##### <ins>Usage</ins>

```
clean.sh
```

**Example:**

```bash
# Remove all dangling images
./.devcontainer/docker/bin/clean.sh
```

> [!NOTE]
> This script is provided for convenience and removes images that are no longer tagged or referenced. The publish script automatically performs basic cleanup, so this is typically only needed for manual cleanup operations.

### Recommended Workflow

```bash
# 1. Build the image with a custom user and context
./.devcontainer/docker/bin/build.sh simple-project vscode .

# 2. Test run locally with custom user and context
./.devcontainer/docker/bin/run.sh simple-project vscode .

# 3. Publish to GHCR
CR_PAT=<your_github_token> \
  ./.devcontainer/docker/bin/publish.sh \
    simple-project \
    <your_github_username>

# 4. (Optional) Test run from GHCR
./.devcontainer/docker/bin/run.sh \
  ghcr.io/<your_github_username>/simple-project:latest \
  vscode \
  .
```
