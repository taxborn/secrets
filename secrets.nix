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

  hostKeys =
    hostList:
    (builtins.map (host: builtins.readFile ./publicKeys/root_${host}.pub) hostList) ++ userKeys;
in
{
  # tailscale auth keys are consumed on every host
  "tailscale/auth.age".publicKeys = keys;
  "tailscale/caddyAuth.age".publicKeys = keys;

  # forgejo server only runs on carbon
  "forgejo/postgres.age".publicKeys = hostKeys [ "carbon" ];
  "forgejo/signing_key.age".publicKeys = hostKeys [ "carbon" ];
  "resend.age".publicKeys = hostKeys [ "carbon" ];

  # forgejo-runner runs on carbon, argon, and helium-01
  "forgejo/act-runner.age".publicKeys = hostKeys [
    "carbon"
    "argon"
    "helium-01"
  ];

  # single-host services
  "copyparty.age".publicKeys = hostKeys [ "helium-01" ];
  "grafana.age".publicKeys = hostKeys [ "helium-01" ];
  "pds.age".publicKeys = hostKeys [ "carbon" ];
  "hash-haus.age".publicKeys = hostKeys [ "argon" ];

  # lastfm is consumed on carbon, uranium, and tungsten
  "lastfm.age".publicKeys = hostKeys [
    "carbon"
    "uranium"
    "tungsten"
  ];

  "borg/argon/passphrase.age".publicKeys = hostKeys [ "argon" ];
  "borg/argon/ssh_key.age".publicKeys = hostKeys [ "argon" ];

  "borg/uranium/passphrase.age".publicKeys = hostKeys [ "uranium" ];
  "borg/uranium/ssh_key.age".publicKeys = hostKeys [ "uranium" ];

  "borg/tungsten/passphrase.age".publicKeys = hostKeys [ "tungsten" ];
  "borg/tungsten/ssh_key.age".publicKeys = hostKeys [ "tungsten" ];

  "borg/carbon/passphrase.age".publicKeys = hostKeys [ "carbon" ];
  "borg/carbon/ssh_key.age".publicKeys = hostKeys [ "carbon" ];

  "borg/helium-01/passphrase.age".publicKeys = hostKeys [ "helium-01" ];
  "borg/helium-01/ssh_key.age".publicKeys = hostKeys [ "helium-01" ];
}
