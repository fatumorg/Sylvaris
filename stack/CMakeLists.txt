cmake_minimum_required(VERSION 3.21)
project(sylstack VERSION 1.0.1 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)

find_package(Qt6 6.9 REQUIRED COMPONENTS Core Gui Qml Quick DBus WaylandClient)
find_package(Qt6 6.9 REQUIRED COMPONENTS GuiPrivate WaylandClientPrivate)
find_package(LayerShellQt REQUIRED)
find_package(PolkitQt6-1 REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(DEPS REQUIRED IMPORTED_TARGET libpipewire-0.3 wayland-client pam)

qt_standard_project_setup(REQUIRES 6.9)

qt_add_executable(sylstack
    src/main.cpp
)

qt_add_qml_module(sylstack
    URI SylStack
    VERSION 1.0
    OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/qml/SylStack
    SOURCES
        src/model.h
        src/stack.h src/stack.cpp
        src/scope.h src/scope.cpp
        src/window.h src/window.cpp
        src/io.h src/io.cpp
        src/desktop.h src/desktop.cpp
        src/toplevel.h src/toplevel.cpp
        src/screencopy.h src/screencopy.cpp
        src/lock.h src/lock.cpp
        src/hyprland.h src/hyprland.cpp
        src/i3.h src/i3.cpp
        src/pipewire.h src/pipewire.cpp
        src/upower.h src/upower.cpp
        src/notifications.h src/notifications.cpp
        src/mpris.h src/mpris.cpp
        src/tray.h src/tray.cpp
        src/polkit.h src/polkit.cpp
        src/pam.h src/pam.cpp
        src/greetd.h src/greetd.cpp
        src/networking.h src/networking.cpp
        src/bluetooth.h src/bluetooth.cpp
    QML_FILES
        qml/FileView.qml
        qml/IconImage.qml
)

qt6_generate_wayland_protocol_client_sources(sylstack FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/protocols/ext-session-lock-v1.xml
    ${CMAKE_CURRENT_SOURCE_DIR}/protocols/ext-background-effect-v1.xml
    ${CMAKE_CURRENT_SOURCE_DIR}/protocols/idle-inhibit-unstable-v1.xml
    ${CMAKE_CURRENT_SOURCE_DIR}/protocols/ext-foreign-toplevel-list-v1.xml
    ${CMAKE_CURRENT_SOURCE_DIR}/protocols/wlr-foreign-toplevel-management-unstable-v1.xml
    ${CMAKE_CURRENT_SOURCE_DIR}/protocols/hyprland-toplevel-export-v1.xml
    ${CMAKE_CURRENT_SOURCE_DIR}/protocols/hyprland-toplevel-mapping-v1.xml
)

target_include_directories(sylstack PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_compile_definitions(sylstack PRIVATE SYLSTACK_VERSION="${PROJECT_VERSION}")
target_link_libraries(sylstack PRIVATE
    Qt6::Quick
    Qt6::DBus
    Qt6::GuiPrivate
    Qt6::WaylandClient
    Qt6::WaylandClientPrivate
    LayerShellQt::Interface
    PolkitQt6-1::Agent
    PkgConfig::DEPS
)

include(GNUInstallDirs)
install(TARGETS sylstack RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/qml/SylStack/qmldir
    ${CMAKE_CURRENT_BINARY_DIR}/qml/SylStack/sylstack.qmltypes
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt-6/qml/SylStack)
install(FILES qml/FileView.qml qml/IconImage.qml DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt-6/qml/SylStack/qml)
