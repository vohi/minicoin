set(installer_version "4.0.1")
if (WIN32)
  set(installer_file_os "windows-x86")
  set(installer_file_ext "exe")
  set(maintenance_tool_ext ".exe")
  set(qt_package_arch "win64_msvc2019_64")
elseif(APPLE)
  set(installer_file_os "mac-x64")
  set(installer_file_ext "dmg")
  set(maintenance_tool_ext ".app/Contents/MacOS/MaintenanceTool")
  set(qt_package_arch "clang_64")
else()
  set(installer_file_os "linux-x64")
  set(installer_file_ext "run")
  set(maintenance_tool_ext "")
  set(qt_package_arch "gcc_64")
endif()

set(INSTALL_ARGS --accept-licenses --auto-answer telemetry-question=No,AssociateCommonFiletypes=No,OverwriteTargetDirectory=Yes,installationErrorWithCancel=Ignore --confirm-command)

if (NOT INSTALL_ROOT)
  set(INSTALL_ROOT "Qt")
endif()
set(INSTALL_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/${INSTALL_ROOT})

set(maintenance_tool_file "${INSTALL_ROOT}/MaintenanceTool${maintenance_tool_ext}")

if(NOT EXISTS "${maintenance_tool_file}") # maintenance tool not present, install basics
  set(installer_file_base "qt-unified-${installer_file_os}-online")
  set(installer_source "official_releases")

  set(qt_base_url "http://download.qt.io/${installer_source}/online_installers")
  set(installer_file ${installer_file_base}.${installer_file_ext})

  if(DEFINED ENV{TEMP})
    set(TMPDIR $ENV{TEMP})
  else()
    set(TMPDIR "/tmp")
  endif()

  message(STATUS "Downloading ${installer_file} from ${qt_base_url} to ${TMPDIR}/${installer_file}")
  file(DOWNLOAD "${qt_base_url}/${installer_file}" ${TMPDIR}/${installer_file} SHOW_PROGRESS)
  file(COPY ${TMPDIR}/${installer_file} DESTINATION . FILE_PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ)
  file(REMOVE ${TMPDIR}/${installer_file})

  if(APPLE)
    execute_process(
      COMMAND
        bash -c "hdiutil attach ${installer_file} | grep /Volumes | awk '{print \$3}'"
      OUTPUT_VARIABLE
        installer_file
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    string(REPLACE "/Volumes/" "" installer_file_base "${installer_file}")
    set(installer_file "/Volumes/${installer_file_base}/${installer_file_base}.app/Contents/MacOS/${installer_file_base}")
  else()
    set(installer_file "./${installer_file}")
  endif()

  if(NOT INITIAL_PACKAGES)
    set(INITIAL_PACKAGES
      qt.tools.qtcreator
      qt.tools.cmake
      qt.tools.ninja
  )
  endif()
  if(NOT EXTRA_INSTALL_ARGS)
    set(EXTRA_INSTALL_ARGS "--no-default-installations")
  endif()

  set(command
    ${installer_file} install ${INITIAL_PACKAGES}
    --root
    "${INSTALL_ROOT}"
    ${INSTALL_ARGS}
    ${EXTRA_INSTALL_ARGS}
  )

  message(STATUS "Running Qt online installer")
  execute_process(
    COMMAND ${command}
    COMMAND_ECHO STDOUT
  )

  if(APPLE)
    execute_process(COMMAND hdiutil detach /Volumes/${installer_file_base})
  endif()
endif()

if(NOT EXISTS "${maintenance_tool_file}")
  message(FATAL_ERROR "Installation failed, ${maintenance_tool_file} not found")
endif()

if (SEARCH)
  message(STATUS "Searching packages matching ${SEARCH}")
  execute_process(
    COMMAND
      "${maintenance_tool_file}" search ${SEARCH}
    RESULT_VARIABLE
      exitcode
    COMMAND_ECHO STDOUT
  )
  return()
endif()

set(exitcode 0)
if(NOT PACKAGE)
  set(PACKAGE "qt.qt6.620")
endif()

message(STATUS "Updating tools in ${maintenance_tool_file}")

execute_process(
  COMMAND
    "${maintenance_tool_file}" update qt.tools
  RESULT_VARIABLE
    exitcode
)

message(STATUS "Installing ${PACKAGE}")

execute_process(
  COMMAND
    "${maintenance_tool_file}" install ${PACKAGE} --root "${INSTALL_ROOT}" ${INSTALL_ARGS}
  RESULT_VARIABLE
    exitcode
  COMMAND_ECHO STDOUT
)

message(DEBUG "Maintenance tool exited with ${exitcode}")

if(exitcode)
  message(FATAL_ERROR "Installation of ${PACKAGE} failed with error ${exitcode}")
endif()
