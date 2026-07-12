function whipper
    docker run -ti --rm --device=/dev/cdrom \
        --mount type=bind,source={$HOME}/.config/whipper,target=/home/worker/.config/whipper \
        --mount type=bind,source=/home/martin/output,target=/output \
        whipperteam/whipper
end
