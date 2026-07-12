function lgsearch
    set -l project_path (op read 'op://BotAccess/lgsearch/PROJECT_PATH')
    $project_path/.venv/bin/python3 $project_path/main.py search $argv
end
