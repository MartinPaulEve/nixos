function nobyobu --description 'Open a plain ghostty window (no byobu) from anywhere, e.g. from inside byobu'
    # Same invocation as the "Ghostty (no byobu)" desktop entry (home/martin/ghostty.nix):
    # NOBYOBU=1 makes fish skip the byobu handoff, and the separate --class keeps this
    # out of the byobu ghostty instance so the variable actually reaches the new shell.
    env NOBYOBU=1 ghostty --class=com.mitchellh.ghostty.plain >/dev/null 2>&1 &
    disown
end
