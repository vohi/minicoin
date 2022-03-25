. /opt/minicoin/util/install_helper.sh

case $distro in
  ubuntu*)
    apt -y install curl dirmngr apt-transport-https lsb-release ca-certificates
    curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -

    packages=(
        nodejs
        python3-pip
        libnss3-dev
        libdbus-1-dev
        libxcursor-dev
        libxrandr-dev
        libxshmfence-dev
        libxtst-dev
        libxdamage-dev
        libxkbfile-dev
        # optional
        libwebp-dev
        libsnappy-dev
        libevent-dev
        libxml2-dev
        libxslt-dev
        liblcms2-dev
    )
    ;;
esac

for package in "${packages[@]}"
do
    echo "Installing $package"
    install_package $package > /dev/null
done

pip3 install html5lib
