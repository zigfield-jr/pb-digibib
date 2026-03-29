#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

const char* iv_screen_reader_default_socket_address();

struct iv_screen_reader_client_t typedef iv_screen_reader_client;

enum
{
    iv_screen_reader_ok,
    iv_screen_reader_library_linkage_failure,
    iv_screen_reader_address_not_found,
    iv_screen_reader_connection_lost,
    iv_screen_reader_null_client,
    iv_screen_reader_all_text_fields_empty,
    iv_screen_reader_invalid_locale,
    iv_screen_reader_can_not_get_system_locale,
    iv_screen_reader_volume_out_of_bounds,
    iv_screen_reader_speed_out_of_bounds,
    iv_screen_reader_tts_package_is_empty,
    iv_screen_reader_too_large_tts_package,
    iv_screen_reader_unknown_error,
} typedef iv_screen_reader_error;

struct
{
    const char* text;
    const char* locale;
} typedef iv_screen_reader_text;

enum
{
    iv_screen_reader_message_priority_normal,
    iv_screen_reader_message_priority_low,
} typedef iv_screen_reader_message_priority;

enum
{
    iv_screen_reader_message_status_playing,
    iv_screen_reader_message_status_canceled,
    iv_screen_reader_message_status_in_queue,
    iv_screen_reader_message_status_done,
} typedef iv_screen_reader_message_status;

typedef uint32_t iv_screen_reader_message_id;

/**
 * @brief screen_reader_connect_result
 * Either client is not null or error is not screen_reader_ok
 */
struct
{
    iv_screen_reader_client* client;
    iv_screen_reader_error error;
} typedef iv_screen_reader_connect_result;

struct
{
    /// undefined if error is not screen_reader_ok
    iv_screen_reader_message_id id;
    iv_screen_reader_error error;
} typedef iv_screen_reader_play_with_response_result;

struct
{
    /// undefined if error is not screen_reader_ok
    iv_screen_reader_message_status status;
    iv_screen_reader_error error;
} typedef iv_screen_reader_status_result;

struct
{
    /// from 0 to 1
    /// undefined if error is not screen_reader_ok
    float volume;
    iv_screen_reader_error error;
} typedef iv_screen_reader_get_volume_result;

struct
{
    /// from 0 to ∞
    /// undefined if error is not screen_reader_ok
    float speed;
    iv_screen_reader_error error;
} typedef iv_screen_reader_get_speed_result;

struct
{
    /// Null terminated ASCII string if no error. Otherwise undefined. Example: "en_us_ashley"
    char package[32];
    iv_screen_reader_error error;
} typedef iv_screen_reader_get_tts_package_result;

const char* iv_screen_reader_error_to_str(iv_screen_reader_error err);

/**
 * @brief iv_set_screen_reader_enabled - sets flag `screen_reader_enabled`
 * system-wide to global config
 */
void iv_set_screen_reader_enabled(bool);

/**
 * @brief iv_screen_reader_enabled - reads `screen_reader_enabled` flag from
 * global config
 */
bool iv_screen_reader_enabled();

/**
 * @brief iv_screen_reader_client_play
 * @param elementLabel - can be null
 * @param elementState - can be null
 * @param elementRole - can be null
 * @param elementInstruction - can be null
 * @param priority
 * @param canceleble
 * @note elementLabel, elementState, elementRole and elementInstruction can not
 * be null all at once (if so screen_reader_all_text_fields_empty is returned)
 */
iv_screen_reader_error iv_screen_reader_play(
    const iv_screen_reader_text* elementLabel,
    const iv_screen_reader_text* elementState,
    const iv_screen_reader_text* elementRole,
    const iv_screen_reader_text* elementInstruction,
    iv_screen_reader_message_priority priority,
    bool canceleble);

/**
 * @brief iv_screen_reader_play_with_default_locale
 * @param elementLabel - can be null
 * @param elementState - can be null
 * @param elementRole - can be null
 * @param elementInstruction - can be null
 * @param priority
 * @param canceleble
 * @note elementLabel, elementState, elementRole and elementInstruction can not
 * be null all at once (if so screen_reader_all_text_fields_empty is returned)
 * @return
 */
iv_screen_reader_error iv_screen_reader_play_with_system_locale(
    const char* elementLabel,
    const char* elementState,
    const char* elementRole,
    const char* elementInstruction,
    iv_screen_reader_message_priority priority,
    bool canceleble);

/**
 * @brief iv_screen_reader_client_play_with_response
 * @param elementLabel - can be null
 * @param elementState - can be null
 * @param elementRole - can be null
 * @param elementInstruction - can be null
 * @param priority
 * @param canceleble
 * @note elementLabel, elementState, elementRole and elementInstruction can not
 * be null all at once (if so screen_reader_all_text_fields_empty is returned)
 */
iv_screen_reader_play_with_response_result iv_screen_reader_client_play_with_response(
    const iv_screen_reader_text* elementLabel,
    const iv_screen_reader_text* elementState,
    const iv_screen_reader_text* elementRole,
    const iv_screen_reader_text* elementInstruction,
    iv_screen_reader_message_priority priority,
    bool canceleble);

/**
 * @brief iv_screen_reader_client_play_with_response_and_default_locale
 * @param elementLabel - can be null
 * @param elementState - can be null
 * @param elementRole - can be null
 * @param elementInstruction - can be null
 * @param priority
 * @param canceleble
 * @note elementLabel, elementState, elementRole and elementInstruction can not
 * be null all at once (if so screen_reader_all_text_fields_empty is returned)
 * @return
 */
iv_screen_reader_play_with_response_result iv_screen_reader_client_play_with_response_and_system_locale(
    const char* elementLabel,
    const char* elementState,
    const char* elementRole,
    const char* elementInstruction,
    iv_screen_reader_message_priority priority,
    bool canceleble);

/**
 * @brief iv_screen_reader_client_cancel
 * @param id
 * @param error
 */
iv_screen_reader_error
iv_screen_reader_client_cancel(iv_screen_reader_message_id id);

/**
 * @brief iv_screen_reader_client_status_with_response
 * @param id
 * @param error
 * @return undefined if error occured
 */
iv_screen_reader_status_result iv_screen_reader_status(iv_screen_reader_message_id id);

/**
 * @brief iv_screen_reader_get_volume
 * @return
 */
iv_screen_reader_get_volume_result iv_screen_reader_get_volume();

/**
 * @brief iv_screen_reader_get_speed
 * @return
 */
iv_screen_reader_get_speed_result iv_screen_reader_get_speed();

/**
 * @brief iv_screen_reader_get_tts_package
 * @return
 */
iv_screen_reader_get_tts_package_result iv_screen_reader_get_tts_package();

/**
 * @brief iv_screen_reader_set_volume
 * @param volume - from 0 to 1
 * @return
 */
iv_screen_reader_error iv_screen_reader_set_volume(float volume);

/**
 * @brief iv_screen_reader_set_speed
 * @param speed - from 0 to ∞
 * @return
 */
iv_screen_reader_error iv_screen_reader_set_speed(float speed);

/**
 * @brief iv_screen_reader_set_tts_package
 * @param package - example: "en_us_ashley"
 * @return
 */
iv_screen_reader_error iv_screen_reader_set_tts_package(const char* package);

/**
 * @brief iv_screen_reader_reload - reload tts engine inside daemon
 * @return
 */
iv_screen_reader_error iv_screen_reader_reload();

/**
 * @brief iv_screen_reader_is_playing
 * @return ivmpc->screen_reader_is_playing
 */
bool iv_screen_reader_is_playing();

#ifdef __cplusplus
}
#endif
