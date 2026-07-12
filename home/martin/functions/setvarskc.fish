function setvarskc
    for line in (op item get 'setvarskc' --vault='BotAccess' --format=json | jq -r '.fields[] | select(.purpose == null and .value != null and .value != "") | "\(.label)\t\(.value)"')
        set -l kv (string split -m 1 \t -- $line)
        if test (count $kv) -eq 2
            set -g -x $kv[1] $kv[2]
        end
    end
end
