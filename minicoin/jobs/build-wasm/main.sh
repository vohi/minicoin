if [[ $1 == "" ]]; then
  echo "No project specified"
  exit 1
fi

project=$(basename $1)
builder=qtbuilder/wasm:latest

if [[ ! -z $2 ]]; then
  builder=$2
fi

echo "Building project in $1"

docker run --rm -v $1:/project/source -v /home/host/$project:/project/build $builder