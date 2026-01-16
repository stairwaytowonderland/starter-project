# Dockerfile

A detailed guide to the Dockerfile.

_TODO_: Add complete details for each build target.

## Folder Structure

```
<root>
└── .devcontainer/
    └── docker/
        ├── .env                # Your .env file (not in version control)
        ├── Dockerfile          # Multi-stage Dockerfile for building the development container
        ├── README.md           # This file
        ├── sample.env          # The sample env file to be copied
        └── bin/                # Shell scripts for container lifecycle management
            ├── build.sh
            ├── clean.sh
            ├── exec-com.sh
            ├── load-env.sh
            ├── publish.sh
            └── run.sh
```

## Environment Variables

1. Copy the [sample.env](./sample.env) and create a `.env`:

    ```bash
    cp sample.env .env
    ```

1. Now update the `.env` that was just created with the relevant information.
    - **GITHUB_REPO**: Should be the name of your repository (e.g. if the url is https://github.com/octocat/Hello-World, `GITHUB_REPO` would be _'Hello-World'_).
    - **GITHUB_NAMESPACE**: Should be namespace owner of the repo (e.g. if the url is https://github.com/octocat/Hello-World, `GITHUB_NAMEPSACE` would be _'octocat'_)
    - **GITHUB_TOKEN**: The access token used to [publish](#publishsh) your image to the Github package registry.

> [!TIP]
> Optionally, manually load the `.env` file into your environment (not needed since the provided scripts will load the file):
>
> ```bash
> # ... load .env file, exporting all variables
> set -a; . .env; set +a
> ```

## Build Targets

1. **base** - Minimal Debian-based image with essential packages (build tools, git, sudo, etc.)
1. **devcontainer** - Extends base with a non-root user, Homebrew, and development tools
1. **codeserver** - A [Coder (code-server)](https://coder.com/docs/code-server) instance (_experimental_)
1. **production** - Minimal production image based on base (includes tini for proper signal handling)

## Build Arguments

The Dockerfile accepts several build arguments that can be customized:

| Argument         | Default                | Target     | Description                            |
| ---------------- | ---------------------- | ---------- | -------------------------------------- |
| `IMAGE_NAME`     | `ubuntu`               | base       | Base image name (must be Debian-based) |
| `VARIANT`        | `latest`               | base       | Base image tag/version                 |
| `USERNAME`       | `devcontainer`         | base       | Non-root user name to create           |
| `USER_UID`       | `1000`                 | base       | User ID for the non-root user          |
| `USER_GID`       | `$USER_UID`            | base       | Group ID for the non-root user         |
| `REPO_NAME`      | `starter-project`      | base       | Your repository name                   |
| `REPO_NAMESPACE` | `stairwaytowonderland` | base       | Your repository namespace (owner)      |
| `BIND_ADDR`      | `0.0.0.0:8080`         | codeserver | Group ID for the non-root user         |

> [!NOTE]
> As of Ubuntu 24+, a non-root `ubuntu` user exists. The Dockerfile automatically removes the default `ubuntu` user (UID 1000) to avoid conflicts when creating a custom user.
>
> See the [official docs](https://code.visualstudio.com/remote/advancedcontainers/add-nonroot-user) for more details on non-root users.

## Quick Start

The recommended workflow for working with the container image is:

1. **Build** the image locally
2. **Run** the container to test it
3. **Publish** the image to GitHub Container Registry
4. **Run** again using the published GHCR URL (optional verification)

## Scripts

### build.sh

Builds the Docker image from the Dockerfile.

#### <ins>Usage</ins>

```
build.sh <image-name[:build_target]> [build-args...] [options] [context]
```

**Arguments:**

- `image-name[:build_target]` - Image name with optional build target (e.g., `starter-project:devcontainer`)
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
./.devcontainer/docker/bin/build.sh starter-project

# Build with standard user and context
./.devcontainer/docker/bin/build.sh starter-project vscode .

# Build with build args and options
./.devcontainer/docker/bin/build.sh starter-project \
  --build-arg VARIANT=jammy \
  --no-cache \
  --progress=plain

# Build custom target
./.devcontainer/docker/bin/build.sh starter-project:production

# Using environment variables
IMAGE_NAME=starter-project \
DOCKER_TARGET=devcontainer \
REMOTE_USER=vscode \
DOCKER_CONTEXT=. \
./.devcontainer/docker/bin/build.sh
```

### run.sh

Runs the Docker container with the workspace mounted.

#### <ins>Usage</ins>

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
./.devcontainer/docker/bin/run.sh starter-project

# Run custom target
./.devcontainer/docker/bin/run.sh starter-project:production

# Run from GitHub Container Registry
./.devcontainer/docker/bin/run.sh \
  ghcr.io/stairwaytowonderland/starter-project:latest

# Run with custom user and context
./.devcontainer/docker/bin/run.sh starter-project vscode .
```

### publish.sh

Publishes the Docker image to GitHub Container Registry. Also performs cleanup by removing dangling images after tagging.

> [!NOTE]
> In order to publish to the github package registry, an access token is **required** for authentication.
>
> See the [official docs](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#authenticating-with-a-personal-access-token-classic) for more details on **authenticating with a personal access token**.

#### <ins>Usage</ins>

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
  starter-project \
  stairwaytowonderland

# Publish with all arguments
CR_PAT=<your-github-token> ./.devcontainer/docker/bin/publish.sh \
    starter-project:devcontainer \
    stairwaytowonderland \
    latest

# Using only environment variables
GITHUB_USER=<your-github-user> \
CR_PAT=<your-github-token> \
IMAGE_NAME=starter-project \
./.devcontainer/docker/bin/publish.sh

# Using GitHub CLI token
export CR_PAT=$(gh auth token)
./.devcontainer/docker/bin/publish.sh \
  starter-project \
  stairwaytowonderland
```

### clean.sh

Removes all dangling (untagged) Docker images that are not associated with any container. These are typically intermediate images left over from builds or retagging operations.

#### <ins>Usage</ins>

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

## Recommended Workflow

```bash
# 1. Build the image with a custom user and context
./.devcontainer/docker/bin/build.sh starter-project vscode .

# 2. Test run locally with custom user and context
./.devcontainer/docker/bin/run.sh starter-project vscode .

# 3. Publish to GHCR
CR_PAT=<your_github_token> \
  ./.devcontainer/docker/bin/publish.sh \
    starter-project \
    <your_github_username>

# 4. (Optional) Test run from GHCR
./.devcontainer/docker/bin/run.sh \
  ghcr.io/<your_github_username>/starter-project:latest \
  vscode \
  .
```
