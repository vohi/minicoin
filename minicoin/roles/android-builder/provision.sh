if [[ $UID -eq 0 ]]; then
    sed -i 's/us.archive.ubuntu.com/archive.ubuntu.com/' /etc/apt/sources.list
    echo "nameserver 8.8.8.8" | tee /etc/resolv.conf > /dev/null

    apt-get -qq update
    apt-get -q install -y build-essential
    apt-get -q install -y default-jre openjdk-8-jdk-headless
    apt-get -q install -y android-sdk android-sdk-platform-23
    apt-get -q install -y libc6-i386 libpulse-dev
    apt-get -q install -y qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virt-manager

    usermod -a -G libvirt vagrant
    usermod -a -G kvm vagrant

    cd /home/vagrant
    exec su vagrant $0 -- $@
fi

# the rest of the provisioning is executed as user vagrant
ndkVersion="r18b"
ndkHost="linux-x86_64"
ndkToolchainVersion="4.9"
sdkBuildToolsVersion="28.0.3"
sdkApiLevel="android-28"
android_arch="x86"
android_image="android-21"

repository=https://dl.google.com/android/repository
toolsFile=sdk-tools-linux-4333796.zip
toolsFolder=android-sdk-tools
ndkFile=android-ndk-$ndkVersion-$ndkHost.zip
ndkFolder=android-ndk-$ndkVersion
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

cp ~/.bashrc ~/.bashrc.backup
echo "export JAVA_HOME=$JAVA_HOME" >> ~/.bashrc
echo "export PATH=\$PATH:\$JAVA_HOME/bin" >> ~/.bashrc
echo "export ANDROID_SDK_HOME=$targetFolder/$toolsFolder" >> ~/.bashrc
echo "export ANDROID_NDK_HOME=$targetFolder/$ndkFolder" >> ~/.bashrc
echo "export ANDROID_NDK_HOST=$ndkHost" >> ~/.bashrc
echo "export ANDROID_API_VERSION=$sdkApiLevel" >> ~/.bashrc

# Optional workaround for issue with certain JDK/JRE versions
#cp $toolsFolder/tools/bin/sdkmanager $toolsFolder/tools/bin/sdkmanager.backup
#sed -i 's/^DEFAULT_JVM_OPTS.*/DEFAULT_JVM_OPTS='"'\"-Dcom.android.sdklib.toolsdir=\$APP_HOME\" -XX:+IgnoreUnrecognizedVMOptions --add-modules java.se.ee'"'/' \
#        $toolsFolder/tools/bin/sdkmanager

echo "Installing SDK packages"
cd $toolsFolder/tools/bin
echo "y" | ./sdkmanager "platforms;$sdkApiLevel" "platform-tools" "build-tools;$sdkBuildToolsVersion" >> sdkmanager.log
echo "y" | ./sdkmanager --install "emulator" >> sdkmanager.log
echo "y" | ./sdkmanager --install "system-images;$android_image;google_apis;$android_arch" >> sdkmanager.log
# echo "y" | ./sdkmanager --install "add-ons;addon-google_apis-google-21" >> sdkmanager.log
# echo "y" | ./sdkmanager --install "extras;android;m2repository" >> sdkmanager.log
# echo "y" | ./sdkmanager --install "extras;google;m2repository" >> sdkmanager.log
echo "no" | ./avdmanager create avd -n $android_arch"emulator" -k "system-images;$android_image;google_apis;$android_arch" -c 2048M -f >> sdkmanager.log

echo "Provisioning complete. Here's the list of packages and avd devices:"
./sdkmanager --list
./avdmanager list avd
echo "Verifying emulator:"
cd ..
./emulator-check accel

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
    $targetFolder/$toolsFolder \
    -android-ndk-host \
    $ndkHost \
    -android-arch \
    $android_arch \
    -android-toolchain-version \
    $ndkToolchainVersion \
    -skip \
    qttranslations \
    -skip \
    qtserialport \
    -no-dbus \
    -no-warnings-are-errors \
    -opengl es2 \
    -no-use-gold-linker \
    -no-qpa-platform-guard \
    -opensource \
    -developer-build \
    -confirm-license > ~/$1-config.opt

ln -fs ~/$1-config.opt ~/config.opt