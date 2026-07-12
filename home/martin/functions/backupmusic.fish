function backupmusic
    rsync -avz --delete /home/martin/Music/ statler:~/Music/

end
