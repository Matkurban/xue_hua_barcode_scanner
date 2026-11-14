#ifdef __ANDROID__

#include "scanner_host_ffi.h"

#include <jni.h>

#include <cstdint>
#include <cstdlib>
#include <mutex>
#include <string>
#include <vector>

namespace {

std::mutex g_jni_mutex;
JavaVM* g_jvm = nullptr;
jobject g_plugin_ref = nullptr;
jclass g_plugin_class = nullptr;

jmethodID g_mid_list_cameras = nullptr;
jmethodID g_mid_start_camera = nullptr;
jmethodID g_mid_stop_camera = nullptr;
jmethodID g_mid_set_torch = nullptr;
jmethodID g_mid_open_app_settings = nullptr;
jmethodID g_mid_pick_image = nullptr;
jmethodID g_mid_set_frame_paused = nullptr;

class ScopedJniEnv {
 public:
  ScopedJniEnv() {
    JavaVM* jvm = nullptr;
    {
      std::lock_guard<std::mutex> lock(g_jni_mutex);
      jvm = g_jvm;
    }
    if (jvm == nullptr) {
      return;
    }
    const jint status =
        jvm->GetEnv(reinterpret_cast<void**>(&env_), JNI_VERSION_1_6);
    if (status == JNI_OK) {
      jvm_ = jvm;
      return;
    }
    if (status == JNI_EDETACHED) {
      if (jvm->AttachCurrentThread(&env_, nullptr) == JNI_OK) {
        jvm_ = jvm;
        attached_by_scope_ = true;
      } else {
        env_ = nullptr;
      }
    }
  }

  ~ScopedJniEnv() {
    if (attached_by_scope_ && jvm_ != nullptr) {
      jvm_->DetachCurrentThread();
    }
  }

  ScopedJniEnv(const ScopedJniEnv&) = delete;
  ScopedJniEnv& operator=(const ScopedJniEnv&) = delete;

  JNIEnv* get() const { return env_; }

 private:
  JavaVM* jvm_ = nullptr;
  JNIEnv* env_ = nullptr;
  bool attached_by_scope_ = false;
};

void ClearPendingException(JNIEnv* env) {
  if (env != nullptr && env->ExceptionCheck()) {
    env->ExceptionDescribe();
    env->ExceptionClear();
  }
}

std::string JStringToStdString(JNIEnv* env, jstring value) {
  if (env == nullptr || value == nullptr) {
    return {};
  }
  const char* chars = env->GetStringUTFChars(value, nullptr);
  if (chars == nullptr) {
    return {};
  }
  std::string out(chars);
  env->ReleaseStringUTFChars(value, chars);
  return out;
}

jstring StdStringToJString(JNIEnv* env, const char* value) {
  if (env == nullptr || value == nullptr) {
    return nullptr;
  }
  return env->NewStringUTF(value);
}

void BuildCameraInfoVectors(
    JNIEnv* env,
    jobjectArray ids,
    jobjectArray labels,
    jobjectArray facings,
    std::vector<std::string>* id_storage,
    std::vector<std::string>* label_storage,
    std::vector<std::string>* facing_storage,
    std::vector<XHHostCameraInfo>* out_infos) {
  if (env == nullptr || ids == nullptr) {
    return;
  }
  const jsize count = env->GetArrayLength(ids);
  if (count <= 0) {
    return;
  }
  id_storage->resize(static_cast<size_t>(count));
  label_storage->resize(static_cast<size_t>(count));
  facing_storage->resize(static_cast<size_t>(count));
  out_infos->resize(static_cast<size_t>(count));

  const jsize label_count = labels != nullptr ? env->GetArrayLength(labels) : 0;
  const jsize facing_count = facings != nullptr ? env->GetArrayLength(facings) : 0;

  for (jsize i = 0; i < count; ++i) {
    auto* id_obj = static_cast<jstring>(env->GetObjectArrayElement(ids, i));
    (*id_storage)[static_cast<size_t>(i)] = JStringToStdString(env, id_obj);
    if (id_obj != nullptr) {
      env->DeleteLocalRef(id_obj);
    }

    if (i < label_count) {
      auto* label_obj =
          static_cast<jstring>(env->GetObjectArrayElement(labels, i));
      (*label_storage)[static_cast<size_t>(i)] =
          JStringToStdString(env, label_obj);
      if (label_obj != nullptr) {
        env->DeleteLocalRef(label_obj);
      }
    }

    if (i < facing_count) {
      auto* facing_obj =
          static_cast<jstring>(env->GetObjectArrayElement(facings, i));
      (*facing_storage)[static_cast<size_t>(i)] =
          JStringToStdString(env, facing_obj);
      if (facing_obj != nullptr) {
        env->DeleteLocalRef(facing_obj);
      }
    }

    XHHostCameraInfo& info = (*out_infos)[static_cast<size_t>(i)];
    info.id = const_cast<char*>((*id_storage)[static_cast<size_t>(i)].c_str());
    info.label =
        const_cast<char*>((*label_storage)[static_cast<size_t>(i)].c_str());
    info.facing =
        const_cast<char*>((*facing_storage)[static_cast<size_t>(i)].c_str());
  }
}

void AndroidListCameras(void* /*user_data*/, int64_t request_id) {
  ScopedJniEnv scoped_env;
  JNIEnv* env = scoped_env.get();
  jobject plugin = nullptr;
  jmethodID mid = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_jni_mutex);
    plugin = g_plugin_ref;
    mid = g_mid_list_cameras;
  }
  if (env == nullptr || plugin == nullptr || mid == nullptr) {
    xh_host_complete_camera_list(
        request_id, 0, "NO_HOST", "Android plugin host is unavailable.", nullptr, 0);
    return;
  }
  env->CallVoidMethod(plugin, mid, static_cast<jlong>(request_id));
  ClearPendingException(env);
}

void AndroidStartCamera(void* /*user_data*/,
                        int64_t request_id,
                        uint64_t session_generation,
                        const char* facing,
                        const char* camera_id) {
  ScopedJniEnv scoped_env;
  JNIEnv* env = scoped_env.get();
  jobject plugin = nullptr;
  jmethodID mid = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_jni_mutex);
    plugin = g_plugin_ref;
    mid = g_mid_start_camera;
  }
  if (env == nullptr || plugin == nullptr || mid == nullptr) {
    xh_host_complete_start_camera(
        request_id,
        0,
        "NO_HOST",
        "Android plugin host is unavailable.",
        nullptr,
        -1,
        0,
        0,
        0,
        nullptr,
        facing,
        0,
        0,
        0,
        nullptr,
        0);
    return;
  }
  jstring j_facing = StdStringToJString(env, facing != nullptr ? facing : "back");
  jstring j_camera_id = StdStringToJString(env, camera_id);
  env->CallVoidMethod(
      plugin,
      mid,
      static_cast<jlong>(request_id),
      static_cast<jlong>(session_generation),
      j_facing,
      j_camera_id);
  if (j_facing != nullptr) env->DeleteLocalRef(j_facing);
  if (j_camera_id != nullptr) env->DeleteLocalRef(j_camera_id);
  ClearPendingException(env);
}

void AndroidStopCamera(void* /*user_data*/, int64_t request_id) {
  ScopedJniEnv scoped_env;
  JNIEnv* env = scoped_env.get();
  jobject plugin = nullptr;
  jmethodID mid = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_jni_mutex);
    plugin = g_plugin_ref;
    mid = g_mid_stop_camera;
  }
  if (env == nullptr || plugin == nullptr || mid == nullptr) {
    xh_host_complete_bool(request_id, 1, 1, nullptr, nullptr);
    return;
  }
  env->CallVoidMethod(plugin, mid, static_cast<jlong>(request_id));
  ClearPendingException(env);
}

void AndroidSetTorch(void* /*user_data*/, int64_t request_id, int32_t enabled) {
  ScopedJniEnv scoped_env;
  JNIEnv* env = scoped_env.get();
  jobject plugin = nullptr;
  jmethodID mid = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_jni_mutex);
    plugin = g_plugin_ref;
    mid = g_mid_set_torch;
  }
  if (env == nullptr || plugin == nullptr || mid == nullptr) {
    xh_host_complete_bool(request_id, 1, 0, nullptr, nullptr);
    return;
  }
  env->CallVoidMethod(
      plugin,
      mid,
      static_cast<jlong>(request_id),
      static_cast<jboolean>(enabled != 0 ? JNI_TRUE : JNI_FALSE));
  ClearPendingException(env);
}

void AndroidOpenAppSettings(void* /*user_data*/, int64_t request_id) {
  ScopedJniEnv scoped_env;
  JNIEnv* env = scoped_env.get();
  jobject plugin = nullptr;
  jmethodID mid = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_jni_mutex);
    plugin = g_plugin_ref;
    mid = g_mid_open_app_settings;
  }
  if (env == nullptr || plugin == nullptr || mid == nullptr) {
    xh_host_complete_bool(request_id, 1, 0, nullptr, nullptr);
    return;
  }
  env->CallVoidMethod(plugin, mid, static_cast<jlong>(request_id));
  ClearPendingException(env);
}

void AndroidPickImage(void* /*user_data*/,
                      int64_t request_id,
                      int32_t prefer_file_path) {
  ScopedJniEnv scoped_env;
  JNIEnv* env = scoped_env.get();
  jobject plugin = nullptr;
  jmethodID mid = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_jni_mutex);
    plugin = g_plugin_ref;
    mid = g_mid_pick_image;
  }
  if (env == nullptr || plugin == nullptr || mid == nullptr) {
    xh_host_complete_pick_image(
        request_id, 1, 0, nullptr, 0, nullptr, nullptr, nullptr);
    return;
  }
  env->CallVoidMethod(
      plugin,
      mid,
      static_cast<jlong>(request_id),
      static_cast<jboolean>(prefer_file_path != 0 ? JNI_TRUE : JNI_FALSE));
  ClearPendingException(env);
}

void AndroidSetFrameStreamPaused(void* /*user_data*/, int32_t paused) {
  ScopedJniEnv scoped_env;
  JNIEnv* env = scoped_env.get();
  jobject plugin = nullptr;
  jmethodID mid = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_jni_mutex);
    plugin = g_plugin_ref;
    mid = g_mid_set_frame_paused;
  }
  if (env == nullptr || plugin == nullptr || mid == nullptr) {
    return;
  }
  env->CallVoidMethod(
      plugin, mid, static_cast<jboolean>(paused != 0 ? JNI_TRUE : JNI_FALSE));
  ClearPendingException(env);
}

void ClearCachedJniStateLocked(JNIEnv* env) {
  if (env != nullptr) {
    if (g_plugin_ref != nullptr) {
      env->DeleteGlobalRef(g_plugin_ref);
    }
    if (g_plugin_class != nullptr) {
      env->DeleteGlobalRef(g_plugin_class);
    }
  }
  g_plugin_ref = nullptr;
  g_plugin_class = nullptr;
  g_mid_list_cameras = nullptr;
  g_mid_start_camera = nullptr;
  g_mid_stop_camera = nullptr;
  g_mid_set_torch = nullptr;
  g_mid_open_app_settings = nullptr;
  g_mid_pick_image = nullptr;
  g_mid_set_frame_paused = nullptr;
}

}  // namespace

extern "C" {

JNIEXPORT jint JNI_OnLoad(JavaVM* vm, void* /*reserved*/) {
  std::lock_guard<std::mutex> lock(g_jni_mutex);
  g_jvm = vm;
  return JNI_VERSION_1_6;
}

JNIEXPORT void JNICALL
Java_com_kurban_xue_1hua_1barcode_1scanner_XueHuaBarcodeScannerPlugin_nativeAttachHost(
    JNIEnv* env,
    jobject thiz) {
  if (env == nullptr || thiz == nullptr) {
    return;
  }
  jobject old_token = nullptr;
  jobject new_ref = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_jni_mutex);
    if (g_jvm == nullptr) {
      env->GetJavaVM(&g_jvm);
    }
    old_token = g_plugin_ref;
  }
  if (old_token != nullptr) {
    xh_host_unregister_platform(old_token);
  }

  {
    std::lock_guard<std::mutex> lock(g_jni_mutex);
    ClearCachedJniStateLocked(env);

    jclass local_cls = env->GetObjectClass(thiz);
    if (local_cls == nullptr) {
      ClearPendingException(env);
      return;
    }
    g_plugin_class = static_cast<jclass>(env->NewGlobalRef(local_cls));
    env->DeleteLocalRef(local_cls);
    if (g_plugin_class == nullptr) {
      ClearPendingException(env);
      return;
    }

    g_plugin_ref = env->NewGlobalRef(thiz);
    new_ref = g_plugin_ref;
    g_mid_list_cameras =
        env->GetMethodID(g_plugin_class, "fromFfiListCameras", "(J)V");
    g_mid_start_camera = env->GetMethodID(
        g_plugin_class,
        "fromFfiStartCamera",
        "(JJLjava/lang/String;Ljava/lang/String;)V");
    g_mid_stop_camera =
        env->GetMethodID(g_plugin_class, "fromFfiStopCamera", "(J)V");
    g_mid_set_torch =
        env->GetMethodID(g_plugin_class, "fromFfiSetTorch", "(JZ)V");
    g_mid_open_app_settings =
        env->GetMethodID(g_plugin_class, "fromFfiOpenAppSettings", "(J)V");
    g_mid_pick_image =
        env->GetMethodID(g_plugin_class, "fromFfiPickImage", "(JZ)V");
    g_mid_set_frame_paused = env->GetMethodID(
        g_plugin_class, "fromFfiSetFrameStreamPaused", "(Z)V");

    if (env->ExceptionCheck() || g_plugin_ref == nullptr ||
        g_mid_list_cameras == nullptr || g_mid_start_camera == nullptr ||
        g_mid_stop_camera == nullptr || g_mid_set_torch == nullptr ||
        g_mid_open_app_settings == nullptr || g_mid_pick_image == nullptr ||
        g_mid_set_frame_paused == nullptr) {
      ClearPendingException(env);
      ClearCachedJniStateLocked(env);
      return;
    }
  }

  XHHostPlatformOps ops{};
  ops.user_data = new_ref;
  ops.list_cameras = AndroidListCameras;
  ops.start_camera = AndroidStartCamera;
  ops.stop_camera = AndroidStopCamera;
  ops.set_torch = AndroidSetTorch;
  ops.open_app_settings = AndroidOpenAppSettings;
  ops.pick_image = AndroidPickImage;
  ops.set_frame_stream_paused = AndroidSetFrameStreamPaused;
  xh_host_register_platform(&ops);
}

JNIEXPORT void JNICALL
Java_com_kurban_xue_1hua_1barcode_1scanner_XueHuaBarcodeScannerPlugin_nativeDetachHost(
    JNIEnv* env,
    jobject thiz) {
  if (env == nullptr || thiz == nullptr) {
    return;
  }
  jobject active_ref = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_jni_mutex);
    if (g_plugin_ref == nullptr || !env->IsSameObject(thiz, g_plugin_ref)) {
      ClearPendingException(env);
      return;
    }
    active_ref = g_plugin_ref;
  }

  xh_host_unregister_platform(active_ref);

  std::lock_guard<std::mutex> lock(g_jni_mutex);
  if (g_plugin_ref == active_ref) {
    ClearCachedJniStateLocked(env);
  }
}

JNIEXPORT void JNICALL
Java_com_kurban_xue_1hua_1barcode_1scanner_XueHuaBarcodeScannerPlugin_nativeOnCameraListResult(
    JNIEnv* env,
    jclass /*clazz*/,
    jlong request_id,
    jboolean ok,
    jstring error_code,
    jstring error_message,
    jobjectArray ids,
    jobjectArray labels,
    jobjectArray facings) {
  const std::string code_str = JStringToStdString(env, error_code);
  const std::string msg_str = JStringToStdString(env, error_message);
  std::vector<std::string> id_storage;
  std::vector<std::string> label_storage;
  std::vector<std::string> facing_storage;
  std::vector<XHHostCameraInfo> infos;
  BuildCameraInfoVectors(
      env, ids, labels, facings, &id_storage, &label_storage, &facing_storage, &infos);

  xh_host_complete_camera_list(
      static_cast<int64_t>(request_id),
      ok == JNI_TRUE ? 1 : 0,
      error_code != nullptr ? code_str.c_str() : nullptr,
      error_message != nullptr ? msg_str.c_str() : nullptr,
      infos.empty() ? nullptr : infos.data(),
      static_cast<int32_t>(infos.size()));
}

JNIEXPORT void JNICALL
Java_com_kurban_xue_1hua_1barcode_1scanner_XueHuaBarcodeScannerPlugin_nativeOnStartCameraResult(
    JNIEnv* env,
    jclass /*clazz*/,
    jlong request_id,
    jboolean ok,
    jstring error_code,
    jstring error_message,
    jstring error_details,
    jlong texture_id,
    jboolean has_torch,
    jboolean torch_enabled,
    jint available_camera_count,
    jstring active_camera_id,
    jstring camera_facing,
    jint preview_width,
    jint preview_height,
    jint sensor_orientation,
    jobjectArray ids,
    jobjectArray labels,
    jobjectArray facings) {
  const std::string code_str = JStringToStdString(env, error_code);
  const std::string msg_str = JStringToStdString(env, error_message);
  const std::string details_str = JStringToStdString(env, error_details);
  const std::string active_id_str = JStringToStdString(env, active_camera_id);
  const std::string facing_str = JStringToStdString(env, camera_facing);

  std::vector<std::string> id_storage;
  std::vector<std::string> label_storage;
  std::vector<std::string> facing_storage;
  std::vector<XHHostCameraInfo> infos;
  BuildCameraInfoVectors(
      env, ids, labels, facings, &id_storage, &label_storage, &facing_storage, &infos);

  xh_host_complete_start_camera(
      static_cast<int64_t>(request_id),
      ok == JNI_TRUE ? 1 : 0,
      error_code != nullptr ? code_str.c_str() : nullptr,
      error_message != nullptr ? msg_str.c_str() : nullptr,
      error_details != nullptr ? details_str.c_str() : nullptr,
      static_cast<int64_t>(texture_id),
      has_torch == JNI_TRUE ? 1 : 0,
      torch_enabled == JNI_TRUE ? 1 : 0,
      static_cast<int32_t>(available_camera_count),
      active_camera_id != nullptr ? active_id_str.c_str() : nullptr,
      camera_facing != nullptr ? facing_str.c_str() : nullptr,
      static_cast<int32_t>(preview_width),
      static_cast<int32_t>(preview_height),
      static_cast<int32_t>(sensor_orientation),
      infos.empty() ? nullptr : infos.data(),
      static_cast<int32_t>(infos.size()));
}

JNIEXPORT void JNICALL
Java_com_kurban_xue_1hua_1barcode_1scanner_XueHuaBarcodeScannerPlugin_nativeOnBoolResult(
    JNIEnv* env,
    jclass /*clazz*/,
    jlong request_id,
    jboolean ok,
    jboolean value,
    jstring error_code,
    jstring error_message) {
  const std::string code_str = JStringToStdString(env, error_code);
  const std::string msg_str = JStringToStdString(env, error_message);
  xh_host_complete_bool(
      static_cast<int64_t>(request_id),
      ok == JNI_TRUE ? 1 : 0,
      value == JNI_TRUE ? 1 : 0,
      error_code != nullptr ? code_str.c_str() : nullptr,
      error_message != nullptr ? msg_str.c_str() : nullptr);
}

JNIEXPORT void JNICALL
Java_com_kurban_xue_1hua_1barcode_1scanner_XueHuaBarcodeScannerPlugin_nativeOnPickImageResult(
    JNIEnv* env,
    jclass /*clazz*/,
    jlong request_id,
    jboolean ok,
    jboolean has_data,
    jbyteArray bytes,
    jstring file_path,
    jstring error_code,
    jstring error_message) {
  const std::string path_str = JStringToStdString(env, file_path);
  const std::string code_str = JStringToStdString(env, error_code);
  const std::string msg_str = JStringToStdString(env, error_message);

  std::vector<uint8_t> byte_buf;
  if (has_data == JNI_TRUE && bytes != nullptr) {
    const jsize len = env->GetArrayLength(bytes);
    if (len > 0) {
      byte_buf.resize(static_cast<size_t>(len));
      env->GetByteArrayRegion(
          bytes, 0, len, reinterpret_cast<jbyte*>(byte_buf.data()));
    }
  }

  xh_host_complete_pick_image(
      static_cast<int64_t>(request_id),
      ok == JNI_TRUE ? 1 : 0,
      has_data == JNI_TRUE && !byte_buf.empty() ? 1 : 0,
      byte_buf.empty() ? nullptr : byte_buf.data(),
      static_cast<int32_t>(byte_buf.size()),
      file_path != nullptr ? path_str.c_str() : nullptr,
      error_code != nullptr ? code_str.c_str() : nullptr,
      error_message != nullptr ? msg_str.c_str() : nullptr);
}

JNIEXPORT void JNICALL
Java_com_kurban_xue_1hua_1barcode_1scanner_XueHuaBarcodeScannerPlugin_nativeOnCameraFrame(
    JNIEnv* env,
    jclass /*clazz*/,
    jlong session_generation,
    jbyteArray bytes,
    jint byte_length,
    jint width,
    jint height,
    jint row_stride,
    jint format,
    jint sensor_orientation) {
  if (env == nullptr || bytes == nullptr || byte_length <= 0) {
    return;
  }
  const jsize arr_len = env->GetArrayLength(bytes);
  const jsize copy_len = byte_length < arr_len ? byte_length : arr_len;
  if (copy_len <= 0) {
    return;
  }
  std::vector<uint8_t> buffer(static_cast<size_t>(copy_len));
  env->GetByteArrayRegion(
      bytes, 0, copy_len, reinterpret_cast<jbyte*>(buffer.data()));
  xh_host_emit_camera_frame(
      static_cast<uint64_t>(session_generation),
      buffer.data(),
      static_cast<int32_t>(copy_len),
      static_cast<int32_t>(width),
      static_cast<int32_t>(height),
      static_cast<int32_t>(row_stride),
      static_cast<int32_t>(format),
      static_cast<int32_t>(sensor_orientation));
}

}  // extern "C"

#endif  // __ANDROID__
