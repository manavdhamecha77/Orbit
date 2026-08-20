cmake_minimum_required(VERSION 3.22.1)
project("offline-ai" LANGUAGES C CXX)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(LLAMA_SRC "${CMAKE_CURRENT_LIST_DIR}/../../../../../llama.cpp")
set(AI_CHAT_SRC "${LLAMA_SRC}/examples/llama.android/lib/src/main/cpp/ai_chat.cpp")
if(ANDROID_ABI STREQUAL "arm64-v8a")
    set(GGML_SYSTEM_ARCH ARM)
    set(GGML_CPU_KLEIDIAI ON)
    set(GGML_OPENMP ON)
    add_subdirectory("${LLAMA_SRC}" "llama-build")
    add_library(ai-chat SHARED "${AI_CHAT_SRC}")
    target_compile_definitions(ai-chat PRIVATE GGML_SYSTEM_ARCH=ARM GGML_CPU_KLEIDIAI=1 GGML_OPENMP=1)
    target_include_directories(ai-chat PRIVATE
        "${LLAMA_SRC}" "${LLAMA_SRC}/common" "${LLAMA_SRC}/include"
        "${LLAMA_SRC}/ggml/include" "${LLAMA_SRC}/ggml/src"
        "${LLAMA_SRC}/examples/llama.android/lib/src/main/cpp")
    target_link_libraries(ai-chat PRIVATE llama llama-common android log)
else()
    add_library(ai-chat SHARED "${CMAKE_CURRENT_LIST_DIR}/abi_placeholder.cpp")
endif()
