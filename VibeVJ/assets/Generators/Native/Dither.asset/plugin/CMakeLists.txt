# The plugin of the native VibeVJ asset Dither on its own (#201): what an asset author needs is this folder and
# core/shizoscript3_core_cabi/include/shz_abi.h. Builds the library into native/<platform>/ next to this file, where
# VibeVJ loads it from (git-ignored: the builds of the repository make it, see the README of the C ABI).
#
#   cmake -S . -B build && cmake --build build --config Release
#   (another place of shz_abi.h: -DSHZ_ABI_INCLUDE=<folder>)

cmake_minimum_required(VERSION 3.16)
project(native_dither C)

set(SHZ_ABI_INCLUDE "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../core/shizoscript3_core_cabi/include" CACHE PATH
	"the folder of shz_abi.h")

if(WIN32)
	set(SHZ_PLATFORM windows_x64)
elseif(APPLE)
	if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64")
		set(SHZ_PLATFORM macos_arm64)
	else()
		set(SHZ_PLATFORM macos_x64)
	endif()
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
	set(SHZ_PLATFORM linux_arm64)
else()
	set(SHZ_PLATFORM linux_x64)
endif()

add_library(native_dither SHARED dither.c)
target_include_directories(native_dither PRIVATE ${SHZ_ABI_INCLUDE})
# $<0:> keeps multi-config generators (Visual Studio, Xcode) from adding a Release/ folder
set(SHZ_NATIVE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/native/${SHZ_PLATFORM}$<0:>)
set_target_properties(native_dither PROPERTIES
	C_STANDARD 99 C_STANDARD_REQUIRED ON C_EXTENSIONS OFF C_VISIBILITY_PRESET hidden
	PREFIX "" OUTPUT_NAME shzmodule_native_dither
	LIBRARY_OUTPUT_DIRECTORY ${SHZ_NATIVE_DIR}
	RUNTIME_OUTPUT_DIRECTORY ${SHZ_NATIVE_DIR}
)
if(APPLE)
	set_target_properties(native_dither PROPERTIES SUFFIX .dylib)
elseif(NOT WIN32)
	# nothing of ShizoScript is needed at link time
	target_link_options(native_dither PRIVATE -Wl,--no-undefined)
	target_link_libraries(native_dither PRIVATE m)
endif()
