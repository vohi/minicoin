#!/bin/bash
cd $(dirname "$0")

rm -rf coin

git clone --single-branch --branch dev --depth 1 git://code.qt.io/qt/qt5.git

mv qt5/coin coin
rm -rf qt5
