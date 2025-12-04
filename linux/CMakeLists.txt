cmake_minimum_required(VERSION 3.10)
project(runner LANGUAGES CXX)

set(BINARY_NAME "smart_calendar")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

apply_standard_settings(${BINARY_NAME})
set_target_properties(${BINARY_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET "${VISIBILITY_HIDDEN}"
)

target_compile_definitions(${BINARY_NAME} PRIVATE "APPLICATION_ID=\"com.smartcalendar.app\"")

target_include_directories(${BINARY_NAME} PRIVATE
  "${FLUTTER_MANAGED_DIR}"
)

target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

list(APPEND PLUGIN_BUNDLED_LIBRARIES)

link_plugin_libraries(${BINARY_NAME})

