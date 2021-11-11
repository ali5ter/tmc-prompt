#!/usr/bin/env bash
# @file test_generic.sh
# Stand up tmc-prompt for $PS1 in Ubuntu distro for testing
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

# Update and install OS tools needed
apt upgrade && apt update
apt install -y curl git

# Download TMC cli command
curl -fsSL https://tmc-cli.s3-us-west-2.amazonaws.com/tmc/latest/linux/x64/tmc -o tmc
chmod 755 tmc
mv tmc /usr/local/bin/
echo "source <(tmc completion bash)" >> ~/.bashrc

# Download and configure tmc-prompt
git clone https://github.com/ali5ter/tmc-prompt.git
echo "source /tmc-prompt/tmc_prompt.sh" >> ~/.bashrc
# shellcheck disable=1091
source /tmc-prompt/tmc_prompt.sh
tmc_configure_prompt none

# Create fresh TMC context
export TMC_API_TOKEN="$CSP_API_TOKEN" && unset CSP_API_TOKEN
tmc login --stg-unstable --name test-context --no-configure
tmc configure -m "attached" -p "attached"