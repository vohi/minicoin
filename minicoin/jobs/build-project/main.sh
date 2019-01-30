export PATH=$PATH:~/qt5-build/qtbase/bin

if [[ $1 == "" ]]; then
  echo "No project specified"
  exit 1
fi

echo "Building project in $1"

cd $1
qmake
make clean
make