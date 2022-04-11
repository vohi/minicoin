#!/bin/bash
set -e
set -o pipefail

sed -i 's/us.archive.ubuntu.com/archive.ubuntu.com/' /etc/apt/sources.list
echo "nameserver 8.8.8.8" | tee /etc/resolv.conf > /dev/null

apt-get -qq update
apt-get -q install -y build-essential
apt-get -q install -y libc6-i386 libpulse-dev
apt-get -q install -y default-jre openjdk-11-jdk-headless
apt-get -q install -y gradle

ndkVersion="${PARAM_ndkVersion:-23.1.7779620}"
ndkHost="linux-x86_64"
sdkBuildToolsVersion="${PARAM_sdkBuildToolsVersion:-31.0.0}"
sdkApiLevel="${PARAM_sdkApiLevel:-android-31}"

repository="https://dl.google.com/android/repository"
toolsFile="commandlinetools-linux-7583922_latest.zip"
toolsFolder="cmdline-tools"
androidRoot=/opt/android

[ ! -d $androidRoot ] && mkdir -p $androidRoot

if ! which sdkmanager > /dev/null
then
  if [ ! -f $toolsFile ]
  then
    echo "Downloading SDK tools from '$repository/$toolsFile'"
    curl -L -O $repository/$toolsFile
    error=$?
    if [[ ! $error -eq 0 ]]; then
      >&2 echo "Error downloading SDK tools!"
      exit $error
    fi
  fi

  echo "Unpacking SDK command line tools"
  unzip -qq $toolsFile -d /tmp
  error=$?
  if [[ ! $error -eq 0 ]]; then
    >&2 echo "Error unpacking SDK!"
    exit 1
  fi

  echo "Installing latest commandline tools into '$androidRoot'"
  echo "y" | /tmp/cmdline-tools/bin/sdkmanager --sdk_root="$androidRoot" "cmdline-tools;latest" >> sdkmanager.log
  error=$?
  if [[ ! $error -eq 0 ]]; then
    >&2 echo "Error installing command line tools!"
    exit $error
  fi

  rm -rf /tmp/cmdline-tools
  [ -f $toolsFile ] && rm $toolsFile
fi

# silence warnings
[[ ! -d ~/.android ]] && mkdir ~/.android
touch ~/.android/repositories.cfg

echo "Configuring environment"
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

if (! grep "ANDROID_SDK_ROOT" /home/vagrant/.profile)
then
  cp /home/vagrant/.profile /home/vagrant/.profile.backup
  echo "export JAVA_HOME=$JAVA_HOME" >> /home/vagrant/.profile
  echo "export ANDROID_SDK_ROOT=$androidRoot" >> /home/vagrant/.profile
  echo "export ANDROID_NDK_ROOT=$androidRoot/ndk/$ndkVersion" >> /home/vagrant/.profile
  echo "export PATH=\$PATH:\$JAVA_HOME/bin:\$ANDROID_SDK_ROOT/$toolsFolder/latest/bin" >> /home/vagrant/.profile
  echo "export ANDROID_SDK_HOME=~/.android" >> /home/vagrant/.profile
  echo "export ANDROID_AVD_HOME=~/.android/avd" >> /home/vagrant/.profile
  echo "export ANDROID_NDK_HOST=$ndkHost" >> /home/vagrant/.profile
  echo "export ANDROID_API_VERSION=$sdkApiLevel" >> /home/vagrant/.profile
fi

. /home/vagrant/.profile

sdkmanager_version=$(sdkmanager --version)
printf "Using sdkmanager version %s\n", $sdkmanager_version

# Optional workaround for issue with certain JDK/JRE versions
#cp $toolsFolder/tools/bin/sdkmanager $toolsFolder/tools/bin/sdkmanager.backup
#sed -i 's/^DEFAULT_JVM_OPTS.*/DEFAULT_JVM_OPTS='"'\"-Dcom.android.sdklib.toolsdir=\$APP_HOME\" -XX:+IgnoreUnrecognizedVMOptions --add-modules java.se.ee'"'/' \
#        $toolsFolder/tools/bin/sdkmanager

echo "Installing platform $sdkApiLevel"
echo "y" | sdkmanager "platforms;$sdkApiLevel" >> sdkmanager.log
echo "Installing Platform tools"
echo "y" | sdkmanager "platform-tools" >> sdkmanager.log
echo "Installing build-tools $sdkBuildToolsVersion"
echo "y" | sdkmanager "build-tools;$sdkBuildToolsVersion" >> sdkmanager.log
echo "Installing NDK $ndkVersion"
echo "y" | sdkmanager "ndk;$ndkVersion" >> sdkmanager.log

echo "SDK installation complete. Here's the list of installed packages:"
sdkmanager --list

echo "... and a list of available targets:"
avdmanager list target
