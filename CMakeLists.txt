cmake_minimum_required(VERSION 3.16)
project(WaypointRoute LANGUAGES CXX)

# ------------------------------------------------------------------
# Bắt buộc build 32-bit (Win32) vì GTA San Andreas là game 32-bit.
# ------------------------------------------------------------------
if(NOT CMAKE_GENERATOR_PLATFORM STREQUAL "Win32" AND NOT CMAKE_VS_PLATFORM_NAME STREQUAL "Win32")
    message(WARNING "Du an nay can build o Win32 (x86), khong phai x64.")
endif()

# ------------------------------------------------------------------
# Tự động tải plugin-sdk (DK22Pac/plugin-sdk) về lúc configure,
# không cần bạn tải thủ công.
# ------------------------------------------------------------------
include(FetchContent)
FetchContent_Declare(
    plugin_sdk
    GIT_REPOSITORY https://github.com/DK22Pac/plugin-sdk.git
    GIT_SHALLOW    TRUE
)
FetchContent_MakeAvailable(plugin_sdk)

# ------------------------------------------------------------------
# Target chính: build ra file .dll nhưng đặt tên đuôi thẳng thành .asi
# ------------------------------------------------------------------
add_library(WaypointRoute MODULE
    src/WaypointRoute.cpp
)

set_target_properties(WaypointRoute PROPERTIES
    SUFFIX ".asi"
    OUTPUT_NAME "WaypointRoute"
)

target_compile_definitions(WaypointRoute PRIVATE GTASA)

# ------------------------------------------------------------------
# Liên kết với thư viện game_sa của plugin-sdk (chứa CPed, CVehicle,...)
# Tên target có thể khác nhau tuỳ version plugin-sdk; nếu CMake báo lỗi
# "target không tồn tại" ở dòng dưới, xem log lỗi để biết tên đúng.
# ------------------------------------------------------------------
if(TARGET game_sa)
    target_link_libraries(WaypointRoute PRIVATE game_sa)
elseif(TARGET plugin_sa)
    target_link_libraries(WaypointRoute PRIVATE plugin_sa)
endif()

target_include_directories(WaypointRoute PRIVATE
    ${plugin_sdk_SOURCE_DIR}
    ${plugin_sdk_SOURCE_DIR}/plugin_sa
    ${plugin_sdk_SOURCE_DIR}/shared
)
