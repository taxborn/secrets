let
  hosts = [
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
in
{
  "tailscale/auth.age".publicKeys = keys;
  "tailscale/caddyAuth.age".publicKeys = keys;

  "forgejo/postgres.age".publicKeys = keys;
  "forgejo/act-runner.age".publicKeys = keys;

  "resend.age".publicKeys = keys;
  "copyparty.age".publicKeys = keys;
  "pds.age".publicKeys = keys;
  "lastfm.age".publicKeys = keys;
}
