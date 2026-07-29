/**
 * MCP tool definitions hub — re-exports split modules.
 * Category map: tool-groups.ts
 */

export type { ToolDef } from './tool-types.js';
export { emptyProps } from './tool-types.js';
export { TOOL_GROUPS, toolsInGroup } from './tool-groups.js';
export { CLI_TOOLS } from './tools-cli.js';
export { LITE_EDITOR_TOOLS } from './tools-lite.js';

import { LITE_EDITOR_TOOLS as _LITE } from './tools-lite.js';

export const EDITOR_PREFERRED = new Set([
  'health_check',
  'agent_workflow_guide',
  'get_godot_version',
  'get_uid',
  'update_project_uids',
  'load_sprite',
  'export_mesh_library',
  'create_scene',
  'add_node',
  'save_scene',
  'get_project_info',
  'list_projects',
  'launch_editor',
  'list_mcp_commands',
  ..._LITE.map((t) => t.name),
]);

export function parseLiteMode(argv: string[]): boolean {
  if (argv.includes('--lite') || argv.includes('--minimal')) return true;
  if (process.env.GODOT_MCP_LITE === 'true' || process.env.GODOT_MCP_LITE === '1') return true;
  return false;
}

