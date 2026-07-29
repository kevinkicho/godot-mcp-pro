/**
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
