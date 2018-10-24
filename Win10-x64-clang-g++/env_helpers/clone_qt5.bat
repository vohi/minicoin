mkdir \dev
cd \dev
git clone git://code.qt.io/qt/qt5
REM add your codereview user name below:
REM perl init-repository --codereview-username YOURNAME

cd qt5
REM git submodule foreach "git fetch; git checkout dev; echo done"
