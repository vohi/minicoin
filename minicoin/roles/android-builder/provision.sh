if [[ $UID -eq 0 ]]; then
    sed -i 's/us.archive.ubuntu.com/archive.ubuntu.com/' /etc/apt/sources.list
    echo "nameserver 8.8.8.8" | tee /etc/resolv.conf > /dev/null

    apt-get -qq update
    apt-get -q install -y build-essential
    apt-get -q install -y default-jre openjdk-8-jdk-headless
    apt-get -q install -y libc6-i386 libpulse-dev

    cd /home/vagrant
    exec su vagrant $0 -- $@
fi

# the rest of the provisioning is executed as user vagrant
ndkVersion="${PARAM_ndkVersion:-r21d}"
ndkHost="linux-x86_64"
sdkBuildToolsVersion="${PARAM_sdkBuildToolsVersion:-29.0.3}"
sdkApiLevel="${PARAM_sdkApiLevel:-android-29}"

repository="https://dl.google.com/android/repository"
toolsFile="commandlinetools-linux-6609375_latest.zip"
toolsFolder="android-sdk-tools"
ndkFile="android-ndk-$ndkVersion-$ndkHost.zip"
ndkFolder="android-ndk-$ndkVersion"
targetFolder=/home/vagrant

rm -rf $toolsFolder
rm -rf $ndkFolder

echo "Downloading SDK tools from '$repository/$toolsFile'"
wget -q $repository/$toolsFile
error=$?
if [[ ! $error -eq 0 ]]; then
  >&2 echo "Error downloading SDK tools!"
  exit $error
fi

echo "Downloading NDK from '$repository/$ndkFile'"
wget -q $repository/$ndkFile
error=$?
if [[ ! $error -eq 0 ]]; then
  >&2 echo "Error downloading NDK!"
  exit $error
fi

echo "Unpacking SDK and NDK into '$targetFolder'"
unzip -qq $toolsFile -d $targetFolder/$toolsFolder
unzip -qq $ndkFile -d $targetFolder

chown -R vagrant $toolsFolder
chown -R vagrant $ndkFolder

rm $toolsFile
rm $ndkFile

# silence warnings
mkdir ~/.android
touch ~/.android/repositories.cfg

echo "Configuring environment"
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export PATH=$PATH:$JAVA_HOME/bin

cp ~/.profile ~/.profile.backup
echo "export JAVA_HOME=$JAVA_HOME" >> ~/.profile
echo "export PATH=\$PATH:\$JAVA_HOME/bin" >> ~/.profile
echo "export ANDROID_SDK_HOME=$targetFolder/$toolsFolder" >> ~/.profile
echo "export ANDROID_NDK_HOME=$targetFolder/$ndkFolder" >> ~/.profile
echo "export ANDROID_NDK_HOST=$ndkHost" >> ~/.profile
echo "export ANDROID_API_VERSION=$sdkApiLevel" >> ~/.profile

# Optional workaround for issue with certain JDK/JRE versions
#cp $toolsFolder/tools/bin/sdkmanager $toolsFolder/tools/bin/sdkmanager.backup
#sed -i 's/^DEFAULT_JVM_OPTS.*/DEFAULT_JVM_OPTS='"'\"-Dcom.android.sdklib.toolsdir=\$APP_HOME\" -XX:+IgnoreUnrecognizedVMOptions --add-modules java.se.ee'"'/' \
#        $toolsFolder/tools/bin/sdkmanager

echo "Installing SDK packages"
cd $toolsFolder/tools/bin
echo "y" | ./sdkmanager --sdk_root="$targetFolder"/"$toolsFolder" "platforms;$sdkApiLevel" "platform-tools" "build-tools;$sdkBuildToolsVersion" >> sdkmanager.log
