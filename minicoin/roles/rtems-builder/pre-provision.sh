set +ex

mkdir -p ~/rtems/tqtc-qt5
cd ~/rtems
$(git clone git@git.qt.io:mikhail.svetkin/qt-rtems-apps.git)

if [[ ! -d "qt-rtems-apps" ]]; then
  echo "Failed to clone apps repository!"
  exit 1
fi

if [[ "$(uname)" == "Darwin" ]]; then
  $(brew install stlink)
fi

if [[ "$(which st-flash)" == "" ]]; then
  echo "Failed to install st-flash"
  exit 2
fi