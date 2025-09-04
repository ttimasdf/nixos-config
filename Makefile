# Makefile for managing NixOS system rebuilds.

# The suffix for the NixOS boot label.
# This can be overridden from the command line.
# Example: make rebuild LABEL_SUFFIX="testing"
LABEL_SUFFIX ?= ""

# Setting the default goal allows running 'make' without specifying a target.
.DEFAULT_GOAL := help

# Using .PHONY declares that these targets do not produce files.
# This prevents conflicts with files of the same name and improves performance.
.PHONY: rebuild sync run-nixos-rebuild update-lock-files help

# The main target for rebuilding the system.
# It depends on a chain of other targets, which will be executed in order.
rebuild: sync run-nixos-rebuild update-lock-files
	@echo "✅ System rebuild completed successfully!"

# Target to sync the local NixOS configuration with the git remote.
sync:
	@echo "--> Resetting NixOS configuration repository..."
	sudo git -C /etc/nixos reset --hard && \
	@echo "--> Pulling latest NixOS configuration..."
	sudo git -C /etc/nixos pull --rebase

# Target to execute the nixos-rebuild command.
run-nixos-rebuild:
	@echo "--> Starting NixOS rebuild with label suffix: '$(LABEL_SUFFIX)'..."
	sudo env "https_proxy=$(https_proxy)" NIXOS_LABEL_SUFFIX="$(LABEL_SUFFIX)" nixos-rebuild switch --impure

# Target to copy the lock files to the current directory.
update-lock-files:
	@echo "--> Updating lock files in current directory..."
	cp /etc/nixos/*.lock .

# A help target to explain how to use the Makefile.
help:
	@echo "Usage: make [TARGET]"
	@echo ""
	@echo "Targets:"
	@echo "  rebuild            Runs the full sequence: sync, run-nixos-rebuild, and update-lock-files."
	@echo "  sync               Resets and pulls the latest NixOS configuration from git."
	@echo "  run-nixos-rebuild  Builds and switches to the new NixOS configuration."
	@echo "  update-lock-files  Copies the NixOS lock files to the current directory."
	@echo "  help               Shows this help message."
	@echo ""
	@echo "Options:"
	@echo "  LABEL_SUFFIX       Set a suffix for the boot entry label. Example: make LABEL_SUFFIX=\"-unstable\""

