function backupm
    rsync -avz --delete /home/martin/Music/ raspberrypi:/media/Music/Music/
    ssh raspberrypi "sudo chown mpd:martin /media/Music/Music"
end
