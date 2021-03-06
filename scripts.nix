{ pkgs, ... }:

let
  writeScript = pkgs.writeScript;
  git-weekend = pkgs.writeShellScriptBin "git-weekend" ''
    FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --env-filter 'at="$(git log --no-walk --pretty=format:%ai $GIT_COMMIT)" \
        ct="$(git log --no-walk --pretty=format:%ci $GIT_COMMIT)"; \
        export GIT_AUTHOR_DATE=$(date -d "$(dateround "$at" Sat)" "+%Y-%m-%d %H:%M:%S") \
        GIT_COMMITTER_DATE=$(date -d "$(dateround "$ct" Sat)" "+%Y-%m-%d %H:%M:%S")'
  '';
in

{
  inherit git-weekend;
}
