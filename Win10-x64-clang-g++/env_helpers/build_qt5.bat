@call msvc_2017_amd64_cmd.bat
cd c:\dev
mkdir qt5-build
cd qt5-build
..\qt5\configure -confirm-license -opensource -developer-build -nomake examples -nomake tests
jom
cmd /k
