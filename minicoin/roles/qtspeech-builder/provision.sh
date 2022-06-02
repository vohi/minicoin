. /opt/minicoin/util/install_helper.sh

prefix="/usr"
case $distro in
    ubuntu*)
        packages=(
            libpulse-dev    # pulseaudio
            libasound2-dev  # alsa
            libdotconf-dev  # needed to build speechd
            libsndfile-dev
            texinfo
            autoconf
            autopoint
            libtool
            gettext
        )
    ;;
    centos*)
        packages=(
            pulseaudio-libs-devel
            alsa-lib-devel
            libtool-ltdl-devel # needed to build speechd
            dotconf-devel
            libsndfile-devel
            texinfo
        )
    ;;
    opensuse*)
        packages=(
            pulseaudio-devel
            alsa-devel
            dotconf-devel # needed to build speechd
            libsndfile-devel
            gettext-tools
            makeinfo
        )
    ;;
    darwin*)
        exit 0
    ;;
esac

for package in "${packages[@]}"
do
    echo "Installing $package"
    install_package $package > /dev/null
done

cd /tmp
[ ! -d flite ] && git clone https://github.com/festvox/flite > /dev/null
cd flite
git checkout v2.2 > /dev/null
./configure --with-pic --enable-shared --prefix=$prefix > /dev/null
make -j$(nproc) > /dev/null && make install > /dev/null

cd /tmp
[ ! -d speechd ] && git clone https://github.com/brailcom/speechd.git > /dev/null
cd speechd
git checkout 0.11.1 > /dev/null
./build.sh > /dev/null
./configure  --prefix=$prefix > /dev/null
make -j$(nproc) > /dev/null && make install > /dev/null
