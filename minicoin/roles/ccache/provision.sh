. /opt/minicoin/util/parse-opts.sh $HOME "$@"

sudo apt-get install -y ccache

if [[ ! $(which ccache) ]]
then
    >&2 echo "Failed to install ccache"
    exit 1
fi

for p in ${PARAMS[@]}
do
    config="PARAM_$p"
    value="${!config}"

    [ ! -z $PARAM_cache_dir ] && sudo -u vagrant ccache --set-config=$p=$value
done
sudo -u vagrant ccache --show-config || true
