#!/usr/bin/env bash

# * Description: Create a non-root user and set up bashrc and profile for both the new user and root

# Only check for errors (set -e)
# Don't check for unset variables (set -u) since variables are set in Dockerfile
# Pipepail (set -o pipefail) is not available in sh
set -e

LEVEL='*' $LOGGER "Setting up bashrc and profile for new users and root ..."

# Comment out the bash_aliases sourcing block in /etc/skel/.bashrc
comment_out_bash_aliases() {
    set -u
    local file="$1"
    if [ -f "$file" ]; then
        sed -i -E '/if[[:space:]]+\[[[:space:]]+-f[[:space:]]+~\/\.bash_aliases[[:space:]]*\];?[[:space:]]*then/,/^[[:space:]]*fi[[:space:]]*$/s/^/# /' "$file"
    fi
    set +u
}

# Extract leading comments from a file and remove them from the original
# Usage: extract_leading_comments <file>
# Outputs the leading comments and blank lines to stdout, and removes them from the file
extract_leading_comments() {
    set -u
    local file="$1"
    # Extract lines from the beginning that are comments or blank lines
    sed -n '/^[[:space:]]*#/p; /^[[:space:]]*$/p; /^[[:space:]]*[^#[:space:]]/q' "$file"
    # Remove the leading comments and blank lines from the file
    sed -i '/^[[:space:]]*[^#[:space:]]/,$!d' "$file"
    set +u
}

# Insert content at the beginning of a file
# Usage: insert_at_beginning <file> < <(echo "Content to insert")
# Content is read from stdin (e.g., from a heredoc)
insert_at_beginning() {
    set -u
    local file="$1"
    local tmpfile
    tmpfile="$(mktemp)"
    cat - "$file" > "$tmpfile" && mv "$tmpfile" "$file"
    set +u
}

# Add parse_git_branch function and update PS1 in color_prompt section
# - Find PS1 lines ending with \$ '
#   - Capture the PS1 prefix (PS1=.*) and the trailing \$ ' (represented as \\\$ \x27)
#     - \\\$ - Matches a literal \$ in the file
#     - \x27 - Hexadecimal escape for a single quote (') character
# - Insert $(parse_git_branch) with blue color before the trailing \$ '
# shellcheck disable=SC2016
update_ps1_with_git_branch() {
    set -u
    local file="$1"
    if [ -f "$file" ]; then
        # Insert parse_git_branch function before the color_prompt conditional
        sed -i '/if[[:space:]]*\[[[:space:]]*"\$color_prompt"[[:space:]]*=[[:space:]]*yes[[:space:]]*\];[[:space:]]*then/i\
# Function to display current git branch in prompt\
parse_git_branch() { [ -t 1 ] || git branch --no-color 2> /dev/null | sed -e '"'"'/^[^*]/d'"'"' -e '"'"'s/* \\(.*\\)/ (\\1)/'"'"'; }\
' "$file"
        # Update PS1 lines within the color_prompt conditional to include git branch
        sed -i '/if[[:space:]]*\[[[:space:]]*"\$color_prompt"[[:space:]]*=[[:space:]]*yes[[:space:]]*\];[[:space:]]*then/,/^else$/s/\(PS1=.*\)\(\\\$ \x27\)$/\1\\[\x27${PS1_GIT_BRANCH_COLOR:-$C_BLUE}\x27\\]\$(parse_git_branch)\\[\x27${C_DEFAULT}\x27\\]\2/' "$file"
        # Update PS1 in the else block to include git branch
        sed -i '/^else$/,/^fi$/s/\(PS1=.*\)\(\\\$ \x27\)$/\1\$(parse_git_branch)\2/' "$file"
    fi
    set +u
}

# shellcheck disable=SC2016
party_ps1() {
    set -u
    local file="$1"
    if [ -f "$file" ]; then
        sed -i '/if[[:space:]]*\[[[:space:]]*"\$color_prompt"[[:space:]]*=[[:space:]]*yes[[:space:]]*\];[[:space:]]*then/,/^else$/s/\(PS1=.*\)\\u@\(.*\\\$ \x27\)$/\1\\[\x27${C_BOLD}\x27\\]\\[\x27${PS1_USER_COLOR:-$C_GREEN}\x27\\]\\u\\[\x27${PS1_AT_COLOR:-$C_GREEN}\x27\\]@\\[\x27${PS1_HOSTNAME_COLOR:-$C_GREEN}\x27\\]\2/' "$file"

        # Insert "if [ "$PARTY_PS1" = "true" ]; then" before PS1 lines
        # sed -i '/if[[:space:]]*\[[[:space:]]*"\$color_prompt"[[:space:]]*=[[:space:]]*yes[[:space:]]*\];[[:space:]]*then/,/^else$/s/^\([[:space:]]*\)\(PS1=.*\\u@.*\\\$ \x27\)$/\1if [ "${PARTY_PS1:-false}" = "true" ]; then\n\1    \2\n\1else\n\1    \2\n\1fi/' "$file"
        # Colorize ...
        # sed -i '/if[[:space:]]*\[[[:space:]]*"${PARTY_PS1:-false}"[[:space:]]*=[[:space:]]*"true"[[:space:]]*\];[[:space:]]*then/{n;s/\(PS1=.*\)\\u@\(.*\\\$ \x27\)$/\1\\[\x27${C_BOLD}\x27\\]\\[\x27${PS1_USER_COLOR:-$C_GREEN}\x27\\]\\u\\[\x27${PS1_AT_COLOR:-$C_GREEN}\x27\\]@\\[\x27${PS1_HOSTNAME_COLOR:-$C_GREEN}\x27\\]\2/}' "$file"
    fi
    set +u
}

for f in /etc/skel/.bashrc /root/.bashrc; do
    comment_out_bash_aliases "$f"
    update_ps1_with_git_branch "$f"
    party_ps1 "$f"
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
# Insert C_* color variables and PATH at the beginning of bashrc files (after initial comments)
for bashrc_file in /etc/skel/.bashrc /root/.bashrc; do
    cat << EOF | insert_at_beginning "$bashrc_file"
$(extract_leading_comments "$bashrc_file")

C_ESQ="\\033[" C_DEFAULT="\${C_ESQ}0m" C_RESET="\${C_ESQ}0m" \\
C_BOLD="\${C_ESQ}1m" C_UNDERLINE="\${C_ESQ}4m" C_REVERSE="\${C_ESQ}7m" \\
C_RED="\${C_ESQ}31m" C_GREEN="\${C_ESQ}32m" C_YELLOW="\${C_ESQ}33m" \\
C_BLUE="\${C_ESQ}34m" C_MAGENTA="\${C_ESQ}35m" C_CYAN="\${C_ESQ}36m" \\
C_RED_BOLD="\${C_ESQ}1;31m" C_GREEN_BOLD="\${C_ESQ}1;32m" \\
C_YELLOW_BOLD="\${C_ESQ}1;33m" C_BLUE_BOLD="\${C_ESQ}1;34m" \\
C_MAGENTA_BOLD="\${C_ESQ}1;35m" C_CYAN_BOLD="\${C_ESQ}1;36m" \\
C_BRIGHT_RED="\${C_ESQ}91m" C_BRIGHT_GREEN="\${C_ESQ}92m" \\
C_BRIGHT_YELLOW="\${C_ESQ}93m" C_BRIGHT_BLUE="\${C_ESQ}94m" \\
C_BRIGHT_MAGENTA="\${C_ESQ}95m" C_BRIGHT_CYAN="\${C_ESQ}96m" \\
C_BRIGHT_RED_BOLD="\${C_ESQ}1;91m" C_BRIGHT_GREEN_BOLD="\${C_ESQ}1;92m" \\
C_BRIGHT_YELLOW_BOLD="\${C_ESQ}1;93m" C_BRIGHT_BLUE_BOLD="\${C_ESQ}1;94m" \\
C_BRIGHT_MAGENTA_BOLD="\${C_ESQ}1;95m" C_BRIGHT_CYAN_BOLD="\${C_ESQ}1;96m" \\
C_WHITE="\${C_ESQ}97m" C_WHITE_BOLD="\${C_ESQ}1;97m" \\
C_BLACK="\${C_ESQ}30m" C_BLACK_BOLD="\${C_ESQ}1;30m"

ps1_colors() {
    for var_def in \\
        "PS1_USER_COLOR:38;5;198" \\
        "PS1_AT_COLOR:38;5;214" \\
        "PS1_ERROR_COLOR:38;5;161" \\
        "PS1_SUCCESS_COLOR:38;5;047" \\
        "PS1_GIT_BRANCH_COLOR:38;5;025" \\
        "PS1_HOSTNAME_COLOR:38;5;118"
    do
        local var_name default_val val varname_to_expand
        var_name="\${var_def%%:*}"
        val="\${!var_name}"

        # If PARTY_PS1 is true and variable is empty, use default
        if [ "\$PARTY_PS1" = "true" ] && [ -z "\$val" ]; then
            default_val="\${var_def#*:}"
            val="\$default_val"
        fi

        # Skip if no value
        [ -n "\$val" ] || continue

        # Expand variable references like \$C_GREEN
        if [[ "\$val" == \\\$* ]]; then
            varname_to_expand="\${val#\\\$}"
            val="\${!varname_to_expand}"
        fi

        # Add C_ESQ if not present
        [[ "\$val" != "\$C_ESQ"* ]] && val="\${C_ESQ}\${val}"

        # Ensure ends with 'm'
        val="\${val%m}m"
        printf -v "\$var_name" "%s" "\$val"
    done
}
ps1_colors

EOF
done

cat << EOF | tee -a /etc/skel/.bashrc /root/.bashrc > /dev/null

PATH="\$($FIXPATH)"

showcolors() {
    for var in PS1_USER_COLOR PS1_AT_COLOR PS1_ERROR_COLOR PS1_SUCCESS_COLOR PS1_GIT_BRANCH_COLOR PS1_HOSTNAME_COLOR
    do
        val="\${!var}"
        if [[ "\$val" == \\\$* ]]; then
            varname_to_expand="\${val#\\\$}"
            val="\${!varname_to_expand}"
        fi
        printf "\${val}%s=%s\${C_DEFAULT}\n" "\$var" "\$val"
    done
}

colors() {
    for bg in {0..255}; do
        for fg in {0..255}; do
            echo -e "\\e[38;5;\${fg}m\\e[48;5;\${bg}m"'\\\\e[38;5;'"\$fg"m'\\\\e[48;5;'"\$bg"m'\\e[0m'
        done
    done
    for fg in {0..255}; do
        echo -e "\\e[38;5;\${fg}m"'\\\\e[38;5;'"\$fg"m'\\e[0m'
    done
}

alias unixtime='date +%s'
alias utctime='date -u +"%Y-%m-%dT%H:%M:%SZ"'
alias now='date "+%A, %B %d, %Y %I:%M:%S %p %Z"'

alias ll='ls -alF'

if [ -x /usr/bin/dircolors ]; then
    alias grep='grep --color=auto'
    alias egrep='egrep --color=auto'
    alias fgrep='fgrep --color=auto'
fi

# Handle exit
__quit() { printf "🤖 %s 🤖\n" "Klaatu barada nikto" >&2; }

# Handle cancelled operations (e.g., Ctrl+C)
__control_c() {
    local err="\$?"
    local color="\${PS1_ERROR_COLOR:-\$C_RED}"
    echo -en "\n⛔ \${C_BOLD}\${color}✗\${C_DEFAULT} \${color}(\$err)\${C_DEFAULT} \${C_BOLD}\${color}Operation cancelled by user\${C_DEFAULT} ⛔" >&2
    return \$err;
}

# Determine if color is supported
__color_enabled() {
    local color_prompt=
    case "\$TERM" in
        xterm-color|*-256color) color_prompt=yes ;;
    esac
    [ "\$color_prompt" = yes ] \\
        && [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null \\
            && return \\
            || return \$?
}

__exit_status() {
    local icon_success="✔"
    local icon_failure="✘"
    local icon_debian="꩜"
    local error_color="\${PS1_ERROR_COLOR:-\$C_RED}"
    local success_color="\${PS1_SUCCESS_COLOR:-\$C_GREEN}"
    if __color_enabled
    then
        if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null
        then
            if [ "\$1" -eq 0 ]
            then
                echo -en "\\001\${success_color}\\002\${icon_debian}\\001\${C_RESET}\\002 "
            else
                echo -en "\\001\${error_color}\\002\${icon_debian} (\${1})\\001\${C_RESET}\\002 "
            fi
        fi
    else
        if [ "\$1" -eq 0 ]
        then
            echo -en "\${icon_success} "
        else
            echo -en "\${icon_failure} (\${1}) "
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
    arch="\$(dpkg --print-architecture)"
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
