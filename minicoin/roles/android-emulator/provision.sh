apt-get -q install -y qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virt-manager

usermod -a -G libvirt vagrant
usermod -a -G kvm vagrant

. /home/vagrant/.profile

if (! which sdkmanager)
then
    >&2 echo "Android SDK Manager not found in PATH"
    exit 1
fi

androidArch="${PARAM_androidArch:-x86}"
androidImage="${PARAM_androidImage:-android-23}"

echo "Installing emulator"
echo "y" | sdkmanager --install "emulator" >> sdkmanager.log

echo "Verifying emulator:"
$ANDROID_SDK_ROOT/emulator/emulator-check accel
error=$?

if [ $error -gt 0 ]
then
    >&2 echo "Emulator can't run on this machine, aborting installation"
    exit 1
fi

echo "Installing system image '$androidImage' for '$androidArch'"
echo "y" | sdkmanager --install "system-images;$androidImage;google_apis;$androidArch" >> sdkmanager.log

echo "Creating AVD based on '$androidImage' for '$androidArch'"
echo "no" | avdmanager create avd -n $androidArch"emulator" -k "system-images;$androidImage;google_apis;$androidArch" -c 2048M -f >> sdkmanager.log

echo "Installation of emulator complete, here's a list of Android Virtual Devices:"
avdmanager list avd

echo "Starting adb"
$ANDROID_SDK_ROOT/platform-tools/adb start-server
echo "Starting windowless emulator"
$ANDROID_SDK_ROOT/emulator/emulator -avd $androidArch"emulator" -no-window &
