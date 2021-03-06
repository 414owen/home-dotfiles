{ lib, pkgs, ... }:

let
  hoogle =
    # build up the hoogle function
    (let
      P = x: "Prelude." + x;
      return = P "return";
      asString = x: "(\"" + x + "\" :: " + P "String" + ")";
      cat = P "++";
      fun1 = arg: body: "\\ " + arg + " -> " + body;
      unwords = ws: lib.strings.concatStringsSep " " ws;
    # :def hoogle \s -> Prelude.return Prelude.$ (":! hoogle --count=15 \"" :: Prelude.String) Prelude.++ s Prelude.++ ("\"" :: Prelude.String)
    # :def hoogle \s -> return ((":! hoogle --count=15 \"" :: String) ++ s ++ ("\"" :: String))
    in
      ":def hoogle " +
      (fun1 "s" (unwords [
        return "(" (asString ":! hoogle --count=15 \\\"") cat "s" cat (asString "\\\"") ")"
      ]))
    );
in

{
  home.file.".ghci".text = lib.strings.concatStringsSep "\n" [
    # Turn off output for resource usage and types.  This is to reduce verbosity when reloading this file.
    ":unset +s +t"
    # Turn on multi-line input and remove the distracting verbosity.
    ":set +m -v0"

    # turn on common ghci extensions
    ":set -XNumericUnderscores -XTupleSections -XPartialTypeSignatures"
    ":set -XScopedTypeVariables -XFlexibleContexts -XDataKinds"

    # run all debug and assert cpp vars
    # ":set -cpp -DASSERTS -DDEBUG"

    # don't warn about shadowing
    ":set -Wno-name-shadowing"

    # UDFs
    hoogle

    # numeric precision function
    "precision = \\n f -> (fromInteger $ round $ f * (10^n)) / (10.0^^n)"

    # import the prompt (and required packages)
    # ANSI escape sequences allow for displaying colours in compatible terminals.
    # See [http://www.lihaoyi.com/post/BuildyourownCommandLinewithANSIescapecodes.html this guide] for help interpreting them.
    ''
    :set prompt "\ESC[1;35m\x03BB> \ESC[m"
    :set prompt-cont "\ESC[1;35m > \ESC[m"
    ''

    # Use :rr to reload this file.
    ":def! rr \\_ -> return \":script ~/.ghci\""

    # Typing `:pretty` will turn on the pretty-printing
    ":set -package process"

    # Turn on output of types.  This line should be last.
    ":set +t"
  ];
}
