#!/usr/bin/env bash
# @file test_starship.sh
# Stand up tmc-prompt for Starship in Ubuntu distro for testing
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

# Update and install OS tools needed
apt upgrade && apt update
apt install -y curl git
	
# Install Starship
# @ref https://starship.rs/guide/
curl -fsSL https://starship.rs/install.sh -o install.sh
bash install.sh -y
echo "eval \"\$(starship init bash)\"" >> ~/.bashrc
rm install.sh
mkdir -p ~/.config
cat > ~/.config/starship.toml <<'END_OF_STARSHIP_CONFIG'
format = "${custom.tmc}$all"

[kubernetes]
disabled = false

END_OF_STARSHIP_CONFIG

# Download TMC cli command
curl -fsSL https://tmc-cli.s3-us-west-2.amazonaws.com/tmc/latest/linux/x64/tmc -o tmc
chmod 755 tmc
mv tmc /usr/local/bin/
echo "source <(tmc completion bash)" >> ~/.bashrc

# Configure tmc-prompt
# shellcheck disable=1091
source /tmc_prompt.sh
tmc_configure_prompt starship
echo "source /tmc_prompt.sh" >> ~/.bashrc

# Create fresh TMC context
export TMC_API_TOKEN="$CSP_API_TOKEN" && unset CSP_API_TOKEN
tmc login --stg-unstable --name test-context --no-configure 
tmc configure -m "attached" -p "attached"