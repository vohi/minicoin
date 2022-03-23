# source this file from a package installing provisioner

if [ $(uname) == "Darwin" ]
then
  ID="darwin" # no /etc/os-release on macOS
  distro="darwin"
else
  . /etc/os-release
  distro=${ID}${VERSION_ID}
  # fix for locale not being set correctly
  echo "LC_ALL=en_US.UTF-8" >> /home/vagrant/.profile
fi

function ubuntu_prepare()
{
    # add google's dns server for fast and reliable lookups
    echo "nameserver 8.8.8.8" | tee /etc/resolv.conf > /dev/null

    # enable source repositories for apt
    sed -i 's/us.archive.ubuntu.com/archive.ubuntu.com/' /etc/apt/sources.list
    sed -i '/deb-src http.*xenial.* main restricted$/s/^# //g' /etc/apt/sources.list

    export DEBIAN_FRONTEND=noninteractive
    apt-get update > /dev/null
}

function centos_prepare()
{
    yum install -y epel-release > /dev/null
    yum install -y dnf-plugins-core > /dev/null
    yum config-manager --set-enabled powertools > /dev/null
    yum update -y > /dev/null
    yum group install -y 'Development Tools' > /dev/null
}

function opensuse_prepare()
{
    zypper refresh
}

function darwin_prepare()
{
    true # nothing to be done with brew
}

case $distro in
ubuntu*)
    install_command="apt-get -qq -y install"
    prepare_command=ubuntu_prepare
    ;;
centos*)
    install_command="yum install -y"
    prepare_command=centos_prepare
    ;;
opensuse*)
    prepare_command=opensuse_prepare
    install_command="zypper --quiet --non-interactive install -y"
    ;;
darwin)
    prepare_command=darwin_prepare
    install_command="su -l vagrant -c brew install"
    ;;
*)
  >&2 echo "Don't know how to install packages on '$distro'"
  exit 1
  ;;
esac

function prepare_install()
{
    $prepare_command "$@"
}

if [ ! -f /tmp/install_prepared ]
then
    touch /tmp/install_prepared
    echo "Updating repositories for $distro"
    prepare_install
fi

function install_package()
{
    $install_command "$@"
}
