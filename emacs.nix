{ pkgs, home, ... }:

let
  sources = import ./nix/sources.nix;
  nur = import sources.nur { pkgs = null; };
  tree-sitter = sources.elisp-tree-sitter;
  lib = pkgs.lib;

  treeSitterGrammars = pkgs.runCommandLocal "tree-sitter-grammars-bundle" {} ''
    mkdir -p $out/bin
    ${lib.concatStringsSep "\n"
    (lib.mapAttrsToList (name: src: "ln -s ${src}/parser $out/bin/${(builtins.replaceStrings [ "tree-sitter-" ] [ "" ] name)}.so") pkgs.tree-sitter.builtGrammars)};
  '';

  package = pkgs.emacsPgtkGcc;
in

{
  imports = [
    nur.repos.rycee.hmModules.emacs-init
  ];

  services.emacs = {
    enable = true;
    client = {
      enable = true;
      arguments = [
        "-c"
      ];
    };
  };

  programs.emacs = {
    enable = true;
    package = package;

    init = {
      enable = true;

      packageQuickstart = false;
      recommendedGcSettings = false;
      usePackageVerbose = false;

      earlyInit = ''
        ;; Minimize garbage collection during startup
        (setq garbage-collection-messages t
              gc-cons-threshold most-positive-fixnum
              gc-cons-percentage 0.6)

        ;; Lower threshold back to 8 MiB (default is 800kB)
        (add-hook 'emacs-startup-hook
          (lambda ()
            (run-with-idle-timer 2 t
              (lambda () (garbage-collect)))
            (setq gc-cons-threshold (expt 2 23))))

        ;; Avoid unnecessary regexp matching while loading .el files.
        (defvar hm/file-name-handler-alist file-name-handler-alist)
        (setq file-name-handler-alist nil)

        ;; Restore regexp matching
        (add-hook 'emacs-startup-hook (lambda ()
          (setq file-name-handler-alist hm/file-name-handler-alist)
          (makunbound 'hm/file-name-handler-alist)))

        ;; Emacs really shouldn't be displaying anything until it has fully started
        ;; up. This saves a bit of time.
        (setq-default inhibit-redisplay t
                      inhibit-message t)
        (add-hook 'window-setup-hook
                  (lambda ()
                    (setq-default inhibit-redisplay nil
                                  inhibit-message nil)
                    (redisplay)))

        ;; Disable some GUI distractions. We set these manually to avoid starting
        ;; the corresponding minor modes.
        (push '(menu-bar-lines . 0) default-frame-alist)
        (push '(tool-bar-lines . nil) default-frame-alist)
        (push '(vertical-scroll-bars . nil) default-frame-alist)

        ;; I typically want to use UTF-8.
        (prefer-coding-system 'utf-8-unix)
        (set-language-environment "UTF-8")

        ;; Set up fonts early.
        (set-face-attribute 'default
                            nil
                            :height 120
                            :family "Fira Mono")
        (set-face-attribute 'variable-pitch
                            nil
                            :family "DejaVu Sans")

        ;; Please don't load outdated byte code
        (setq load-prefer-newer t)

        ;; Debugging
        (setq message-log-max 10000)

      '';

      prelude = ''
        ;; No lockfiles
        (setq create-lockfiles nil)

        ;; Disable audio bell
        (setq visible-bell 1)

        ;; Disable startup message.
        (setq inhibit-startup-screen t
              inhibit-startup-echo-area-message (user-login-name))

        (setq initial-major-mode 'fundamental-mode
              initial-scratch-message nil)

        ;; Don't blink the cursor.
        (setq blink-cursor-mode nil)

        ;; Set frame title.
        (setq frame-title-format
              '("" invocation-name ": "(:eval
                                        (if (buffer-file-name)
                                            (abbreviate-file-name (buffer-file-name))
                                          "%b"))))

        ;; Make sure the mouse cursor is visible at all times.
        (set-face-background 'mouse "#ffffff")

        ;; Accept 'y' and 'n' rather than 'yes' and 'no'.
        (defalias 'yes-or-no-p 'y-or-n-p)

        ;; Don't want to move based on visual line.
        (setq line-move-visual nil)

        ;; Stop creating backup and autosave files.
        (setq make-backup-files nil
              auto-save-default nil)

        ;; Default is 4k, which is too low for LSP.
        (setq read-process-output-max (* 1024 1024))

        ;; Always show line and column number in the mode line.
        (line-number-mode)
        (column-number-mode)

        ;; Display line number in-buffer
        (add-hook 'prog-mode-hook 'display-line-numbers-mode)

        ;; Enable some features that are disabled by default.
        (put 'narrow-to-region 'disabled nil)

        ;; Typically, I only want spaces when pressing the TAB key. I also
        ;; want 4 of them.
        (setq-default indent-tabs-mode nil
                      tab-width 2
                      c-basic-offset 2)

        ;; Trailing white space are banned!
        (setq-default show-trailing-whitespace t)

        ;; Use one space to end sentences.
        (setq sentence-end-double-space nil)

        ;; Nicer handling of regions.
        (transient-mark-mode 1)

        ;; Make moving cursor past bottom only scroll a single line rather
        ;; than half a page.
        (setq scroll-step 1
              scroll-conservatively 5)

        ;; Enable highlighting of current line.
        (global-hl-line-mode 1)

        ;; Improved handling of clipboard in GNU/Linux and otherwise.
        (setq select-enable-clipboard t
              select-enable-primary t
              save-interprogram-paste-before-kill t)

        ;; Pasting with middle click should insert at point, not where the
        ;; click happened.
        (setq mouse-yank-at-point t)

        ;; Enable a few useful commands that are initially disabled.
        (put 'upcase-region 'disabled nil)
        (put 'downcase-region 'disabled nil)

        ;;; Directories
        (defvar user-setup-directory          (expand-file-name "setup"          user-emacs-directory))
        (defvar user-setup-builtins-directory (expand-file-name "setup/builtins" user-emacs-directory))
        (defvar local-dev-package-directory   (expand-file-name "packages"       user-emacs-directory))
        (defvar user-data-directory           (expand-file-name ""               user-emacs-directory))
        (defvar user-cache-directory          (expand-file-name ".cache"         user-emacs-directory))
        (defvar user-bin-directory            (expand-file-name "bin"            "~"))
        (setq custom-file                     (expand-file-name "custom.el"    user-emacs-directory))

        ;; It may not exist yet
        (ignore-errors (load custom-file))

        ;; When finding file in non-existing directory, offer to create the
        ;; parent directory.
        (defun with-buffer-name-prompt-and-make-subdirs ()
          (let ((parent-directory (file-name-directory buffer-file-name)))
            (when (and (not (file-exists-p parent-directory))
                       (y-or-n-p (format "Directory `%s' does not exist! Create it? " parent-directory)))
              (make-directory parent-directory t))))

        (add-to-list 'find-file-not-found-functions #'with-buffer-name-prompt-and-make-subdirs)

        ;; Don't want to complete .hi files.
        (add-to-list 'completion-ignored-extensions ".hi")

        (defun rah-disable-trailing-whitespace-mode ()
          (setq show-trailing-whitespace nil))

        ;; Shouldn't highlight trailing spaces in various mods
        (add-hook 'term-mode #'rah-disable-trailing-whitespace-mode)
        (add-hook 'term-mode-hook #'rah-disable-trailing-whitespace-mode)
        (add-hook 'compilation-mode-hook #'rah-disable-trailing-whitespace-mode)
        (add-hook 'undo-tree-visualizer-mode-hook #'rah-disable-trailing-whitespace-mode)
        (add-hook 'leetcode--problems-mode-hook #'rah-disable-trailing-whitespace-mode)

        (defun rah-prog-mode-setup ()
          ;; Use a bit wider fill column width in programming modes
          ;; since we often work with indentation to start with.
          (setq fill-column 80))

        (add-hook 'prog-mode-hook #'rah-prog-mode-setup)

        ; (defun rah-lsp ()
        ;   (interactive)
        ;   (envrc-mode)
        ;   (lsp))

        ;(defun rah-sort-lines-ignore-case ()
        ;  (interactive)
        ;  (let ((sort-fold-case t))
        ;    (call-interactively 'sort-lines)))

        ; ;; Connect M-x to ivy-rich
        ; (use-package counsel
        ;   :bind (("M-x" . counsel-M-x)
        ;          ("C-x b" . counsel-ibuffer)
        ;          ("C-x C-f" . counsel-find-file)
        ;          :map minibuffer-local-map
        ;          ("C-r" . 'counsel-minibuffer-history))
        ;   :config
        ;   (setq ivy-initial-inputs-alist nil)) ;; Don't start search with ^


        ;; counsel-projectile
        (provide 'workspace)

        ;; splash
        (provide 'splash)

        ;; magit
        (provide 'vsc)

        (add-to-list 'load-path "${tree-sitter}/core")
        (add-to-list 'load-path "${tree-sitter}/lisp")
        (add-to-list 'load-path "${tree-sitter}/langs")

        (setq tree-sitter-langs--testing t)
        (setq tsc-dyn-dir (expand-file-name "tree-sitter/" user-emacs-directory))
        (setq tree-sitter-load-path '("${treeSitterGrammars}/bin"))

        (add-to-list 'auto-mode-alist '("\\.sil\\'" . sil-mode))

        ;;; esc always quits
        (define-key minibuffer-local-map [escape] 'minibuffer-keyboard-quit)
        (define-key minibuffer-local-ns-map [escape] 'minibuffer-keyboard-quit)
        (define-key minibuffer-local-completion-map [escape] 'minibuffer-keyboard-quit)
        (define-key minibuffer-local-must-match-map [escape] 'minibuffer-keyboard-quit)
        (define-key minibuffer-local-isearch-map [escape] 'minibuffer-keyboard-quit)
        (global-set-key [escape] 'keyboard-quit)

        (global-set-key (kbd "C-d") 'scroll-up)
        (global-set-key (kbd "C-u") 'scroll-down)

        (setq python-indent-guess-indent-offset nil)
      '';

      usePackage = {
        all-the-icons = {
          enable = true;
        };

        counsel = {
          enable = true;
          diminish = [ "ivy-mode" ];
          command = [ "ivy-mode" ];
          config = ''
            (setq ivy-use-virtual-buffers t
                  ivy-wrap t
                  ivy-count-format "%d/%d "
                  enable-recursive-minibuffers nil
                  ivy-virtual-abbreviate 'full)

            (define-key ivy-minibuffer-map (kbd "TAB") #'ivy-alt-done)
            (define-key ivy-minibuffer-map (kbd "RET") #'ivy-alt-done)
            (define-key ivy-minibuffer-map (kbd "C-j") #'ivy-next-line)
            (define-key ivy-minibuffer-map (kbd "C-k") #'ivy-previous-line)

            (define-key ivy-switch-buffer-map (kbd "C-l") #'ivy-done)
            (define-key ivy-switch-buffer-map (kbd "C-j") #'ivy-next-line)
            (define-key ivy-switch-buffer-map (kbd "C-k") #'ivy-previous-line)
            (define-key ivy-switch-buffer-map (kbd "C-d") #'ivy-switch-buffer-kill)
            (define-key ivy-switch-buffer-map (kbd "C-q") #'ivy-switch-buffer-kill)

            ; (define-key ivy-reverse-i-search (kbd "C-l") #'ivy-done)
            ; (define-key ivy-reverse-i-search (kbd "C-j") #'ivy-next-line)
            ; (define-key ivy-reverse-i-search (kbd "C-k") #'ivy-previous-line)
            ; (define-key ivy-reverse-i-search (kbd "C-q") #'ivy-reverse-i-search-kill)

            (setq ivy-re-builders-alist
              '((t . ivy--regex-plus)))
                (ivy-mode 1)
           '';
        };

        counsel-projectile = {
          enable = true;
          bind = {
            "C-SPC" = "counsel-projectile-switch-project";
          };
          config = ''
            (counsel-projectile-mode)
          '';
        };

        dashboard = {
          enable = true;
          config = ''
            (setq show-week-agenda-p t)
            (setq dashboard-items '((recents . 15) (agenda . 5)))
            (setq dashboard-set-heading-icons t)
            (setq dashboard-set-file-icons t)
            (setq dashboard-startup-banner 'logo)
            (dashboard-setup-startup-hook)
          '';
        };

        doom-themes = {
          enable = true;
          config = ''
            (load-theme 'doom-one t)
          '';
        };

        editorconfig = {
          enable = true;
          config = ''
            (require 'editorconfig-core)
            (editorconfig-mode 1)
          '';
        };

        esup = {
          enable = true;
        };

        swiper = {
          enable = true;
        };

        leetcode = {
          enable = true;
          config = ''
            (define-key leetcode--problem-description-mode-map
              (kbd "h") #'meow-left)
            (define-key leetcode--problem-description-mode-map
              (kbd "l") #'meow-right)
            (define-key leetcode--problem-description-mode-map
              (kbd "w") #'meow-next-word)
            (define-key leetcode--problem-description-mode-map
              (kbd "b") #'meow-back-word)

            (setq leetcode-prefer-language "python3")
            (setq leetcode-prefer-sql "mysql")
            (setq leetcode-save-solutions t)
            (setq leetcode-directory "~/src/leet")

            (defalias 'lc 'leetcode)
            (defalias 'lct 'leetcode-try)
            (defalias 'lcs 'leetcode-submit)
          '';
        };

        eglot = {
          enable = true;
          config = ''
            (add-hook 'python-mode-hook 'eglot-ensure)
          '';
        };

        lsp-mode = {
          enable = false;
          command = [ "lsp" ];
          hook = [
            "(python-mode . lsp-deferred)"
            "(rust-mode . lsp-deferred)"
            "(lsp-mode . lsp-enable-which-key-integration)"
          ];
        };

        # company = { enable = true; };
        # flycheck = { enable = true; };
        # lsp-treemacs = {
        #   enable = true;
        #   command = [ "lsp-treemacs-errors-list" ];
        # };
        lsp-ui = {
          enable = false;
          command = [ "lsp-ui-mode" ];
        };
        # treemacs = { enable = true; };
        lsp-ivy = {
          enable = false;
          command = [ "lsp-ivy-workspace-symbol" ];
        };

        # TODO
        # dap-mode = { enable = true; };

        magit = {
          enable = true;
          config = ''
            (setq magit-completing-read-function 'ivy-completing-read)
          '';
          bind = {
            "C-x g s" = "magit-status";
            "C-x g x" = "magit-checkout";
            "C-x g c" = "magit-commit";
            "C-x g p" = "magit-push";
            "C-x g u" = "magit-pull";
            "C-x g e" = "magit-ediff-resolve";
            "C-x g r" = "magit-rebase-interactive";
          };
        };

        meow = {
          enable = true;
          after = [ "ivy" "swiper" ];
          config = ''
            (defun o-dup ()
              (interactive)
              (insert-char
                (char-after)))

            ; A less-smart line join.
            ; I wanted to keep the extra space anyway.
            ; TODO maybe check this works at buffer end
            (defun o-join ()
              (interactive)
              (meow-join (- 0 1))
              (meow-kill nil)
              (unless (eq (char-after) ?\s)
                (insert-char ?\s)))

            (defun o-append-line ()
              (interactive)
              (meow-line 1)
              (meow-append))

            (defun o-change ()
              (interactive)
              (meow-kill nil)
              (meow-insert))

            (defun o-change-char ()
              (interactive)
              (delete-char 1)
              (meow-insert))

            (defun o-replace ()
              (interactive)
              (let ((c (read-char))
                    (l (- (region-end) (region-beginning))))
                (meow-kill nil)
                (insert-char c l)))

            (defun o-replace-char ()
              (interactive)
              (let ((c (read-char))
                (delete-char 1)
                (insert-char c))))

            (defun o-open-emacs-config ()
              (interactive)
              (find-file "~/.config/nixpkgs/emacs.nix"))

            (defun o-indent-left ()
              (interactive)
              (meow--with-selection-fallback
                (save-mark-and-excursion
                  (indent-rigidly-left
                    (region-beginning)
                    (region-end)))
                (setq deactivate-mark nil)))

            (defun o-mark-line ()
              (set-mark (line-beginning-position))
              (goto-char (line-end-position))
              (activate-mark))

            (defun o-indent-right()
              (interactive)
              (meow--with-selection-fallback
                (save-mark-and-excursion
                  (indent-rigidly-right
                    (region-beginning)
                    (region-end)))
                (setq deactivate-mark nil)))

            (defun o-indent-line-left ()
              (interactive)
              (indent-rigidly-left
                (line-beginning-position)
                (line-end-position)))

            (defun o-indent-line-right ()
              (interactive)
              (indent-rigidly-right
                (line-beginning-position)
                (line-end-position)))

            (defun meow-setup ()

              (setq meow-cheatsheet-layout meow-cheatsheet-layout-qwerty)

              (setq meow-selection-command-fallback
                '((meow-replace . meow-replace-char)
                  (meow-change . meow-change-char)
                  (meow-save . meow-save-char)
                  (meow-kill . delete-char)
                  (meow-delete . meow-C-d)
                  (meow-cancel . meow-keyboard-quit)
                  (o-change . o-change-char)
                  (o-replace . o-replace-char)
                  (o-indent-left . o-indent-line-left)
                  (o-indent-right . o-indent-line-right)
                  (meow-pop-selection . meow-pop-grab)))

              (meow-motion-overwrite-define-key
                '("j" . meow-next)
                '("k" . meow-prev))

              (meow-leader-define-key

                ;; SPC j/k will run the original command in MOTION state.
                '("j" . meow-motion-origin-command)
                '("k" . meow-motion-origin-command)

                ;; Use SPC (0-9) for digit arguments.
                '("1" . meow-digit-argument)
                '("2" . meow-digit-argument)
                '("3" . meow-digit-argument)
                '("4" . meow-digit-argument)
                '("5" . meow-digit-argument)
                '("6" . meow-digit-argument)
                '("7" . meow-digit-argument)
                '("8" . meow-digit-argument)
                '("9" . meow-digit-argument)
                '("0" . meow-digit-argument)
                '("/" . meow-keypad-describe-key)
                '("?" . meow-cheatsheet)

                ;; reverse command query
                '("^" . meow-keypad-describe-key)

                ;; cheatsheet
                '("?" . meow-cheatsheet)

                ;; high frequency keybindings

                ;; window management
                '("w" . other-window)
                '("o" . delete-other-windows)


                '("u" . undo-tree-visualize)

                ;; high frequency commands
                '(";" . comment-dwim)
                '("k" . quit-window)
                '("g" . magit-status)
                '("p" . project-find-file)
                '("j" . o-join)
                '("d" . dired)
                '("b" . switch-to-buffer)
                '("e" . o-open-emacs-config)
                '("r" . deadgrep)
                '("f" . find-file)
                '("i" . imenu)
                '("a" . "M-x"))

              (meow-normal-define-key
                '("/" . swiper)
                '("0" . meow-expand-0)
                '("9" . meow-expand-9)
                '("8" . meow-expand-8)
                '("7" . meow-expand-7)
                '("6" . meow-expand-6)
                '("5" . meow-expand-5)
                '("4" . meow-expand-4)
                '("3" . meow-expand-3)
                '("2" . meow-expand-2)
                '("1" . meow-expand-1)
                '("<" . o-indent-left)
                '(">" . o-indent-right)
                '("-" . negative-argument)
                '(";" . meow-reverse)
                '("," . meow-inner-of-thing)
                '("." . meow-bounds-of-thing)
                '("[" . meow-beginning-of-thing)
                '("]" . meow-end-of-thing)
                '("a" . meow-append)
                '("A" . o-append-line)
                '("b" . meow-back-word)
                '("B" . meow-block-expand)
                '("c" . o-change)
                '("C" . meow-change-save)
                '("d" . meow-kill)
                '("D" . meow-backward-delete)
                '("e" . meow-next-word)
                '("E" . meow-next-symbol)
                '("f" . meow-find)
                '("F" . meow-find-expand)
                '("g" . meow-cancel)
                '("G" . meow-grab)
                '("h" . meow-left)
                '("H" . meow-left-expand)
                '("i" . meow-insert)
                '("I" . meow-open-above)
                '("j" . meow-next)
                '("J" . meow-next-expand)
                '("k" . meow-prev)
                '("K" . meow-prev-expand)
                '("l" . meow-right)
                '("L" . meow-right-expand)
                '("m" . meow-join)
                '("n" . meow-search)
                '("N" . meow-pop-search)
                '("o" . meow-open-below)
                '("O" . meow-open-above)
                '("p" . meow-yank)
                '("P" . meow-clipboard-yank)
                '("q" . meow-quit)
                '("Q" . meow-goto-line)
                '("r" . o-replace)
                '("R" . meow-swap-grab)
                '("s" . save-buffer)
                '("t" . meow-till)
                '("T" . meow-till-expand)
                '("u" . meow-undo)
                '("U" . undo-tree-redo)
                '("v" . meow-visit)
                '("V" . meow-kmacro-matches)
                '("w" . meow-next-word)
                '("W" . meow-next-symbol)
                '("x" . meow-line)
                '("X" . meow-kmacro-lines)
                '("y" . meow-save)
                '("Y" . meow-sync-grab)
                '("z" . meow-pop-selection)
                '("Z" . meow-pop-all-selection)
                '("&" . meow-query-replace)
                '("%" . mark-whole-buffer)
                '("." . repeat)
                '("#" . comment-or-uncomment-region)
                '("\\" . quoted-insert)
                '("<escape>" . meow-cancel)))

            (meow-setup)
            ;; If you want relative line number in NORMAL state(for display-line-numbers-mode)
            (meow-setup-line-number)
            ;; If you need setup indicator, see `meow-indicator' for customizing by hand.
            (meow-global-mode 1)
            (meow-setup-indicator)

            (defun swiper-mc-regions-in-region ()
              "Create a region for each `swiper' candidate inside current region.
              Make sure `swiper-mc' is on `mc/cmds-to-run-once' list."
              (interactive)
              (unless (require 'multiple-cursors nil t)
                (error "Multiple-cursors isn't installed"))
              (unless (window-minibuffer-p)
                (error "Call me only from `swiper'"))
              (let ((cands (nreverse ivy--old-cands))
                    (action (ivy--get-action ivy-last)))
                (unless (string= ivy-text "")
                  (ivy-exit-with-action
                    (lambda (_)
                      (let ((b (region-beginning))
                            (e (region-end)))
                        (meow-cancel-selection)
                        (save-restriction
                          (narrow-to-region b e)
                          (let (cand)
                            (while (setq cand (pop cands))
                              (funcall action cand)
                              (when cands
                                (push-mark (avy-candidate-beg cand))
                                (mc/create-fake-cursor-at-point))))
                          (multiple-cursors-mode 1))))))))


            ; (define-key swiper-map (kbd "RET") #'swiper-mc-regions-in-region)
          '';
        };

        envrc = {
          enable = true;
          config = ''
            (envrc-global-mode)
          '';
        };

        multiple-cursors = {
          enable = true;
        };

        phi-search = {
          enable = true;
          bind = {
            "C-s" = "phi-search";
            "C-r" = "phi-search-backward";
          };
        };

        nix-mode = {
          enable = true;
        };

        page-break-lines = {
          enable = true;
        };

        projectile = {
          enable = true;
          diminish = ["projectile-mode"];
          config = ''
            (setq projectile-completion-system 'ivy)
            (projectile-global-mode)
          '';
          bindKeyMap = {
            "C-c p" = "projectile-command-map";
          };
          init = ''
            (setq projectile-project-search-path '("~/src"))
            (setq projectile-switch-project-action #'projectile-dired)
          '';
        };

        rust-mode = {
          enable = true;
        };

        tree-sitter = {
          enable = true;
        };

        tree-sitter-langs = {
          enable = true;
        };

        undo-tree = {
          enable = true;
          config = ''
            (define-key undo-tree-visualizer-mode-map
              (kbd "h") #'undo-tree-visualize-switch-branch-left)
            (define-key undo-tree-visualizer-mode-map
              (kbd "l") #'undo-tree-visualize-switch-branch-right)
            (define-key undo-tree-visualizer-mode-map
              (kbd "j") #'undo-tree-visualize-redo)
            (define-key undo-tree-visualizer-mode-map
              (kbd "k") #'undo-tree-visualize-undo)

            (global-undo-tree-mode 1)
          '';
        };

        wgrep = {
          enable = true;
        };

        which-key = {
          enable = true;
          after = [ "lsp-mode" ];
          diminish = [ "which-key-mode" ];
          config = ''
            (which-key-mode)
            (setq which-key-idle-delay 1)
          '';
        };
      };
    };
  };

  programs.emacs.extraPackages = epkgs: with epkgs; [
  ];
}
