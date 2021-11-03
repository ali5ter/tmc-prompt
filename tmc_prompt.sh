#!/usr/bin/env bash
# @file tmc_prompt.sh
# Functions to build a TMC CLI prompt
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

TMC_CONFIG_DIR="$HOME/.vmware-cna-saas"
# Current context direct from tmc command...
# !! Need to parse yaml, e.g. tmc system context current | yq e '.full_name.name' -
# shellcheck disable=SC2086
# shellcheck disable=SC2155
TMC_CONTEXT="$(grep name $TMC_CONFIG_DIR/current-context 2>/dev/null | cut -d':' -f2 | sed -e 's/^[ ]*//')"
TMC_PROMPT=''
TMC_PROMPT_FORMAT='#CONTEXT# #DEFAULTS#'
TMC_PROMPT_DEFAULTS_FORMAT='(#MGMT_CLUSTER# ⇢ #PROVISIONER#)'
TMC_PROMPT_ENABLED='off'
TMC_PROMPT_DEFAULTS_ENABLED='on'

# parse out the value for a given key from the current context
_tmc_context_value_for_key() {
    local key="$1"
    tmc system context get "$TMC_CONTEXT" |\
        grep "$key" |\
        cut -d':' -f2 |\
        sed -e 's/^[ ]*//'
}

# build the string used as a TMC prompt
tmc_build_prompt() {
    local prompt default mgmtCluster provisioner
    if [ -n "$TMC_CONTEXT" ]; then
        prompt="${TMC_PROMPT_FORMAT//#CONTEXT#/$TMC_CONTEXT}"
        [[ "$TMC_PROMPT_DEFAULTS_ENABLED" == 'on' ]] && {
            mgmtCluster=$(_tmc_context_value_for_key MANAGEMENT_CLUSTER_NAME)
            provisioner=$(_tmc_context_value_for_key PROVISIONER_NAME)
            default="${TMC_PROMPT_DEFAULTS_FORMAT//#MGMT_CLUSTER#/$mgmtCluster}"
            default="${default//#PROVISIONER#/$provisioner}"
            prompt="${prompt//#DEFAULTS#/$default}"
        }
        export TMC_PROMPT="$prompt"
        echo "$TMC_PROMPT"
    else
        return 1
    fi
}

# toggle showing the defaults in the TMC prompt, `tmc_defaults [on|off]`
tmc_defaults() { export TMC_PROMPT_DEFAULTS_ENABLED="$1"; }

# configure TMC prompt for the given prompt framework or for the generic PS1
tmc_configure_prompt() {
    local framework="$1"
    local configFile config
    if [ -z "$framework" ]; then
        # shellcheck disable=SC2162
        read -p "✋ What framework are you using for your prompt? [starship|none] " framework
    fi
    case $framework in
        starship)
            configFile=~/.config/starship.toml
            # shellcheck disable=SC1073
            config=$(cat <<END_OF_STARSHIP_CONFIG
[custom.tmc]
description = "Display the current tmc context"
command = "source $DIR/tmc_prompt.sh && tmc_build_prompt"
when= "command -v tmc 1>/dev/null 2>&1"
symbol='⏣ '
disabled = false
END_OF_STARSHIP_CONFIG
            )
            echo "$config" >> "$configFile"
            echo "ℹ️ Added custom prompt to your starship configuration at $configFile"
            ;;
        none)
            _tmc_bash_prompt() {
                [[ "$TMC_PROMPT_ENABLED" == 'on' ]] && tmc_build_prompt
            }
            tmc_prompt() { export TMC_PROMPT_ENABLED="$1"; }
            PROMPT_COMMAND="_tmc_bash_prompt; ${PROMPT_COMMAND:-}"
            echo "ℹ️ Use 'tmc_prompt [on|off]' to toggle display of the prompt"
            ;;
        *)
            echo "I don't recognize a framework called $framework"
            ;;
    esac
}