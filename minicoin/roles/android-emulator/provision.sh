apt-get -q install -y qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virt-manager
apt-get -q install -y libstdc++6 libncurses5 # for adb/gdb
apt-get -q install -y libsdl1.2debian # for the emulator

usermod -a -G libvirt vagrant
usermod -a -G kvm vagrant

. /home/vagrant/.profile

if (! which sdkmanager)
then
    >&2 echo "Android SDK Manager not found in PATH"
    exit 1
fi

androidArch="${PARAM_androidArch:-x86_64}"
androidImage="${PARAM_androidImage:-android-31}"

echo "Installing emulator"
echo "y" | sdkmanager --install "emulator" "patcher;v4" >> sdkmanager.log

if (! grep "ANDROID_EMULATOR_HOME" /home/vagrant/.profile)
then
    echo "export ANDROID_EMULATOR_HOME=~/.android" >> /home/vagrant/.profile
    echo "export ANDROID_EMULATOR_IMAGE=${androidImage}-${androidArch}" >> /home/vagrant/.profile
fi

echo "Verifying emulator:"
$ANDROID_SDK_ROOT/emulator/emulator-check accel desktop-env window-mgr
error=$?

if [ $error -gt 0 ]
then
    >&2 echo "Emulator can't run on this machine, aborting installation"
    exit 1
fi

echo "Installing system image '$androidImage' for '$androidArch'"
echo "y" | sdkmanager --install "system-images;$androidImage;google_apis;$androidArch" >> sdkmanager.log

echo "Creating AVD based on '$androidImage' for '$androidArch'"
echo "no" | su -l vagrant -c "avdmanager create avd -n \"${androidImage}-${androidArch}\" -k \"system-images;$androidImage;google_apis;$androidArch\" -c 2048M -f"

echo "Installation of emulator complete, here's a list of Android Virtual Devices:"
su -l vagrant -c "avdmanager list avd"

echo "Starting adb"
su -l vagrant -c "$ANDROID_SDK_ROOT/platform-tools/adb start-server"
echo "Starting emulator"
su -l vagrant -c "$ANDROID_SDK_ROOT/emulator/emulator -avd \"${androidImage}-${androidArch}\" -no-window &> /dev/null &"
while ! $ANDROID_SDK_ROOT/platform-tools/adb devices | grep emulator > /dev/null; do
    sleep 1
done
