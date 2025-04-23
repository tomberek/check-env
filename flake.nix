{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs = _: {
    packages = builtins.mapAttrs (system: pkgs: {
      default = pkgs.writeShellApplication {
        name = "check-env";

        # excluding flox and git. Assume they are in the PATH
        runtimeInputs = [
          pkgs.jq
          pkgs.gawk
        ];

        text = ''
          check-env(){
            if [ -z "$FLOX_ENV_PROJECT" ] || [ ! -f "$FLOX_ENV_PROJECT"/.flox/env.lock ]; then
	      echo "error: tool must be run in an environment" >&2
	      return 0
	    fi
            local token data_dir REMOTE_REV LOCAL_REV
            LOCAL_REV=$(jq .rev -r "$FLOX_ENV_PROJECT"/.flox/env.lock)
            {
              read -r owner
              read -r name
            } <<< "$(jq -cr '.owner, .name' "$FLOX_ENV_PROJECT"/.flox/env.json)"
            if [ -z "$owner" ] || [ -z "$name" ] || [ "$owner" == "null" ] || [ "$name" == "null" ] ; then
              return 0
            fi
            token=$(flox config | awk 'match($0,/floxhub_token = "(.*)"/,m){print m[1]}')
            data_dir=$(flox config | awk 'match($0,/data_dir = "(.*)"/,m){print m[1]}')
            REMOTE_REV=$(env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git -c "remote.dynamicorigin.url=https://oauth2:$token@api.flox.dev/git/$owner/floxmeta" -C "$data_dir"meta/"$owner" ls-remote dynamicorigin refs/heads/"$name" | cut -f1)
            
            if [ "$LOCAL_REV" != "$REMOTE_REV" ] ; then
                 echo "INFORMATION: environment has been changed" >&2
                 echo "LOCAL_REV:   $LOCAL_REV" >&2
                 echo "REMOTE_REV:  $REMOTE_REV" >&2
                 return 1
            fi
            return 0
          }
          check-env
        '';
      };
    }) _.nixpkgs.legacyPackages;
  };
}
