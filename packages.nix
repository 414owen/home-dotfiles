{ pkgs, ... }:

{
  home.packages = with pkgs; [
    any-nix-shell
    bat
    cachix
    exa
    fasd
    fd
    htop
    gitAndTools.hub
    jq
    kak-lsp
    killall
    neofetch
    nix-prefetch-github
    nix-index
    nixops
    nix-prefetch-git
    ranger
    ripgrep
    sd
    stdenv
    tmux
    zsh-history-substring-search
    zsh-syntax-highlighting
  ] ++ (with gitAndTools; [
    gh
    git-absorb
    git-gone
    git-open
    git-recent
    git-standup
    git-test
    git-fame
  ]);
}
