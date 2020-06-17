FROM trzeci/emscripten AS qtbuilder
 
RUN mkdir -p /development/qt5-build
ARG qt_version=5.13
WORKDIR /development

RUN echo "Cloning Qt branch $qt_version..."
RUN git clone --branch=$qt_version git://code.qt.io/qt/qt5.git

WORKDIR /development/qt5

RUN ./init-repository

WORKDIR /development/qt5_build

RUN /development/qt5/configure -opensource --confirm-license \
    -xplatform wasm-emscripten -nomake examples -nomake tests \
    -prefix /usr/local/Qt-$qt_version \
    && make && make install

FROM trzeci/emscripten AS userbuild

ARG qt_version=5.13
RUN echo "Installing Qt $qt_version on userbuild image"
COPY --from=qtbuilder /usr/local/Qt-$qt_version/ /usr/local/Qt-$qt_version/
ENV PATH="/usr/local/Qt-$qt_version/bin:${PATH}"
RUN echo "PATH=$PATH"
RUN ls /usr/local/Qt-$qt_version/bin

WORKDIR /project/build
CMD ls /usr/local/Qt-5.13 && /usr/local/Qt-5.13/bin/qmake /project/source && make
