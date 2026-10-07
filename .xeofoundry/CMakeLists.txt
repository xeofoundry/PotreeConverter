cmake_minimum_required(VERSION 3.16)
set(CMAKE_SUPPRESS_REGENERATION true)

project(PotreeConverter LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(CMAKE_BUILD_TYPE "Release" CACHE STRING "" FORCE)

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)

set(POTREE_CONVERTER_VERSION "v2.1.6" CACHE STRING "Release version stamped beside the built executable")
file(WRITE "${CMAKE_BINARY_DIR}/VERSION" "${POTREE_CONVERTER_VERSION}\n")

set(HEADER_FILES
	${REPO_ROOT}/Converter/include/Attributes.h
	${REPO_ROOT}/Converter/include/chunker_countsort_laszip.h
	${REPO_ROOT}/Converter/include/ChunkRefiner.h
	${REPO_ROOT}/Converter/include/ConcurrentWriter.h
	${REPO_ROOT}/Converter/include/converter_utils.h
	${REPO_ROOT}/Converter/include/indexer.h
	${REPO_ROOT}/Converter/include/prototyping.h
	${REPO_ROOT}/Converter/include/sampler_poisson.h
	${REPO_ROOT}/Converter/include/sampler_random.h
	${REPO_ROOT}/Converter/include/structures.h
	${REPO_ROOT}/Converter/include/Vector3.h
	${REPO_ROOT}/Converter/include/PotreeConverter.h
	${REPO_ROOT}/Converter/include/logger.h
	${REPO_ROOT}/Converter/modules/LasLoader/LasLoader.h
	${REPO_ROOT}/Converter/modules/helpers/helpers.hpp
)

add_executable(PotreeConverter
	${REPO_ROOT}/Converter/src/chunker_countsort_laszip.cpp
	${REPO_ROOT}/Converter/src/indexer.cpp
	${REPO_ROOT}/Converter/src/main.cpp
	${REPO_ROOT}/Converter/src/logger.cpp
	${REPO_ROOT}/Converter/src/VBuffer.cpp
	${REPO_ROOT}/Converter/src/Writer.cpp
	${REPO_ROOT}/Converter/modules/LasLoader/LasLoader.cpp
	${REPO_ROOT}/Converter/modules/helpers/helpers_platform_specific.cpp
	${HEADER_FILES}
)

set(LASZIP_DIR "${REPO_ROOT}/Converter/libs/laszip")
set(BROTLI_DIR "${REPO_ROOT}/Converter/libs/brotli")
set(JSON_DIR "${REPO_ROOT}/Converter/libs/json")

add_subdirectory(${LASZIP_DIR} ${CMAKE_BINARY_DIR}/laszip)

set(SAVED_POLICY_VERSION_MINIMUM "${CMAKE_POLICY_VERSION_MINIMUM}")
set(CMAKE_POLICY_VERSION_MINIMUM 3.5)
add_subdirectory(${BROTLI_DIR} ${CMAKE_BINARY_DIR}/brotli)
set(CMAKE_POLICY_VERSION_MINIMUM "${SAVED_POLICY_VERSION_MINIMUM}")

target_link_libraries(PotreeConverter laszip)
target_link_libraries(PotreeConverter brotlienc-static)
target_link_libraries(PotreeConverter brotlidec-static)

target_include_directories(PotreeConverter PRIVATE "${REPO_ROOT}/Converter/include")
target_include_directories(PotreeConverter PRIVATE "${REPO_ROOT}/Converter/modules")
target_include_directories(PotreeConverter PRIVATE "${REPO_ROOT}/Converter/libs")

if (NOT WIN32)
	find_package(Threads REQUIRED)
	find_package(TBB REQUIRED)

	target_link_libraries(PotreeConverter Threads::Threads)
	target_link_libraries(PotreeConverter TBB::tbb)

	if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
		target_compile_options(PotreeConverter PRIVATE -stdlib=libstdc++ -Wno-c++11-narrowing)
	endif()
else()
	if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
		target_compile_options(PotreeConverter PRIVATE -Wno-c++11-narrowing)
	endif()
endif()

add_custom_command(
	TARGET PotreeConverter POST_BUILD
	COMMAND ${CMAKE_COMMAND} -E copy_directory
		${REPO_ROOT}/resources/page_template
		$<TARGET_FILE_DIR:PotreeConverter>/resources/page_template)

add_custom_command(
	TARGET PotreeConverter POST_BUILD
	COMMAND ${CMAKE_COMMAND} -E copy
		${LASZIP_DIR}/COPYING
		$<TARGET_FILE_DIR:PotreeConverter>/licenses/license_laszip.txt)

add_custom_command(
	TARGET PotreeConverter POST_BUILD
	COMMAND ${CMAKE_COMMAND} -E copy
		${BROTLI_DIR}/LICENSE
		$<TARGET_FILE_DIR:PotreeConverter>/licenses/license_brotli.txt)

add_custom_command(
	TARGET PotreeConverter POST_BUILD
	COMMAND ${CMAKE_COMMAND} -E copy
		${JSON_DIR}/LICENSE
		$<TARGET_FILE_DIR:PotreeConverter>/licenses/license_json.txt)

add_custom_command(
	TARGET PotreeConverter POST_BUILD
	COMMAND ${CMAKE_COMMAND} -E copy
		${REPO_ROOT}/LICENSE
		$<TARGET_FILE_DIR:PotreeConverter>/licenses/license_potree_converter.txt)

add_custom_command(
	TARGET PotreeConverter POST_BUILD
	COMMAND ${CMAKE_COMMAND} -E copy
		${REPO_ROOT}/README.md
		$<TARGET_FILE_DIR:PotreeConverter>/README.md)
