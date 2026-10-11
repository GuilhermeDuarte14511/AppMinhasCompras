const { readdirSync } = require('node:fs');
const { join } = require('node:path');
const { spawnSync } = require('node:child_process');

const files = readdirSync(join(__dirname, 'lib'))
  .filter((name) => name.endsWith('.test.js'))
  .sort()
  .map((name) => join(__dirname, 'lib', name));

if (files.length === 0) {
  console.error('Nenhum teste compilado encontrado em lib.');
  process.exit(1);
}

const result = spawnSync(process.execPath, ['--test', ...files], {
  stdio: 'inherit',
});
if (result.error) console.error(result.error.message);
process.exit(result.status ?? 1);
