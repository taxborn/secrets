let
  hosts = [
    "argon"
    "carbon"
    "helium-01"
    "tungsten"
    "uranium"
  ];
  users = [
    "taxborn_yubikey"
  ];
  systemKeys = builtins.map (host: builtins.readFile ./publicKeys/root_${host}.pub) hosts;
  userKeys = builtins.map (user: builtins.readFile ./publicKeys/${user}.pub) users;
  keys = systemKeys ++ userKeys;

  hostKey = host: [ (builtins.readFile ./publicKeys/root_${host}.pub) ] ++ userKeys;
in
{
  "tailscale/auth.age".publicKeys = keys;
  "tailscale/caddyAuth.age".publicKeys = keys;

  "forgejo/postgres.age".publicKeys = keys;
  "forgejo/act-runner.age".publicKeys = keys;
  "forgejo/signing_key.age".publicKeys = keys;

  "resend.age".publicKeys = keys;
  "grafana.age".publicKeys = keys;
  "pds.age".publicKeys = keys;
  "lastfm.age".publicKeys = keys;
  "hash-haus.age".publicKeys = keys;

  "borg/argon/passphrase.age".publicKeys = hostKey "argon";
  "borg/argon/ssh_key.age".publicKeys = hostKey "argon";

  "borg/uranium/passphrase.age".publicKeys = hostKey "uranium";
  "borg/uranium/ssh_key.age".publicKeys = hostKey "uranium";

  "borg/tungsten/passphrase.age".publicKeys = hostKey "tungsten";
  "borg/tungsten/ssh_key.age".publicKeys = hostKey "tungsten";

  "borg/carbon/passphrase.age".publicKeys = hostKey "carbon";
  "borg/carbon/ssh_key.age".publicKeys = hostKey "carbon";

  "borg/helium-01/passphrase.age".publicKeys = hostKey "helium-01";
  "borg/helium-01/ssh_key.age".publicKeys = hostKey "helium-01";
}
