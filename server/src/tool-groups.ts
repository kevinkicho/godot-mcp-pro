/**
 * Tool grouping helpers — keeps tools.ts maintainable as the surface grows.
 * CLI_TOOLS / LITE_EDITOR_TOOLS still live in tools.ts; this documents categories
 * for discovery and future splitting.
 */

export const TOOL_GROUPS = {
  connection: ['health_check', 'get_connection_status', 'runtime_ping', 'runtime_call'],
  run_probe: [
    'run_session_start',
    'run_session_stop',
    'run_session_status',
    'run_probe_report',
    'run_record_start',
    'run_record_stop',
    'run_capture_timeline',
    'run_find_nodes',
    'run_log_event',
    'run_ping_runtime',
    'ensure_runtime_autoloads',
    'set_runtime_token',
    'get_runtime_info',
  ],
  media: [
    'media_find_ffmpeg',
    'media_frames_to_video',
    'media_extract_keyframes',
    'media_clip_video',
    'media_contact_sheet',
  ],
  web: ['web_serve_export', 'web_serve_stop', 'web_playwright_probe'],
  tests: ['detect_test_frameworks', 'run_gut_tests', 'run_gdunit_tests', 'list_test_recipes'],
  production: [
    'scaffold_project_defaults',
    'ensure_imported',
    'import_paths',
    'stage_files_into_res',
    'wire_signal_to_new_method',
    'playtest_report',
    'agent_production_status',
  ],
} as const;

export function toolsInGroup(group: keyof typeof TOOL_GROUPS): readonly string[] {
  return TOOL_GROUPS[group];
}
