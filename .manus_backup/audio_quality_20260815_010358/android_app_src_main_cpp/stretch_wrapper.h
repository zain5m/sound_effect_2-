#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef struct StretchProcessor StretchProcessor;

/// اختبار الاتصال
int stretch_test_connection(void);

/// إنشاء معالج جديد
StretchProcessor* stretch_create(
        int channels,
        int sampleRate
);

/// حذف المعالج
void stretch_destroy(
        StretchProcessor* processor
);

/// إعادة التهيئة
int stretch_reset(
        StretchProcessor* processor
);

/// معالجة البيانات
int stretch_process(
        StretchProcessor* processor,
        const float* input,
        int inputFrames,
        float* output,
        int outputFrames,
        float speed
);

/// إخراج العينات المتبقية
int stretch_flush(
        StretchProcessor* processor,
        float* output,
        int outputFrames
);

#ifdef __cplusplus
}
#endif