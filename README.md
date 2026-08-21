# Orbit

Orbit is a fully offline Flutter Android chatbot powered by a local llama.cpp-compatible GGUF model. No account, server, API, database, Python, or internet connection is required at runtime.

## Requirements

- Android ARM64 phone
- Flutter SDK and Android SDK/NDK/CMake for building
- A text-generation GGUF model on the phone
- USB debugging enabled for `flutter run` or `adb install`

On first launch, tap **Select GGUF model** and choose a `.gguf` file using Android's document picker. Orbit copies the model into app-private storage and loads it from there. The model is not bundled into the APK, and a previously selected model is reused automatically on later launches.

## Model selection

Orbit accepts llama.cpp-compatible GGUF files, but the model should be a text-generation or instruction-tuned model. Vision, audio, embedding, and other non-chat GGUF files are not supported by the current text-only interface.

For a typical Android ARM64 phone, these are the practical choices:

| Model | Recommended quantization | Use case |
| --- | --- | --- |
| Qwen2.5-0.5B-Instruct | `Q4_K_M` | Compact model with low memory use |
| Qwen2.5-1.5B-Instruct | `Q4_K_M` | Better answers and reasoning |
| Either model | `Q2_K` | Smallest file, but noticeably lower quality; use only if storage or memory is limited |

Start with `Qwen2.5-0.5B-Instruct-Q4_K_M.gguf` for a compact model. Use `Qwen2.5-1.5B-Instruct-Q4_K_M.gguf` when answer quality matters more. Q2_K can hurt coding, reasoning, and factual answers. Avoid 7B-or-larger models on a phone because they require substantially more memory.

Download models from a trusted source, preferably the model publisher's official Hugging Face repository. The official [Qwen2.5-0.5B GGUF repository](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF) provides the `Q4_K_M` file.

After downloading a model, copy it anywhere accessible to Android's file picker, then select it inside Orbit. The app copies the selected file into private storage; it does not depend on a hardcoded shared-storage path.

## Build and run

From the project root:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter build apk --debug
flutter run
```

The generated APK is:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

To install it manually on a connected phone:

```powershell
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Then open the app named **Orbit**.

## Put the model on the phone

You can place a model anywhere visible in the Android file picker. For example, with ADB:

```powershell
adb shell mkdir -p /sdcard/Download/offline_ai
adb push qwen2.5-0.5b-instruct-q4_k_m.gguf /sdcard/Download/offline_ai/
```

The 1.5B Q4_K_M model is approximately 1.1 GB. Keep several hundred megabytes of additional free RAM and storage available for the context and KV cache.

## How the app works

1. Flutter displays the chat UI.
2. Android copies the model selected in the document picker into `files/models`.
3. The llama.cpp Android native runtime loads the GGUF model.
4. Generation runs on a background coroutine/thread.
5. Native tokens stream to Flutter through an EventChannel.
6. Native model resources are released when the Activity is destroyed.

The Android native build includes the ARM64 llama.cpp/ggml CPU backend directly in the APK. This avoids missing dynamic backend-library errors such as `no backends are loaded` or missing `libmtmd.so`.

## Custom app icon and splash icon

For a 1:1 image, place the source image in the project, for example:

```text
assets/branding/orbit_icon.png
```

Android launcher density resources are stored in `android/app/src/main/res/mipmap-*`. The launch screen uses:

```text
android/app/src/main/res/drawable/launch_background.xml
android/app/src/main/res/drawable-v21/launch_background.xml
```

The splash image is stored at `android/app/src/main/res/drawable-nodpi/orbit_icon.png`. Keep important artwork centered because Android may crop or mask launcher artwork.

## Troubleshooting

### Model not found

Tap **Select GGUF model** and choose the model again. If using ADB, verify that the file is visible in Downloads:

```powershell
adb shell ls -lh /sdcard/Download/offline_ai/
```

### App says no backend is loaded

Rebuild the APK from the project root. The ARM64 APK must contain `libai-chat.so`, `libllama.so`, `libllama-common.so`, `libggml.so`, and `libggml-base.so`.

### Completely offline behavior

After the model is copied to app-private storage, Orbit does not need network access. Disable Wi-Fi and mobile data to verify offline inference.
