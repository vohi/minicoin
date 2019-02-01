export PATH=$PATH:~/qt5-build/qtbase/bin

if [[ $1 == "" ]]; then
  echo "No project specified"
  exit 1
fi

echo "Building project in $1"

project=$(basename $1)
cd $HOME
mkdir $project > /dev/null

cd $project
qmake $1
make clean
make