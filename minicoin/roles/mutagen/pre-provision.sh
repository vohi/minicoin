PLATFORM=windows
ARCH=amd64
VERSION=0.11.5
FILE=mutagen_${PLATFORM}_${ARCH}_v${VERSION}.tar.gz

cd /tmp
echo "Downloading mutagen '$FILE'"
wget -q https://github.com/mutagen-io/mutagen/releases/download/v$VERSION/$FILE
rm -rf mutagen
mkdir mutagen
cd mutagen
tar -xzf ../$FILE 2>&1 > /dev/null

exit 0