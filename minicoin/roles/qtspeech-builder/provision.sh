. /opt/minicoin/util/install_helper.sh

case $distro in
    ubuntu*)
        packages=(
            libspeechd-dev
            flite1-dev
            libasound2-dev
        )
    ;;
    centos*)
        # needed for flite >= 2.0.0
        yum-config-manager --add-repo http://repo.okay.com.mx/centos/8/x86_64/release
        packages=(
            speech-dispatcher-devel
            "--nogpgcheck flite-devel"
            alsa-lib-devel
        )
    ;;
    opensuse*)
        packages=(
            libspeechd-devel
            alsa-devel
        )
        cd /tmp
        git clone https://github.com/festvox/flite
        cd flite
        git checkout v2.2
        ./configure --with-pic --enable-shared
        make
        make get_voices
        make install
    ;;
    darwin*)
    ;;
esac

for package in "${packages[@]}"
do
    echo "Installing $package"
    install_package $package > /dev/null
done
