#!/usr/bin/env bash
# @file tmc_prompt.sh
# Functions to build a Bash TMC CLI prompt
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

[[ -n $DEBUG ]] && set -x

# initialize defaults
_tmc_init() {
    # shellcheck disable=SC2155
    export TMC_PROMPT_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    export TMC_CONFIG_DIR="$HOME/.vmware-cna-saas"
    export TMC_CONTEXT=''
    export TMC_PROMPT=''
    export TMC_PROMPT_FORMAT='⏣ #CONTEXT# #DEFAULTS#'
    export TMC_PROMPT_DEFAULTS_FORMAT='(#MGMT_CLUSTER# ⇢ #PROVISIONER#)'
    export TMC_PROMPT_ENABLED='on'
    export TMC_PROMPT_DEFAULTS_ENABLED='on'
}
[[ -z "$TMC_PROMPT_SCRIPT_DIR" || "$1" == 'init' ]] && _tmc_init

# fetch the current context
_tmc_fetch_context() {
    # Current context direct from tmc command...
    # !! Need to parse yaml, e.g. tmc system context current | yq e '.full_name.name' -
    grep name "$TMC_CONFIG_DIR/current-context" 2>/dev/null | \
        cut -d':' -f2 | \
        sed -e 's/^[ ]*//'
}

# parse out the value for a given key from the current context
_tmc_context_value_for_key() {
    local key="$1"
    tmc system context get "$TMC_CONTEXT" |\
        grep "$key" |\
        cut -d':' -f2 |\
        sed -e 's/^[ ]*//'
}

# build the string used as a TMC
_tmc_build_prompt() {
    local default mgmtCluster provisioner
    # shellcheck disable=SC2155
    export TMC_CONTEXT="$(_tmc_fetch_context)"
    if [ -n "$TMC_CONTEXT" ]; then
        prompt="${TMC_PROMPT_FORMAT//#CONTEXT#/$TMC_CONTEXT}"
        if [[ "$TMC_PROMPT_DEFAULTS_ENABLED" == 'on' ]]; then
            mgmtCluster=$(_tmc_context_value_for_key MANAGEMENT_CLUSTER_NAME)
            provisioner=$(_tmc_context_value_for_key PROVISIONER_NAME)
            default="${TMC_PROMPT_DEFAULTS_FORMAT//#MGMT_CLUSTER#/$mgmtCluster}"
            default="${default//#PROVISIONER#/$provisioner}"
            prompt="${prompt//#DEFAULTS#/$default}"
        else
            prompt="${prompt//#DEFAULTS#/}"
        fi
        export TMC_PROMPT="$prompt"
        [[ "$TMC_PROMPT_ENABLED" == 'on' ]] && echo "$TMC_PROMPT"
    else
        return 1
    fi
}

# toggle the visibility of the defaults in the TMC prompt, `tmc_defaults on|off`
tmc_defaults() { export TMC_PROMPT_DEFAULTS_ENABLED="$1"; }

# show or toggle the visibility of the TMC ptompt, `tmc_prompt on|off`
# shellcheck disable=SC2120
tmc_prompt() { 
    local toggle="${1:-}"
    if [[ -z "$toggle" ]]; then 
        _tmc_build_prompt
    else
        export TMC_PROMPT_ENABLED="$toggle"; 
    fi
}

# configure TMC prompt for the given prompt framework or for the generic PS1
tmc_configure_prompt() {
    local framework="$1"
    local configFile config
    if [ -z "$framework" ]; then
        echo "The following prompts are supported:"
        echo "    1 ... starship"
        echo "    2 ... generic Bash prompt"
        until [[ "$REPLY" =~ ^-?[0-9]+$ && "$REPLY" -gt 0 && "$REPLY" -lt 3 ]]; do
            # shellcheck disable=SC2162
            read -p "✋ Select the prompt type you'd like me to configure [1|2] "  -r -n 1
            echo
        done
        echo
        framework="$REPLY"
    fi
    case $framework in
        1|starship)
            configFile=~/.config/starship.toml
            # shellcheck disable=SC1073
            config=$(cat <<END_OF_STARSHIP_CONFIG
[custom.tmc]
description = "Display the current tmc context"
command = ". $TMC_PROMPT_SCRIPT_DIR/tmc_prompt.sh; tmc_prompt"
when= "command -v tmc 1>/dev/null 2>&1"
disabled = false
END_OF_STARSHIP_CONFIG
            )
            echo -e "Copy the following to $configFile:\n"
            echo "$config"
            echo
            read -p "✋ Shall I append this to $configFile for you? [y/N] " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] && {
                echo "$config" >> "$configFile"
                echo "✅ Added the TMC custom prompt to your starship configuration"
            }
            ;;
        powerline-go)
            ## TODO
            ;;
        2|none)
            read -p "✋ Shall I pre-pend the TMC prompt to your existing \$PROMPT_COMMAND? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                PROMPT_COMMAND="tmc_prompt; ${PROMPT_COMMAND:-}"
                echo "✅ PS1 now includes the TMC prompt. Use 'tmc_prompt [on|off]' to toggle display of the prompt"
            else
                echo "👍 Ok, you can add 'tmc_prompt' to \$PS1."
            fi
            ;;
        *)
            echo "🤔 I don't recognize a framework called $framework"
            ;;
    esac
}

# Return prompt if this script is called directly
[ "${BASH_SOURCE[0]}" -ef "$0" ] && tmc_prompt