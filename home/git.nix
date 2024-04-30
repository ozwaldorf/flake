{ ... }:
{
  programs.git = {
    enable = true;

    userName = "ozwaldorf";
    userEmail = "self@ossian.dev";
    signing = {
      key = "~/.ssh/id_ecdsa.pub";
      signByDefault = true;
    };
    extraConfig = {
      url."ssh://git@github.com/".insteadOf = "https://github.com/";
      gpg.format = "ssh";
      init.defaultBranch = "main";
      core.editor = "nvim";
      core.commentChar = "!";
    };
    ignores = [
      ".envrc"
      ".direnv"
      "result"
    ];
    delta = {
      enable = true;
      options = {
        navigate = true;
        side-by-side = true;
        true-color = "never";

        features = "unobtrusive-line-numbers decorations";
        unobtrusive-line-numbers = {
          line-numbers = true;
          line-numbers-left-format = "{nm:>4}│";
          line-numbers-right-format = "{np:>4}│";
          line-numbers-left-style = "grey";
          line-numbers-right-style = "grey";
        };
        decorations = {
          commit-decoration-style = "bold grey box ul";
          file-style = "bold blue";
          file-decoration-style = "ul";
          hunk-header-decoration-style = "box";
        };
      };
    };
  };
}
