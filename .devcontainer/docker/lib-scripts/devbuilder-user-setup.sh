#!/usr/bin/env bash

# * Description: Create a non-root user and set up bashrc and profile for both the new user and root

# Only check for errors (set -e)
# Don't check for unset variables (set -u) since variables are set in Dockerfile
# Pipepail (set -o pipefail) is not available in sh
set -e

LEVEL='*' $LOGGER "Setting up bashrc and profile for new users and root ..."

# Comment out the bash_aliases sourcing block in /etc/skel/.bashrc
comment_out_bash_aliases() {
    local file="$1"
    if [ -f "$file" ]; then
        sed -i -E '/if[[:space:]]+\[[[:space:]]+-f[[:space:]]+~\/\.bash_aliases[[:space:]]*\];?[[:space:]]*then/,/^[[:space:]]*fi[[:space:]]*$/s/^/# /' "$file"
    fi
}

# Add parse_git_branch function and update PS1 in color_prompt section
# - Find PS1 lines ending with \$ '
#   - Capture the PS1 prefix (PS1=.*) and the trailing \$ ' (represented as \\\$ \x27)
#     - \\\$ - Matches a literal \$ in the file
#     - \x27 - Hexadecimal escape for a single quote (') character
# - Insert $(parse_git_branch) with blue color (tput setaf 4) before the trailing \$ '
# shellcheck disable=SC2016
update_ps1_with_git_branch() {
    local file="$1"
    if [ -f "$file" ]; then
        # Insert parse_git_branch function before the color_prompt conditional
        sed -i '/if[[:space:]]*\[[[:space:]]*"\$color_prompt"[[:space:]]*=[[:space:]]*yes[[:space:]]*\];[[:space:]]*then/i\
# Function to display current git branch in prompt\
parse_git_branch() { [ -t 1 ] || git branch --no-color 2> /dev/null | sed -e '"'"'/^[^*]/d'"'"' -e '"'"'s/* \\(.*\\)/ (\\1)/'"'"'; }\
' "$file"
        # Update PS1 lines within the color_prompt conditional to include git branch
        sed -i '/if[[:space:]]*\[[[:space:]]*"\$color_prompt"[[:space:]]*=[[:space:]]*yes[[:space:]]*\];[[:space:]]*then/,/^else$/s/\(PS1=.*\)\(\\\$ \x27\)$/\1\$(tput setaf 4)\$(parse_git_branch)\$(tput sgr0)\2/' "$file"
        # Update PS1 in the else block to include git branch
        sed -i '/^else$/,/^fi$/s/\(PS1=.*\)\(\\\$ \x27\)$/\1\$(parse_git_branch)\2/' "$file"
    fi
}

for f in /etc/skel/.bashrc /root/.bashrc; do
    comment_out_bash_aliases "$f"
    update_ps1_with_git_branch "$f"
done

cat << EOF | tee -a /etc/skel/.bashrc /root/.bashrc > /dev/null

# Ensure Homebrew is properly configured
# The brew shellenv line exports HOMEBREW_PREFIX, HOMEBREW_CELLAR,
# and HOMEBREW_REPOSITORY (INFOPATH is also set),
# in addition to prepending the brew 'bin' and 'sbin' to the PATH.
if type "$BREW" &>/dev/null
then
    eval "\$($BREW shellenv)"
fi
EOF

test "$PYTHON_VERSION" = "devcontainer" \
    || test "$PYTHON_VERSION" = "$USERNAME" \
    || test "$PYTHON_VERSION" = "system" \
    || cat << EOF | tee -a /etc/skel/.bashrc /root/.bashrc > /dev/null

if type brew &>/dev/null
then
    # PYTHON_BREW_PATH="\$(brew --prefix python3)/bin"
    PYTHON_BREW_PATH="\$(brew --prefix)/opt/python3/bin"
    if test -d "\$PYTHON_BREW_PATH"
    then
        PATH="\${PYTHON_BREW_PATH}:\${PATH}"
    fi
fi
EOF

test "$PYTHON_VERSION" != "devcontainer" \
    && test "$PYTHON_VERSION" != "$USERNAME" \
    && test "$PYTHON_VERSION" != "system" \
    || cat << EOF | tee -a /etc/skel/.bashrc /root/.bashrc > /dev/null

if type /usr/local/python/current/bin/python3 &>/dev/null
then
    PATH="/usr/local/python/current/bin:\${PATH}"
fi
EOF

# shellcheck disable=SC2181
cat << EOF | tee -a /etc/skel/.bashrc /root/.bashrc > /dev/null

PATH="\$($FIXPATH)"

C_BOLD="\033[1m" C_UNDERLINE="\033[4m" C_REVERSE="\033[7m" \\
C_DEFAULT="\033[0m" C_RESET="\033[0m" C_NORM="\033[0m" \\
C_RED="\033[31m" C_GREEN="\033[32m" C_YELLOW="\033[33m" \\
C_BLUE="\033[34m" C_MAGENTA="\033[35m" C_CYAN="\033[36m" \\
C_RED_BOLD="\033[1;31m" C_GREEN_BOLD="\033[1;32m" \\
C_YELLOW_BOLD="\033[1;33m" C_BLUE_BOLD="\033[1;34m" \\
C_MAGENTA_BOLD="\033[1;35m" C_CYAN_BOLD="\033[1;36m" \\
C_BRIGHT_RED="\033[91m" C_BRIGHT_GREEN="\033[92m" \\
C_BRIGHT_YELLOW="\033[93m" C_BRIGHT_BLUE="\033[94m" \\
C_BRIGHT_MAGENTA="\033[95m" C_BRIGHT_CYAN="\033[96m" \\
C_BRIGHT_RED_BOLD="\033[1;91m" C_BRIGHT_GREEN_BOLD="\033[1;92m" \\
C_BRIGHT_YELLOW_BOLD="\033[1;93m" C_BRIGHT_BLUE_BOLD="\033[1;94m" \\
C_BRIGHT_MAGENTA_BOLD="\033[1;95m" C_BRIGHT_CYAN_BOLD="\033[1;96m" \\
C_WHITE="\033[97m" C_WHITE_BOLD="\033[1;97m" \\
C_BLACK="\033[30m" C_BLACK_BOLD="\033[1;30m"

alias unixtime='date +%s'
alias utctime='date -u +"%Y-%m-%dT%H:%M:%SZ"'
alias now='date "+%A, %B %d, %Y %I:%M:%S %p %Z"'

alias ll='ls -alF'

# Handle exit
__quit() { printf "🤖 %s 🤖\n" "Klaatu barada nikto" >&2; }

# Handle cancelled operations (e.g., Ctrl+C)
__control_c() {
    local err="\$?"
    printf "\n⛔ \${C_RED}\${C_BOLD}✗\${C_DEFAULT} \${C_RED}(%s)\${C_DEFAULT} \${C_RED}\${C_BOLD}%s\${C_DEFAULT} ⛔" "\$err" "Operation cancelled by user" >&2
    return \$err;
}

# Determine if color is supported
__color_enabled() {
    local color_prompt=
    case "\$TERM" in
        xterm-color|*-256color) color_prompt=yes ;;
        *) return 1 ;;
    esac
    if [ "\$color_prompt" = yes ]
    then
        if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null
        then
            return 0
        fi
    fi
    return 1
}

__exit_status() {
    local icon_success="✔"
    local icon_failure="✘"
    local icon_debian="꩜"
    if __color_enabled
    then
        if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null
        then
            if [ "\$1" -eq 0 ]
            then
                printf "%s%s%s " "\$(tput setaf 2)" "\$icon_debian" "\$(tput sgr0)"
            else
                printf "%s%s (%s)%s " "\$(tput setaf 1)" "\$icon_debian" "\$1" "\$(tput sgr0)"
            fi
        fi
    else
        if [ "\$1" -eq 0 ]
        then
            printf "%s " "\$icon_success"
        else
            printf "%s (%s) " "\$icon_failure" "\$1"
        fi
    fi
}

# Standardizes error output
# Usage: errcho "Error message here"
errcho() { >&2 echo -e "\$@"; }

# String Manipulation
# Usage:
#     uppercase "string to convert"
#     echo "string to convert" | uppercase
#     lowercase "STRING TO CONVERT"
#     echo "STRING TO CONVERT" | lowercase
uppercase() {
    if [ -n "\$1" ]
    then
        tr '[:lower:]' '[:upper:]' <<<"\$@"
    else
        tr '[:lower:]' '[:upper:]'
    fi
}
lowercase() {
    if [ -n "\$1" ]
    then
        tr '[:upper:]' '[:lower:]' <<<"\$@"
    else
        tr '[:upper:]' '[:lower:]'
    fi
}

# Boolean Checks
# Usage:
#     is_bool "value"
#     is_true "value"
#     is_false "value"
#     is "value" && echo "Value is true" || echo "Value is false"
is_bool() {
    case "\$1" in
        y|Y|yes|Yes|YES|n|N|no|No|NO|true|True|TRUE|false|False|FALSE|on|On|ON|off|Off|OFF|1|0) errcho true;;
        *) errcho false; return 1;;
    esac
}
is_true() {
    case "\$1" in
        y|Y|yes|Yes|YES|true|True|TRUE|on|On|ON|1) errcho true;;
        *) errcho false; return 1;;
    esac
}
is_false() {
    local err=0
    is_bool "\$1" >/dev/null 2>&1 && ! is_true "\$1" >/dev/null 2>&1 || err=\$?
    [ "\$err" -gt 0 ] && errcho false && return \$err || errcho true
}
is() { is_true "\$1" 2>/dev/null || return \$?; }

# A mostly POSIX Compliant Decimal Comparison
# Simple decimal comparison function.
# Last (4th) argument defaults to false; Setting to true will cause
# the function to return 0 or 1 based on success or failure of the comparison,
# causing an error code of 1 if the comparison fails.
# Usage:
# testd <value1> <value2> <operator> [true|false]
# Example:
# testd 1.0 eq 1.1
# testd 1.0 eq 1.1 eq false
testd() {
    local value1="\${1-}" operator="\${2-}" value2="\${3-}" err=0
    case "\$operator" in
        'eq'|'==') set +e; awk -v a="\$value1" -v b="\$value2" ' BEGIN { if ( a == b ) exit 0; else exit 1 } '; err=\$? ;;
        'ne'|'!=') set +e; awk -v a="\$value1" -v b="\$value2" ' BEGIN { if ( a != b ) exit 0; else exit 1 } '; err=\$? ;;
        'gt'|'>') set +e; awk -v a="\$value1" -v b="\$value2" ' BEGIN { if ( a > b ) exit 0; else exit 1 } '; err=\$? ;;
        'ge'|'>=') set +e; awk -v a="\$value1" -v b="\$value2" ' BEGIN { if ( a >= b ) exit 0; else exit 1 } '; err=\$? ;;
        'lt'|'<') set +e; awk -v a="\$value1" -v b="\$value2" ' BEGIN { if ( a < b ) exit 0; else exit 1 } '; err=\$? ;;
        'le'|'<=') set +e; awk -v a="\$value1" -v b="\$value2" ' BEGIN { if ( a <= b ) exit 0; else exit 1 } '; err=\$? ;;
        *) err=2 ;;
    esac
    echo "\$-" | grep -Eqv '[e]' || set -e
    case "\$err" in
        0) errcho true; [ "true" != "\${4:-false}" ] || return 0;;
        1) errcho false; [ "true" != "\${4:-false}" ] || return 1;;
        *) errcho "Bad number"; return \$err ;;
    esac
}

# OS Detection
os() {
    local os arch
    os="\$(uname -s | lowercase)"
    arch="\$(uname -m)"
    if [ -n "\$arch" ]
    then
        case "\$arch" in
            x86_64|amd64) os="\${os}-amd64" ;;
            aarch64|arm64) os="\${os}-arm64" ;;
            *) os="\${os}-\${arch}" ;;
        esac
    fi
    if [ -r /etc/os-release ]
    then
        # os="\$(. /etc/os-release; echo "\${os}:\${ID-}-\${VERSION_CODENAME-}:\${VERSION_ID-}")"
        while IFS='=' read -r name value; do
            case "\$name" in
                ID) os_id="\${value//\"/}";;
                VERSION_ID) os_version_id="\${value//\"/}";;
                VERSION_CODENAME) os_codename="\${value//\"/}";;
            esac
        done < /etc/os-release
        os="\${os}:\${os_id}-\${os_codename}:\${os_version_id}"
    fi
    echo "\${os}"
}
os_platform() { os | cut -d: -f1; }
os_type() { os_platform | cut -d- -f1; }
os_arch() { os_platform | cut -d- -f2; }
os_name() { os | cut -d: -f2; }
os_id() { os_name | cut -d- -f1; }
os_codename() { os_name | cut -d- -f2; }
os_version() { os | cut -d: -f3; }

if [ -t 1 ]
then
    PS1='\$(__exit_status \$?)'\$PS1
fi

# Additional alias definitions.
if [ -f ~/.bash_aliases ]
then
    . ~/.bash_aliases
fi

if [ -f /etc/profile.d/bash_colors.sh ] && ! shopt login_shell >/dev/null
then
    . /etc/profile.d/bash_colors.sh
fi
EOF

cat << EOF | tee -a /etc/skel/.profile /root/.profile > /dev/null

# https://docs.brew.sh/Shell-Completion
if type brew &>/dev/null
then
    HOMEBREW_PREFIX="\$(brew --prefix)"
    if [ -r "\${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]
    then
        source "\${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
    else
        for COMPLETION in "\${HOMEBREW_PREFIX}/etc/bash_completion.d/"*
        do
            ! test  -r "\${COMPLETION}" || source "\${COMPLETION}"
        done
    fi
fi
EOF

# Enable bash completion for root
cat >> /root/.bashrc << EOF

if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
   . /etc/bash_completion
fi
EOF

LEVEL='√' $LOGGER "Done! Bashrc and profile setup complete."

LEVEL='*' $LOGGER "Creating non-root user '$USERNAME' ..."

# Create a new non-root user with sudo privileges
groupadd --gid "$USER_GID" "$USERNAME" \
    && useradd --uid "$USER_UID" --gid "$USER_GID" -m "$USERNAME" -s /bin/bash \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME" \
    && chmod 0440 "/etc/sudoers.d/$USERNAME"

# Create SSH directory for non-root user to ensure proper permissions
mkdir -p "/home/$USERNAME/.ssh" \
    && chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh" \
    && chmod 700 "/home/$USERNAME/.ssh"

cat << EOF | tee -a "/home/$USERNAME/.bash_aliases" /root/.bash_aliases > /dev/null
tux() {
    cat <<'TUX'
           _..._
         .'     '.
        /  _   _  \\
        | (o)_(o) |
         \\(     ) /
         //'._.'\\\ \\
        //   .   \\\ \\
       ||   .     \\\ \\
       |\\   :     / |
       \\\ \`) '   (\`  /_
     _)\`\`".____,.'"' (_
     )     )'--'(     (
      '---\`      \`---'
TUX
}

tux_alt() {
    cat <<'TUX'
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠋⠉⠁⠀⠀⠀⠀⠉⠉⠛⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠛⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣀⠀⠈⠛⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⠉⠁⠀⠀⠈⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠒⠒⢦⡀⠀⠀⠀⠀⠀⠀⠒⠲⢤⡀⠀⠀⠀⠈⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⣠⠶⠶⠄⠱⠀⠀⠀⠀⠴⠾⠶⣆⡀⠹⠄⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⢠⡶⠛⠻⣷⡀⠀⠀⢸⣿⠟⠉⠓⢶⣥⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⢸⡇⠀⠀⢹⢃⣀⣀⡸⣿⠀⠀⠀⢸⣿⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠈⢷⣄⣴⣾⣿⣿⣷⣼⣿⣦⣄⡠⣾⠏⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⣨⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⢿⣦⠀⠀⠀⠀⠀⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠰⠹⣿⣿⣿⣿⣿⣿⣿⣿⡿⢛⣵⣾⠏⠀⠀⠀⠀⠀⠈⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⢰⡉⣙⣛⣛⣛⣛⣭⣵⣾⠟⣋⣥⣦⠀⠀⠀⢸⣦⡀⠙⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⣸⣿⣦⡘⢩⠋⠟⢍⣓⣵⣾⣿⣿⣿⣧⠀⠀⠈⠉⠀⠀⠹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠃⠀⣠⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀⠘⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠋⠀⠀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀⠈⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠁⠀⠀⣼⣿⣿⣿⣿⣿⣿⣿⣿⡿⢽⣿⣿⣿⣿⣿⣿⣿⣿⣿⡄⠀⠀⠀⠀⠀⠀⠀⠈⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠀⠀⢿⣿⡿⢟⣻⣫⣯⣽⣭⢀⣴⣷⣶⣶⣷⣿⣾⣭⣝⣋⠀⠀⠈⢦⡀⠀⠀⠀⠀⠀⠙⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠁⠀⣰⠃⠀⣤⣶⣾⣾⣿⣿⣿⣿⣿⡏⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⡄⠀⠉⠲⡀⠀⠀⠀⠀⠘⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡏⠀⢠⠇⠀⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⢃⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡄⠀⠀⠱⡄⠀⠀⠀⠀⠘⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠀⢠⠏⠀⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡀⠀⠀⠙⣆⠀⠀⠀⠀⠹⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠁⢠⠏⠀⣸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⣸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣇⠀⠀⠀⢸⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠃⢀⡏⠀⢠⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⢸⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⡿⠃⠀⣸⠀⠀⣸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢡⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⢸⠀⠀⠀⠀⠀⠐⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⠇⠀⠀⠹⡆⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⢏⣀⣀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⡆⣀⣠⣀⠙⠦⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡌⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠿⠿⣿⢀⡔⠋⠁⠀⠈⠙⡄⠀⢸⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⡿⣱⣿⣿⣿⣷⡄⠈⠙⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠁⢽⣿⣶⠊⠀⠀⠀⠀⠀⢀⠇⢀⠾⣿⣿⣿⣿⣿⣿
⣿⡿⢛⡛⣛⠛⢋⢼⣿⣿⣿⣿⣿⣿⣆⠀⠀⠙⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⢼⣿⣿⠀⠀⠀⠀⠀⠀⠀⣠⣾⣷⠌⣿⣿⣿⣿⣿
⣿⢨⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣆⠀⠀⠈⠙⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⣺⣿⣿⣆⡀⠀⠀⠀⣀⣴⣿⣿⣿⡆⣿⣿⣿⣿⣿
⣿⢨⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀⠉⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⣾⣿⣿⣿⣿⣽⣯⣿⣿⣿⣿⣿⣿⣿⣎⡻⣿⣿⣿
⣿⡐⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡀⠀⠀⠀⠈⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠱⣻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣎⠻⣿
⣿⡇⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡄⢤⣴⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠁⠀⢐⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡮⡊
⡟⣤⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣆⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠛⠁⠀⠀⠀⣘⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⢿⢏⠳⣰
⡸⣽⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣗⠆⡀⠉⠛⠛⠛⠿⠿⠛⠛⠛⠉⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⡟⢯⡙⠆⣙⣠⣶⣿⣿
⣴⣃⠏⢿⡹⣟⢿⡿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢯⡃⠄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠱⣞⣿⣿⣿⣿⣿⢿⡻⣍⠓⡉⣤⣶⣾⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣶⣬⣦⣝⣢⠙⠜⠭⡛⢿⡻⣿⢿⡿⡿⣏⠳⠀⣠⣶⣿⣾⣿⣿⣿⣿⣿⣾⣷⣶⣶⣤⣤⣤⣀⡀⠀⠘⡌⢳⡙⢮⠱⢋⠔⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣶⣤⣑⡈⠣⢉⠑⠀⣁⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣆⣀⠀⠀⠈⠀⢁⣠⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
TUX
}

if [ -t 1 ]
then
    if __color_enabled
    then
        trap __quit EXIT
        trap __control_c INT
    fi
    printf "👋 Welcome to your development container...\n" >&2
    if [ "\${SHOW_TUX:-$SHOW_TUX}" = "true" ]
    then
        tux >&2
    elif [ "\${SHOW_TUX_ALT:-$SHOW_TUX_ALT}" = "true" ]
    then
        tux_alt >&2
    else
        printf "🐧 %s 🐧\n" "Happy coding!" >&2
    fi
fi
EOF

chown "$USERNAME:$USERNAME" "/home/$USERNAME/.bash_aliases"

LEVEL='√' $LOGGER "Done! User '$USERNAME' created successfully."

# Set default password for root user to 'docker'
# Only for development purposes; password can be changed at runtime
# DO NOT use in production environments
# Avoid using 'chpasswd' with here-string (e.g. chpasswd <<<"root:docker") as it may not be supported in some shells
if [ "$DEFAULT_ROOT_PASS" = "true" ]; then
    # Extract ID from /etc/os-release to use as default root password (e.g., 'ubuntu', 'debian', etc.)
    prop=ID ID="$({ while IFS= read -r line; do printf '%s\n' "$line"; done < /etc/os-release; } | grep "^$prop=" | cut -d'=' -f2 | tr -d '"')"
    $LOGGER "Setting default root password to '$ID' (for development purposes only)"
    echo "root:${ID:-docker}" | chpasswd
fi
