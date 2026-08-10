cmake_minimum_required(VERSION 3.16)
project(WaypointRoute LANGUAGES CXX)

# ------------------------------------------------------------------
# safetyhook (thư viện phụ thuộc bên trong plugin-sdk) dùng std::expected,
# tính năng CHỈ CÓ TỪ C++23 trở lên — đây là lỗi đã biết, nhiều người dùng
# plugin-sdk khác cũng gặp (xem GitHub issue #201 của DK22Pac/plugin-sdk).
# C++20 KHÔNG đủ, bắt buộc phải C++23.
# ------------------------------------------------------------------
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(MSVC)
    add_compile_options(/std:c++latest /Zc:__cplusplus)
endif()

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
# plugin-sdk có rất nhiều header nằm rải rác nhiều thư mục con lồng nhau,
# và các header include lẫn nhau bằng đường dẫn tương đối ngắn (ví dụ
# #include "eWeaponType.h") mà không phải lúc nào cũng ở cùng thư mục.
# Thay vì liệt kê thủ công từng thư mục (dễ thiếu, gây lỗi liên tiếp),
# ta QUÉT TỰ ĐỘNG mọi thư mục con có chứa file .h/.hpp và thêm hết vào
# include path — đảm bảo mọi include tương đối đều tìm được.
# ------------------------------------------------------------------
file(GLOB_RECURSE ALL_SDK_HEADERS
    "${plugin_sdk_SOURCE_DIR}/*.h"
    "${plugin_sdk_SOURCE_DIR}/*.hpp"
)

set(SDK_INCLUDE_DIRS "")
foreach(HEADER_FILE ${ALL_SDK_HEADERS})
    get_filename_component(HEADER_DIR ${HEADER_FILE} DIRECTORY)
    list(APPEND SDK_INCLUDE_DIRS ${HEADER_DIR})
endforeach()
list(REMOVE_DUPLICATES SDK_INCLUDE_DIRS)

target_include_directories(WaypointRoute PRIVATE ${SDK_INCLUDE_DIRS})
