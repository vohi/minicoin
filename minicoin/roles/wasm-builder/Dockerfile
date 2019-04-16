FROM trzeci/emscripten AS qtbuilder
 
RUN mkdir -p /development/qt5-build
ARG qt_version
WORKDIR /development

RUN git clone --branch=$qt_version git://code.qt.io/qt/qt5.git

WORKDIR /development/qt5

RUN ./init-repository -module-subset=essential

WORKDIR /development/qt5_build

RUN /development/qt5/configure -opensource --confirm-license \
    -xplatform wasm-emscripten -nomake examples -nomake tests \
    -prefix /usr/local/Qt-$qt_version \
    && make && make install

FROM trzeci/emscripten AS userbuild

ARG qt_version
COPY --from=qtbuilder /usr/local/Qt-$qt_version/ /usr/local/Qt-$qt_version/
ENV PATH="/usr/local/Qt-$qt_version/bin:${PATH}"

WORKDIR /project/build
CMD qmake /project/source && make