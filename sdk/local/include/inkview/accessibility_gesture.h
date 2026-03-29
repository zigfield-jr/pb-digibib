#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    GESTURE_SWIPE,
    GESTURE_TAP,
    GESTURE_DOUBLE_TAP,
    GESTURE_DOUBLE_TAP_AND_HOLD,
    GESTURE_DRAG,
    GESTURE_DRAG_FINISH,
    GESTURE_TWO_TAP,
    GESTURE_TWO_SWIPE
} gesture_type_t;

typedef enum {
    GESTURE_DIRECTION_NONE,
    GESTURE_DIRECTION_LEFT,
    GESTURE_DIRECTION_RIGHT,
    GESTURE_DIRECTION_UP,
    GESTURE_DIRECTION_DOWN
} gesture_direction_t;

typedef struct gesture_event_t {
    gesture_type_t type;
    gesture_direction_t direction;
    uint32_t duration_ms;
    int start_x;
    int start_y;
    int end_x;
    int end_y;
} gesture_event_t;

typedef struct {
    int x;
    int y;
} point_t;

typedef struct {
    bool active;
    point_t point;
    long long timems;
} touch_point_t;

typedef struct gesture_config gesture_config_t;

typedef void (*gesture_timer_callback_t)(void* user_data);
typedef void (*gesture_set_timer_t)(const char* name,
    gesture_timer_callback_t callback,
    void* user_data, int ms);
typedef void (*gesture_cancel_timer_t)(const char* name);

typedef struct {
    gesture_set_timer_t set_timer;
    gesture_cancel_timer_t cancel_timer;
} gesture_timer_t;

typedef void (*gesture_callback_t)(const gesture_event_t event,
    void* user_data);
typedef struct gesture_recognizer gesture_recognizer_t;

gesture_recognizer_t* gesture_recognizer_create(const gesture_config_t* config,
    const gesture_timer_t* timer);
void gesture_recognizer_destroy(gesture_recognizer_t* recognizer);
void gesture_recognizer_set_callback(gesture_recognizer_t* recognizer,
    gesture_callback_t callback,
    void* user_data);
void gesture_recognizer_process_touch(gesture_recognizer_t* recognizer,
    const touch_point_t* points, int size);

void handle_accessibility_mtsync_event(int index);
const gesture_event_t* get_accessibility_gesture_event(unsigned int index);

#ifdef __cplusplus
}
#endif
