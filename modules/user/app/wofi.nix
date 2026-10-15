{ ... }:

{
  programs.wofi = {
    enable = true;
    settings = {
      # Core behavior
      mode = "drun"; # app launcher mode
      show = "drun"; # show desktop entries
      prompt = "Search..."; # search bar text
      insensitive = true; # case-insensitive search
      allow_images = true; # show app icons
      width = 600;
      height = 400;
      location = "center"; # center on screen
      hide-scroll = false;
      no-actions = true; # cleaner UI
      layer = true;
    };

    # CSS theming
    style = ''
      window {
        border: 0px solid #3b4252;
        border-radius: 15px;
        /*background-color: rgba(30, 30, 30, 0.9);*/
        background-color: rgba(0, 0, 0, 0.6);
        color: #cdd6f4;
      }

      #outer-box {
        margin: 20px;
      }

      #input {
        margin-bottom: 20px;
        margin: 10px;
        padding: 8px;
        border: none;
        border-radius: 15px;
        /*background-color: rgba(12, 12, 12, 0.9);
        color: #eceff4;*/
        background-color: rgba(0, 0, 0, 0.6);
        color: #cdd6f4;
        font-size: 14px;
      }

      #input:focus {
        border: 2px solid #5e81ac;
        /*background-color: #3b4252;
        background-color: rgba(0, 0, 0, 0.6);
        color: #cdd6f4;*/
        background-color: rgba(30, 30, 46, 0.5);
      }

      #inner-box {
        margin-top: 10px;
        margin: 10px;
      }

      #entry {
        padding: 6px;
      }

      #entry:selected {
        padding: 8px;
        /*border-radius: 10px;
        background-color: rgba(94, 129, 172, 0.8);
        color: #eceff4;*/
        background-color: rgba(30, 30, 46, 0.5);
      }

      #text {
        color: #d8dee9;
        font-size: 13px;
      }
    '';
  };
}
