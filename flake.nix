{
inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
outputs = _: {
  packages = builtins.mapAttrs (system: pkgs: {
    default = pkgs.runCommandNoCC "check-env" {
    } ''
      mkdir -p $out/bin
      cat > $out/bin/check-env <<'EOF'
      #!/usr/bin/env bash
      set -euo pipefail
      check-env(){
        local LOCAL_REV=$(cat $FLOX_ENV_PROJECT/.flox/env.lock | jq .rev -r)
        {
          read -r owner
          read -r name 
        } <<< $(cat $FLOX_ENV_PROJECT/.flox/env.json | jq -cr '.owner, .name' )
        if [ -z "$owner" ] || [ -z "$name" ] || [ "$owner" == "null" ] || [ "$name" == "null" ] ; then
          return 0
        fi
        local token=$(flox config | awk 'match($0,/floxhub_token = "(.*)"/,m){print m[1]}')
        local data_dir=$(flox config | awk 'match($0,/data_dir = "(.*)"/,m){print m[1]}')
        local REMOTE_REV=$(env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git -c "remote.dynamicorigin.url=https://oauth2:$token@api.flox.dev/git/$owner/floxmeta" -C "$data_dir"meta/$owner ls-remote dynamicorigin refs/heads/$name | cut -f1)
        
        if [ "$LOCAL_REV" != "$REMOTE_REV" ] ; then
             echo "INFORMATION: environment has been changed" >&2
             echo "LOCAL_REV:   $LOCAL_REV" >&2
             echo "REMOTE_REV:  $REMOTE_REV" >&2
             return 1
        fi
        return 0
      }
      check-env
      EOF
      chmod +x $out/bin/check-env
    '';
  }) _.nixpkgs.legacyPackages;
};
}
