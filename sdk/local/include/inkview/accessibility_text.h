#pragma once

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

void iv_load_text_accessibility_parameters();
void iv_notify_text_accessibility_parameter_changed(int parameter, int receiver);

void iv_set_system_default_fonts();

int iv_load_text_scale_percentage();
int iv_text_scale_percentage();
void iv_set_text_scale_percentage(int value, bool save, int notification_receiver);

bool iv_load_text_bold_enabled();
bool iv_text_bold_enabled();
void iv_set_text_bold_enabled(bool value, bool save, int notification_receiver);

bool iv_load_text_contrast_enabled();
bool iv_text_contrast_enabled();
void iv_set_text_contrast_enabled(bool value, bool save, int notification_receiver);

bool iv_load_text_dyslexic_font_enabled();
bool iv_text_dyslexic_font_enabled();
void iv_set_text_dyslexic_font_enabled(bool value, bool save, int notification_receiver);

bool iv_dyslexic_supports_current_language();

#ifdef __cplusplus
}
#endif
