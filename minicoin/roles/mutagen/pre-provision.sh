PLATFORM=windows
ARCH=amd64
VERSION=0.11.5
FILE=mutagen_${PLATFORM}_${ARCH}_v${VERSION}.tar.gz

if [ -f "/tmp/mutagen.tar.gz" ]
then
    echo "Downloading mutagen package: '$FILE'"
    wget -q https://github.com/mutagen-io/mutagen/releases/download/v$VERSION/$FILE -O /tmp/mutagen.tar.gz
fi

exit 0