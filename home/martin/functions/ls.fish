function ls --wraps='eza -lh --group-directories-first --icons=auto' --description 'alias ls=eza -lh --group-directories-first --icons=auto'
  EZA_COLORS="di=32" eza -lh --group-directories-first --icons=auto $argv
        
end
