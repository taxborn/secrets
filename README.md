# secrets

agenix-encrypted secrets for the nix-infra configuration.

## how it works

[agenix](https://github.com/ryantm/agenix) encrypts secrets with age using SSH public keys. each secret is encrypted for specific hosts and users, defined in `secrets.nix`. only machines with the corresponding private key can decrypt their secrets at activation time.

### key participants

- **host keys** (`publicKeys/root_<host>.pub`) - the SSH host key for each NixOS machine. these are the keys in `/etc/ssh/ssh_host_ed25519_key.pub` on each host.
- **user keys** (`publicKeys/taxborn_yubikey.pub`) - your personal key (for editing secrets locally).

`secrets.nix` combines all keys and assigns them to each secret file:

```nix
let
  hosts = [ "carbon" "helium-01" "tungsten" "uranium" ];
  users = [ "taxborn_yubikey" ];
  systemKeys = builtins.map (host: builtins.readFile ./publicKeys/root_${host}.pub) hosts;
  userKeys = builtins.map (user: builtins.readFile ./publicKeys/${user}.pub) users;
  keys = systemKeys ++ userKeys;
in
{
  "tailscale/auth.age".publicKeys = keys;
  "forgejo/postgres.age".publicKeys = keys;
  # ...
}
```

## current secrets

| secret | used by | purpose |
|---|---|---|
| `tailscale/auth.age` | all hosts | tailscale auth key |
| `tailscale/caddyAuth.age` | carbon | caddy tailscale auth |
| `forgejo/postgres.age` | carbon | forgejo database password |
| `forgejo/act-runner.age` | carbon | forgejo CI runner token |
| `resend.age` | carbon | resend API key |
| `grafana.age` | helium-01 | grafana admin password |
| `pds.age` | carbon | bluesky PDS config |
| `lastfm.age` | carbon | last.fm API key |

## creating a new secret

1. add the secret entry to `secrets.nix`:

```nix
{
  # ... existing secrets ...
  "my-service.age".publicKeys = keys;
}
```

2. create the encrypted secret file:

```bash
cd /path/to/secrets
agenix -e my-service.age
```

this opens your `$EDITOR` — paste the secret value, save, and close. agenix encrypts it with all the public keys listed in `secrets.nix`.

3. if the secret should only be available on specific hosts, use a subset of keys:

```nix
let
  carbonKey = builtins.readFile ./publicKeys/root_carbon.pub;
in
{
  "carbon-only.age".publicKeys = [ carbonKey ] ++ userKeys;
}
```

4. reference the secret in the host's `secrets.nix`:

```nix
# hosts/<host>/secrets.nix
{ self, ... }:
{
  age.secrets = {
    myServiceSecret = {
      file = "${self.inputs.secrets}/my-service.age";
      # optional: set owner/group/mode
      # owner = "my-service";
      # group = "my-service";
      # mode = "0400";
    };
  };
}
```

5. use the decrypted secret path in your service module:

```nix
config.age.secrets.myServiceSecret.path
```

this resolves to something like `/run/agenix/myServiceSecret` at runtime.

6. commit both repos (secrets and nixcfg), then rebuild.

## re-keying secrets

if you add a new host or rotate a key, re-encrypt all secrets so the new key can decrypt them:

```bash
cd /path/to/secrets

# update the public key file in publicKeys/ first, then:
agenix -r
```

this re-encrypts every secret listed in `secrets.nix` with the current set of public keys.

## provisioning a new host

### 1. generate the host key

on the new machine (or during install), grab the SSH host public key:

```bash
cat /etc/ssh/ssh_host_ed25519_key.pub
```

if the machine doesn't have one yet:

```bash
ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
cat /etc/ssh/ssh_host_ed25519_key.pub
```

### 2. add the host key to secrets

```bash
# copy the public key into the secrets repo
cp /etc/ssh/ssh_host_ed25519_key.pub publicKeys/root_<hostname>.pub

# add the hostname to the hosts list in secrets.nix
```

edit `secrets.nix` and add the hostname to the `hosts` list:

```nix
hosts = [
  "carbon"
  "helium-01"
  "tungsten"
  "uranium"
  "new-host"  # add here
];
```

### 3. re-key all secrets

```bash
agenix -r
```

this re-encrypts every secret so the new host can decrypt them. commit and push the secrets repo.

### 4. create the host configuration in nixcfg

```bash
mkdir -p hosts/<hostname>
```

create the following files:

**`hosts/<hostname>/default.nix`** - NixOS system config:

```nix
{ self, ... }:
{
  imports = [
    ./home.nix
    ./secrets.nix
    self.diskoConfigurations.<disko-config>  # or define a new one
    self.nixosModules.locale-en-us
  ];

  networking.hostName = "<hostname>";
  time.timeZone = "America/Chicago";
  system.stateVersion = "25.11";

  myNixOS = {
    base.enable = true;
    programs.nix.enable = true;
    # enable what you need:
    # programs.systemd-boot.enable = true;
    # services.tailscale = { enable = true; operator = "taxborn"; };
  };

  myHardware = {
    # intel.cpu.enable = true;
    # profiles.ssd.enable = true;
  };

  myUsers.taxborn = {
    enable = true;
    password = "<hashed-password>";  # mkpasswd -m yescrypt
  };

  boot.initrd.availableKernelModules = [
    # check `lspci` and `lsmod` on the target machine
  ];
}
```

**`hosts/<hostname>/home.nix`** - home-manager config:

```nix
{ self, ... }:
{
  home-manager.users.taxborn = {
    imports = [
      # use self.homeModules.taxborn for desktop hosts
      # use self.homeModules.default for servers
      self.homeModules.default
    ];

    config = {
      home = {
        username = "taxborn";
        homeDirectory = "/home/taxborn";
        stateVersion = "25.11";
      };

      programs = {
        home-manager.enable = true;
        fish.enable = true;
      };

      myHome.taxborn.programs = {
        git.enable = true;
        gpg.enable = true;
        tmux.enable = true;
        yubikey.enable = true;
      };
    };
  };
}
```

**`hosts/<hostname>/secrets.nix`** - agenix secret declarations:

```nix
{ self, ... }:
{
  age.secrets = {
    tailscaleAuthKey.file = "${self.inputs.secrets}/tailscale/auth.age";
    # add other secrets this host needs
  };
}
```

### 5. create a disko configuration (if needed)

add a disk layout under `modules/disko/`. look at existing configs for reference:

- `luks-btrfs-uranium/` and `luks-btrfs-tungsten/` for LUKS-encrypted btrfs (desktops)
- `btrfs-carbon/` and `btrfs-helium-01/` for plain btrfs (servers)

### 6. register the host in the flake

edit `modules/flake/nixos.nix` and add the hostname to the `genAttrs` list:

```nix
inputs.nixpkgs.lib.genAttrs
  [
    "carbon"
    "helium-01"
    "tungsten"
    "uranium"
    "new-host"  # add here
  ]
```

### 7. build and deploy

```bash
# first build (from a machine that can reach the target):
just deploy <hostname>

# or if installing fresh with disko:
nix run github:nix-community/disko -- --mode disko --flake .#<hostname>
nixos-install --flake .#<hostname>
```
