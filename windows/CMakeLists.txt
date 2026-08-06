# The Flutter Tooling version that was used to create this project.
# Changes to this version should only be made by the 'flutter' command-line tool.
# The value must be kept in sync with the version in the 'pubspec.yaml' file.
set(FLUTTER_VERSION "1.0.0+1")

# The Flutter project name.
# Changes to this name should only be made by the 'flutter' command-line tool.
# The value must be kept in sync with the 'name' in the 'pubspec.yaml' file.
set(BINARY_NAME "vervestride")

cmake_minimum_required(VERSION 3.14)
project(vervestride LANGUAGES CXX)

# The Flutter configuration.
include(flutter/generated_plugins.cmake)

# The application executable.
add_executable(${BINARY_NAME}
  "runner/main.cpp"
  "runner/utils.cpp"
  "runner/win32_window.cpp"
  "runner/flutter_window.cpp"
  "runner/Runner.rc"
  "runner/resources/utils.cpp"
  "runner/resources/win32_window.cpp"
  "runner/resources/flutter_window.cpp"
  "runner/resources/Runner.rc"
  ${FLUTTER_MANAGED_SOURCES}
)
apply_standard_settings(${BINARY_NAME})
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE ${FLUTTER_LIBRARY})
add_dependencies(${BINARY_NAME} flutter_assemble)

# Standardize the resource compiler's search path.
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

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
