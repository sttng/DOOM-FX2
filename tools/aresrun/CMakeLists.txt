# ares-headless; tools/aresrun/build.sh copies this into <ares>/headless
add_executable(ares-headless main.cpp)
target_include_directories(ares-headless PRIVATE ${CMAKE_SOURCE_DIR} ${CMAKE_SOURCE_DIR}/thirdparty)
target_link_libraries(ares-headless PRIVATE ares::ares ares::mia ares::nall)
target_compile_definitions(ares-headless PRIVATE MIA_LIBRARY)
target_include_directories(ares-headless PRIVATE ${CMAKE_BINARY_DIR}/mia ${CMAKE_BINARY_DIR})
