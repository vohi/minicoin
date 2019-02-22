POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --docker-password)
      DOCKERPWD="$2"
      shift
      shift
      ;;
    --docker-user)
      DOCKERUSR="$2"
      shift
      shift
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

apt-get -y install docker.io
docker login -u $DOCKERUSR -p $DOCKERPWD

# prevent interruption of firmware update
systemctl disable ModemManager.service

sandbox=/home/builder/qt-rtems-port

docker run \
    -v /home/host/rtems/tqtc-qt5:/home/builder/qt-rtems-port/tqtc-qt5 \
    -v /home/host/rtems/qt-rtems-apps:/home/builder/qt-rtems-port/qt-rtems-apps \
    -e sandbox=$sandbox \
    tqtc/qt-on-mcu ./build_qt5.sh
