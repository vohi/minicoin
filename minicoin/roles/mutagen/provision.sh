. /minicoin/util/parse-opts.sh "$@"

if [ "$PARAM_reverse" == "true" ]
then
    for ((i=0;i<${#PARAM_alpha[@]};++i))
    do
        beta=${PARAM_beta[i]}
        beta=${beta/\~/\/home/vagrant}
        sudo -H -u vagrant mkdir -p $beta
    done
    exit 0
fi

platform=$(uname)
if [[ $(uname) =~ "Darwin" ]]
then
    sudo -H -u vagrant brew install mutagen-io/mutagen/mutagen
else
    echo "Mutagen not implemented"
    exit 1
fi

USERNAME="${POSITIONAL[2]}"
HOST=$(echo $SSH_CONNECTION | cut -f 1 -d ' ')
ssh-keyscan -H "$HOST" >> /Users/vagrant/.ssh/known_hosts

sudo -H -u vagrant mutagen daemon register
sudo -H -u vagrant mutagen daemon start
sudo -H -u vagrant mutagen sync terminate minicoin 2> /dev/null

for ((i=0;i<${#PARAM_alpha[@]};++i))
do
    mkdir -p ${PARAM_beta[i]}
    sudo -H -u vagrant mutagen sync create --sync-mode one-way-replica --ignore-vcs --name minicoin ${USERNAME}@${HOST}:${PARAM_alpha[i]} ${PARAM_beta[i]}
done
