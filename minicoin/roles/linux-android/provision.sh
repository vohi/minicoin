if [[ $UID -eq 0 ]]; then
    sed -i 's/us.archive.ubuntu.com/archive.ubuntu.com/' /etc/apt/sources.list
    echo "nameserver 8.8.8.8" | tee /etc/resolv.conf > /dev/null

    apt-get -q update
    apt-get -q install -y build-essential
    apt-get -q install -y default-jre openjdk-8-jdk-headless
    apt-get -q install -y android-sdk android-sdk-platform-23
    apt-get -q install -y libc6-i386

    cd /home/vagrant
    exec su vagrant $0 -- $@
fi

# the rest of the provisioning is executed as user vagrant
ndkVersion="r18b"
ndkHost="linux-x86_64"
sdkBuildToolsVersion="28.0.3"
sdkApiLevel="android-28"

repository=https://dl.google.com/android/repository
toolsFile=sdk-tools-linux-4333796.zip
toolsFolder=android-sdk-tools
ndkFile=android-ndk-$ndkVersion-$ndkHost.zip
ndkFolder=android-ndk-$ndkVersion
targetFolder=/home/vagrant

rm -rf $toolsFolder
rm -rf $ndkFolder

echo "Downloading SDK tools from $repository"
wget -q $repository/$toolsFile
unzip -qq $toolsFile -d $targetFolder/$toolsFolder

echo "Downloading NDK from $repository"
wget -q $repository/$ndkFile
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

cp /home/vagrant/.bashrc /home/vagrant/.bashrc.backup
echo "export JAVA_HOME=$JAVA_HOME" >> /home/vagrant/.bashrc
echo "export PATH=\$PATH:\$JAVA_HOME/bin" >> /home/vagrant/.bashrc
echo "export ANDROID_SDK_HOME=$targetFolder/$toolsFolder/tools" >> /home/vagrant/.bashrc
echo "export ANDROID_NDK_HOME=$targetFolder/$ndkFolder" >> /home/vagrant/.bashrc
echo "export ANDROID_NDK_HOST=$ndkHost" >> /home/vagrant/.bashrc
echo "export ANDROID_API_VERSION=$sdkApiLevel" >> /home/vagrant/.bashrc

# Optional workaround for issue with certain JDK/JRE versions
#cp $toolsFolder/tools/bin/sdkmanager $toolsFolder/tools/bin/sdkmanager.backup
#sed -i 's/^DEFAULT_JVM_OPTS.*/DEFAULT_JVM_OPTS='"'\"-Dcom.android.sdklib.toolsdir=\$APP_HOME\" -XX:+IgnoreUnrecognizedVMOptions --add-modules java.se.ee'"'/' \
#        $toolsFolder/tools/bin/sdkmanager

echo "Installing SDK packages"
cd $toolsFolder/tools/bin
echo "y" | ./sdkmanager "platforms;$sdkApiLevel" "platform-tools" "build-tools;$sdkBuildToolsVersion" >> sdkmanager.log
echo "y" | ./sdkmanager --install "emulator" >> sdkmanager.log
echo "y" | ./sdkmanager --install "system-images;android-21;google_apis;x86" >> sdkmanager.log
# echo "y" | ./sdkmanager --install "add-ons;addon-google_apis-google-21" >> sdkmanager.log
# echo "y" | ./sdkmanager --install "extras;android;m2repository" >> sdkmanager.log
# echo "y" | ./sdkmanager --install "extras;google;m2repository" >> sdkmanager.log
echo "no" | ./avdmanager create avd -n x86emulator -k "system-images;android-21;google_apis;x86" -c 2048M -f >> sdkmanager.log

echo "Provisioning complete. Here's the list of packages and avd devices:"
./sdkmanager --list
./avdmanager list avd

printf "%s\n" \
    -xplatform \
    android-clang \
    --disable-rpath \
    -nomake \
    tests \
    -nomake \
    examples \
    -android-ndk \
    $targetFolder/$ndkFolder \
    -android-sdk \
    /usr/lib/android-sdk \
    -android-ndk-host \
    $ndkHost \
    -android-toolchain-version \
    4.9 \
    -skip \
    qttranslations \
    -skip \
    qtserialport \
    -no-warnings-are-errors \
    -opensource \
    -confirm-license > ~/$1-config.opt

ln -fs ~/$1-config.opt ~/config.opt