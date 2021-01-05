@echo off
mkdir \dev
cd \dev
git clone git://code.qt.io/qt/qt5
cd qt5

REM add your codereview user name below:
REM perl init-repository --codereview-username YOURNAME
perl init-repository --module-subset=default,-qtwebkit,-qtwebkit-examples,-qtwebengine,-qt3d
REM git submodule foreach "git fetch; git checkout dev; echo done"
