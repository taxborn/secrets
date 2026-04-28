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
}
