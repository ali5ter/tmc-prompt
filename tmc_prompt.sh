#!/usr/bin/env bash
# @file tmc_prompt.sh
# Functions to build a TMC CLI prompt
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

# initialize defaults
_tmc_init() {
    # shellcheck disable=SC2155
    export TMC_PROMPT_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    export TMC_CONFIG_DIR="$HOME/.vmware-cna-saas"
    export TMC_CONTEXT=''
    export TMC_PROMPT=''
    export TMC_PROMPT_FORMAT='#CONTEXT# #DEFAULTS#'
    export TMC_PROMPT_DEFAULTS_FORMAT='(#MGMT_CLUSTER# ⇢ #PROVISIONER#)'
    export TMC_PROMPT_ENABLED='off'
    export TMC_PROMPT_DEFAULTS_ENABLED='on'
}
[[ -z "$TMC_PROMPT_SCRIPT_DIR" ]] && _tmc_init

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

# build the string used as a TMC prompt
tmc_build_prompt() {
    local prompt default mgmtCluster provisioner
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
command = "source $TMC_PROMPT_SCRIPT_DIR/tmc_prompt.sh && tmc_build_prompt"
when= "command -v tmc 1>/dev/null 2>&1"
symbol='⏣ '
disabled = false
END_OF_STARSHIP_CONFIG
            )
            echo "$config" >> "$configFile"
            echo "✅ Added custom prompt to your starship configuration at $configFile"
            ;;
        none)
            _tmc_bash_prompt() {
                [[ "$TMC_PROMPT_ENABLED" == 'on' ]] && tmc_build_prompt
            }
            tmc_prompt() { export TMC_PROMPT_ENABLED="$1"; }
            PROMPT_COMMAND="_tmc_bash_prompt; ${PROMPT_COMMAND:-}"
            echo "✅ Use 'tmc_prompt [on|off]' to toggle display of the prompt"
            ;;
        *)
            echo "🤔 I don't recognize a framework called $framework"
            ;;
    esac
}