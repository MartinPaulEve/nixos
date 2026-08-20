function ls --wraps='eza -lh --group-directories-first --icons=auto' --description 'alias ls=eza -lh --group-directories-first --icons=auto'
  # No icons on the sshfs mounts: to pick the empty-vs-full folder icon eza
  # reads the contents of every subdirectory it lists, which over sshfs on
  # huge directories (~100k entries each on the NAS) turns a 40-line listing
  # into millions of remote dirents — `ls` appears to hang. Icons only
  # activate on a tty, which is why piped/scripted runs never showed this.
  set -l icons auto
  string match -q -- "$HOME/mounts*" $PWD; and set icons never
  for a in $argv
    string match -q -- "$HOME/mounts*" (realpath -- $a 2>/dev/null; or echo $a); and set icons never
  end
  EZA_COLORS="di=32" eza -lh --group-directories-first --icons=$icons $argv
end
