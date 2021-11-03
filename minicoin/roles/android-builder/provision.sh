#!/bin/bash
set -e
set -o pipefail

sed -i 's/us.archive.ubuntu.com/archive.ubuntu.com/' /etc/apt/sources.list
echo "nameserver 8.8.8.8" | tee /etc/resolv.conf > /dev/null

apt-get -qq update
apt-get -q install -y build-essential
apt-get -q install -y default-jre openjdk-8-jdk-headless
apt-get -q install -y libc6-i386 libpulse-dev

# the rest of the provisioning is executed as user vagrant
ndkVersion="${PARAM_ndkVersion:-r22b}"
ndkHost="linux-x86_64"
sdkBuildToolsVersion="${PARAM_sdkBuildToolsVersion:-30.0.3}"
sdkApiLevel="${PARAM_sdkApiLevel:-android-30}"

repository="https://dl.google.com/android/repository"
toolsFile="commandlinetools-linux-6609375_latest.zip"
toolsFolder="cmdline-tools"
ndkFile="android-ndk-$ndkVersion-$ndkHost.zip"
ndkFolder="android-ndk-$ndkVersion"
androidRoot=/opt/android

[[ -d "$androidRoot" ]] && rm -rf $androidRoot
mkdir -p $androidRoot

if [ ! -f $toolsFile ]
then
  echo "Downloading SDK tools from '$repository/$toolsFile'"
  wget -q $repository/$toolsFile
  error=$?
  if [[ ! $error -eq 0 ]]; then
    >&2 echo "Error downloading SDK tools!"
    exit $error
  fi
fi

if [ ! -f $ndkFile ]
then
  echo "Downloading NDK from '$repository/$ndkFile'"
  wget -q $repository/$ndkFile
  error=$?
  if [[ ! $error -eq 0 ]]; then
    >&2 echo "Error downloading NDK!"
    exit $error
  fi
fi

echo "Unpacking SDK and NDK into '$androidRoot'"
unzip -qq $toolsFile -d $androidRoot/$toolsFolder && unzip -qq $ndkFile -d $androidRoot
error=$?

if [[ ! $error -eq 0 ]]; then
  >&2 echo "Error unpacking!"
  exit 1
fi

rm $toolsFile
rm $ndkFile

# silence warnings
[[ ! -d ~/.android ]] && mkdir ~/.android
touch ~/.android/repositories.cfg

echo "Configuring environment"
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

#exec su vagrant $0 -- $@

if (! grep "ANDROID_SDK_ROOT" /home/vagrant/.profile)
then
  cp /home/vagrant/.profile /home/vagrant/.profile.backup
  echo "export JAVA_HOME=$JAVA_HOME" >> /home/vagrant/.profile
  echo "export ANDROID_SDK_ROOT=$androidRoot" >> /home/vagrant/.profile
  echo "export PATH=\$PATH:\$JAVA_HOME/bin:\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:\$ANDROID_SDK_ROOT/cmdline-tools/tools/bin" >> /home/vagrant/.profile
  echo "export ANDROID_SDK_HOME=\$ANDROID_SDK_ROOT/$toolsFolder" >> /home/vagrant/.profile
  echo "export ANDROID_NDK_HOME=\$ANDROID_SDK_ROOT/$ndkFolder" >> /home/vagrant/.profile
  echo "export ANDROID_NDK_HOST=$ndkHost" >> /home/vagrant/.profile
  echo "export ANDROID_API_VERSION=$sdkApiLevel" >> /home/vagrant/.profile
fi

. /home/vagrant/.profile

# Optional workaround for issue with certain JDK/JRE versions
#cp $toolsFolder/tools/bin/sdkmanager $toolsFolder/tools/bin/sdkmanager.backup
#sed -i 's/^DEFAULT_JVM_OPTS.*/DEFAULT_JVM_OPTS='"'\"-Dcom.android.sdklib.toolsdir=\$APP_HOME\" -XX:+IgnoreUnrecognizedVMOptions --add-modules java.se.ee'"'/' \
#        $toolsFolder/tools/bin/sdkmanager

echo "Installing SDK packages"
# cd $androidRoot/$toolsFolder/tools/bin
echo "y" | sdkmanager "platforms;$sdkApiLevel" "platform-tools" "build-tools;$sdkBuildToolsVersion" >> sdkmanager.log

echo "SDK installation complete. Here's the list of installed packages:"
sdkmanager --list

echo "... and a list of available targets:"
avdmanager list target
