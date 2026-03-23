#!/bin/sh

# Only check for errors (set -e)
# Don't check for unset variables (set -u) since variables are set in Dockerfile
# Pipepail (set -o pipefail) is not available in sh
set -e

LEVEL='ƒ' $LOGGER "Installing base utilities and dependencies..."

# shellcheck disable=SC1091
. /helpers/install-helper.sh

PACKAGES_TO_INSTALL="${PACKAGES_TO_INSTALL% } $(
    cat << EOF
openssh-client
EOF
)"

# TODO: Consider creating a a PRE_COMMIT_PIPX_ONLY variable to only install pre-commit via pipx (i.e. not with apt-get package)
# This could potentially save space, since system pre-commit is uninstalled in the devtools-utils script if pipx is available
if [ "${PRE_COMMIT_ENABLED:-false}" = "true" ] && ! "$PIPX" > /dev/null 2>&1; then
    PACKAGES_TO_INSTALL="${PACKAGES_TO_INSTALL% } $(
        cat << EOF
pre-commit
EOF
    )"
fi

update_and_install "${PACKAGES_TO_INSTALL# }"

if [ "${UNIMATRIX_ENABLED:-true}" = "true" ]; then
    LEVEL='*' $LOGGER "Installing unimatrix..."
    # curl -fsSL https://raw.githubusercontent.com/will8211/unimatrix/master/unimatrix.py -o /tmp/unimatrix.py \
    wget -qO /tmp/unimatrix.py https://raw.githubusercontent.com/will8211/unimatrix/master/unimatrix.py \
        && install /tmp/unimatrix.py /usr/local/bin/unimatrix
fi

LEVEL='√' $LOGGER "Done! Base utilities installation complete."

LEVEL='ƒ' $LOGGER "Setting up bash aliases..."

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

COWFILES="\${COWFILES:-default three-eyes apt moose tux cock bunny bud-frogs}"

cowfile() { echo \${COWFILES:-default} | xargs -n 1 | shuf -n 1; }
aliases() { echo -e "\${C_ESQ}2m\$(alias)\${C_RESET}"; }
aliascow() {
    local com="\${1:-/usr/games/cowthink}"
    if [ -n "\${com-}" ]
    then
        shift
        local lines=\$(alias | wc -l) count=1 length= suffix= opts=()
        while read -r line; do
            [ \$(echo "\$line" | wc -L) -lt "\${ALIAS_COW_LENGTH:-72}" ] || { suffix="\n"; break; }
        done <<<\$(alias)
        [ -z "\$suffix" ] && opts+=("-n") || opts+=("-W\${ALIAS_COW_LENGTH:-72}")
        set - "\${opts[@]}"
        echo -en "\${C_ESQ}2m"
        alias | while read -r line; do
            echo -e "\${line}\${suffix}"
        done | "\$com" -f "\$(cowfile)" \$@
        echo -en "\${C_RESET}"
    fi
}
showmatrix() { unimatrix -af -l 'k' -s "\${2:-98}" -t "\${1:-2}" -i; }

if [ -t 1 ]
then
    if type unimatrix >/dev/null 2>&1 && [ "\${SHOW_MATRIX:-false}" = "true" ]
    then
        showmatrix "\${MATRIX_TIME-}" "\${MATRIX_SPEED-}"
    fi
    if __color_enabled
    then
        trap __quit EXIT
        trap __control_c INT
    fi
    if [ "\${SHOW_TUX:-false}" = "true" ]
    then
        tux >&2
    elif [ "\${SHOW_TUX_ALT:-false}" = "true" ]
    then
        tux_alt >&2
    fi
    if [ "\${SHOW_FORTUNECOW:-false}" = "true" ]
    then
        if type /usr/games/fortune >/dev/null 2>&1 \\
            && type /usr/games/cowsay >/dev/null 2>&1
        then
            echo -en "\${C_ESQ}2m" >&2
            /usr/games/fortune | /usr/games/cowsay -f "\$(cowfile)" >&2
            echo -en "\${C_RESET}" >&2
        fi
    fi
    if [ "\${SHOW_ALIASES:-false}" = "true" ]
    then
        if type /usr/games/cowthink >/dev/null 2>&1
        then
            aliascow /usr/games/cowthink >&2
        else
            aliases >&2
        fi
    fi
fi
EOF

chown "$USERNAME:$USERNAME" "/home/$USERNAME/.bash_aliases"

LEVEL='√' $LOGGER "Bash aliases setup complete."
