import { copyFileSync, mkdirSync, existsSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');
const destDir = join(root, 'build', 'scripts');
mkdirSync(destDir, { recursive: true });

const src = join(root, 'src', 'scripts', 'godot_operations.gd');
const dest = join(destDir, 'godot_operations.gd');
if (existsSync(src)) {
  copyFileSync(src, dest);
  console.log('Copied godot_operations.gd');
} else {
  console.warn('godot_operations.gd not found; headless scene ops will be unavailable');
}
