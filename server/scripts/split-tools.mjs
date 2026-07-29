import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const srcDir = path.join(__dirname, '..', 'src');
const src = fs.readFileSync(path.join(srcDir, 'tools.ts'), 'utf8');

const cliStart = src.indexOf('export const CLI_TOOLS');
const liteStart = src.indexOf('export const LITE_EDITOR_TOOLS');
const editorPref = src.indexOf('export const EDITOR_PREFERRED');
if (cliStart < 0 || liteStart < 0 || editorPref < 0) {
  console.error('markers not found', { cliStart, liteStart, editorPref });
  process.exit(1);
}

const cliBlock = src.slice(cliStart, liteStart).trim();
const liteBlock = src.slice(liteStart, editorPref).trim();
const restTail = src.slice(editorPref).trimStart();

const types = `/**
 * Shared tool definition types for Godot MCP open server.
 */

export type ToolDef = {
  name: string;
  description: string;
  inputSchema: {
    type: 'object';
    properties: Record<string, unknown>;
    required: string[];
  };
};

export const emptyProps = {
  type: 'object' as const,
  properties: {} as Record<string, unknown>,
  required: [] as string[],
};
`;

const cli = `import type { ToolDef } from './tool-types.js';
import { emptyProps } from './tool-types.js';

${cliBlock}
`;

const lite = `import type { ToolDef } from './tool-types.js';
import { emptyProps } from './tool-types.js';

${liteBlock}
`;

const main = `/**
 * MCP tool definitions hub — re-exports split modules.
 * Category map: tool-groups.ts
 */

export type { ToolDef } from './tool-types.js';
export { emptyProps } from './tool-types.js';
export { TOOL_GROUPS, toolsInGroup } from './tool-groups.js';
export { CLI_TOOLS } from './tools-cli.js';
export { LITE_EDITOR_TOOLS } from './tools-lite.js';

${restTail}
`;

fs.writeFileSync(path.join(srcDir, 'tool-types.ts'), types);
fs.writeFileSync(path.join(srcDir, 'tools-cli.ts'), cli + '\n');
fs.writeFileSync(path.join(srcDir, 'tools-lite.ts'), lite + '\n');
fs.writeFileSync(path.join(srcDir, 'tools.ts'), main);
console.log('split ok', {
  cli: cli.split('\n').length,
  lite: lite.split('\n').length,
  main: main.split('\n').length,
});
