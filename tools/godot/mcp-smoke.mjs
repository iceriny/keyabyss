// Reusable local integration check. Run godot.ps1 preview first.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../../', import.meta.url));
const sdk = path.join(root, '.tools/godot-mcp/node_modules/@modelcontextprotocol/sdk/dist/esm/client');
const { Client } = await import(pathToFileURL(path.join(sdk, 'index.js')));
const { StdioClientTransport } = await import(pathToFileURL(path.join(sdk, 'stdio.js')));
const local = JSON.parse(await readFile(new URL('local.paths.json', import.meta.url), 'utf8'));
const projectPath = path.join(root, '.temp/godot-mcp/project');
const evidence = path.join(root, '.temp/godot-preparation');
await mkdir(evidence, { recursive: true });
const records = [];
const transport = new StdioClientTransport({
  command: process.execPath,
  args: [path.join(root, '.tools/godot-mcp/build/index.js')],
  cwd: root,
  env: { ...process.env, GODOT_PATH: process.env.GODOT_PATH || local.godot, GODOT_MCP_ALLOWED_DIRS: projectPath },
  stderr: 'pipe',
});
let serverOutput = '';
transport.stderr?.on('data', data => { serverOutput += data.toString(); });
const client = new Client({ name: 'keyabyss-preparation', version: '1.0.0' });
async function call(name, args = {}) {
  const result = await client.callTool({ name, arguments: args });
  records.push({ name, args, result: { ...result, content: result.content.map(item => item.type === 'image' ? { type: 'image', mimeType: item.mimeType } : item) } });
  if (result.isError) throw new Error(`${name}: ${JSON.stringify(result.content)}`);
  for (const item of result.content) {
    if (item.type !== 'text' || !item.text.trim().startsWith('{')) continue;
    const payload = JSON.parse(item.text);
    if (payload.success === false || payload.valid === false) throw new Error(`${name}: ${item.text}`);
    if (name === 'game_get_property' && args.property === 'use_hdr_2d' && payload.value !== true) throw new Error('HDR 2D is disabled.');
    if (name === 'get_debug_output' && (payload.errors || []).some(line => /(?:SCRIPT ERROR|^ERROR:)/.test(line))) throw new Error(`Godot runtime error: ${item.text}`);
  }
  console.log(`OK ${name}`);
  return result;
}
let running = false;
try {
  await client.connect(transport);
  const listed = await client.listTools();
  records.push({ advertisedTools: listed.tools.map(tool => tool.name) });
  await call('get_godot_version');
  await call('get_project_info', { projectPath });
  await call('validate_script', { projectPath, scriptPath: 'app/main.gd' });
  await call('run_project', { projectPath });
  running = true;
  // The upstream run tool returns before the TCP bridge has connected.
  let connected = false;
  for (let attempt = 0; attempt < 20; attempt++) {
    await new Promise(resolve => setTimeout(resolve, 500));
    const result = await client.callTool({ name: 'game_get_scene_tree', arguments: {} });
    if (!result.isError) { records.push({ name: 'game_get_scene_tree', result }); connected = true; break; }
  }
  if (!connected) throw new Error('Runtime bridge did not become ready within 10 seconds.');
  await call('game_wait', { frames: 3 });
  await call('game_get_ui');
  await call('game_get_property', { nodePath: '/root', property: 'use_hdr_2d' });
  await call('game_get_audio');
  await call('game_key_press', { key: 'Tab' });
  await call('game_get_ui');
  const screenshot = await call('game_screenshot');
  const png = screenshot.content.find(item => item.type === 'image' && item.mimeType === 'image/png');
  if (!png) throw new Error('MCP did not return a PNG image.');
  await writeFile(path.join(evidence, 'godot-window.png'), Buffer.from(png.data, 'base64'));
  await call('game_get_errors');
  await call('get_debug_output');
} finally {
  if (running) await call('stop_project').catch(error => { console.error(error); process.exitCode = 1; });
  await client.close();
  await writeFile(path.join(evidence, 'mcp-smoke.json'), JSON.stringify(records, null, 2) + '\n');
  await writeFile(path.join(evidence, 'mcp-server.log'), serverOutput);
}
