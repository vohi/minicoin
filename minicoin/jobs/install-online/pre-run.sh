path_options=(
    "$HOME/Library/Application Support/Qt"
    "$HOME/.local/share/Qt"
    "$USERPROFILE/AppData/Roaming/Qt"
)

for path in "${path_options[@]}"
do
    if [ -d "$path" ]
    then
        if [ -f "$path/qtaccount.ini" ]
        then
            cp "$path/qtaccount.ini" "$(dirname $0)"
            exit 0
        else
            echo "No qtaccount.ini file found in $path, please set your account up locally."
            exit 1
        fi
    fi
done

echo "Can't find your qtaccount.ini file location, tried ${path_options[@]}"
exit 2
