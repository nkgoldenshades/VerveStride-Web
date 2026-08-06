# The Flutter Tooling version that was used to create this project.
# Changes to this version should only be made by the 'flutter' command-line tool.
# The value must be kept in sync with the version in the 'pubspec.yaml' file.
set(FLUTTER_VERSION "1.0.0+1")

# The Flutter project name.
# Changes to this name should only be made by the 'flutter' command-line tool.
# The value must be kept in sync with the 'name' in the 'pubspec.yaml' file.
set(BINARY_NAME "vervestride")

cmake_minimum_required(VERSION 3.10)
project(vervestride LANGUAGES CXX)

# The Flutter configuration.
include(flutter/generated_plugins.cmake)

# The application binary.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "my_application.h"
  ${FLUTTER_MANAGED_SOURCES}
)
apply_standard_settings(${BINARY_NAME})
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)
add_dependencies(${BINARY_NAME} flutter_assemble)

# The copy_flutter_assets target.
add_custom_command(
  OUTPUT ${FLUTTER_ASSETS_DIR}
  COMMAND ${CMAKE_COMMAND} -E copy_directory
  "${PROJECT_SOURCE_DIR}/../build/flutter_assets"
  "${FLUTTER_ASSETS_DIR}"
  DEPENDS flutter_assemble
)
add_custom_target(copy_flutter_assets ALL DEPENDS ${FLUTTER_ASSETS_DIR})
add_dependencies(${BINARY_NAME} copy_flutter_assets)

set(APPLICATION_ID "com.example.vervestride")
