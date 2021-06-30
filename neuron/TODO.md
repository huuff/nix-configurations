* Make sure rsync starts after the dir is cloned
* Maybe there is some way to ensure the files are created on first boot?
* Security is probably an issue, which user are all these systemd units being started from?
* If this is to be distributed, shouldn't I put all imports in neuron.nix instead of in flake.nix?
* I'm sure auto-rsync shouldn't be needed, get nginx to serve it from the home directory someway
