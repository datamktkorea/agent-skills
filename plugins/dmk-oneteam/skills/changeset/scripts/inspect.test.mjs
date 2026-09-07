import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import assert from 'node:assert/strict';

const SCRIPT = join(dirname(fileURLToPath(import.meta.url)), 'inspect.mjs');

function write(root, path, contents) {
  const target = join(root, path);
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, contents);
}

function git(root, ...args) {
  return execFileSync('git', args, { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
}

function createRepo(files) {
  const root = mkdtempSync(join(tmpdir(), 'changeset-inspect-'));
  git(root, 'init', '--initial-branch=main');
  git(root, 'config', 'user.name', 'Skill Test');
  git(root, 'config', 'user.email', 'skill-test@example.invalid');
  for (const [path, contents] of Object.entries(files)) write(root, path, contents);
  git(root, 'add', '--all');
  git(root, 'commit', '-m', 'initial fixture');
  return root;
}

function inspect(root, ...args) {
  return JSON.parse(execFileSync(process.execPath, [SCRIPT, ...args], { cwd: root, encoding: 'utf8' }));
}

test('reports a repository that does not use Changesets', (t) => {
  const root = createRepo({ 'README.md': 'fixture\n' });
  t.after(() => rmSync(root, { recursive: true, force: true }));

  const result = inspect(root);
  assert.equal(result.changesets.enabled, false);
  assert.equal(result.changesets.checker.available, false);
  assert.equal(result.changesets.topology, 'single-package');
});

test('reports single-package Changesets facts and working-tree files', (t) => {
  const root = createRepo({
    'package.json': JSON.stringify({
      name: 'service-one',
      version: '1.0.0',
      packageManager: 'npm@11.0.0',
      scripts: { 'check:changesets': 'node scripts/check.mjs' },
    }),
    '.changeset/config.json': JSON.stringify({ baseBranch: 'main', commit: false }),
    'src/index.js': 'export const value = 1;\n',
  });
  t.after(() => rmSync(root, { recursive: true, force: true }));
  write(root, '.changeset/service-fix.md', '---\n"service-one": patch\n---\n\nFix the service.\n');

  const result = inspect(root, '--base', 'HEAD');
  assert.equal(result.changesets.enabled, true);
  assert.equal(result.changesets.topology, 'single-package');
  assert.equal(result.changesets.packageManager.name, 'npm');
  assert.equal(result.changesets.checker.available, true);
  assert.equal(result.changesets.packages[0].name, 'service-one');
  assert.deepEqual(result.git.workingTreeChangesets, [
    { status: '??', path: '.changeset/service-fix.md' },
  ]);
});

test('reports workspace package manifests without deciding release units', (t) => {
  const root = createRepo({
    'package.json': JSON.stringify({
      name: 'workspace-root',
      private: true,
      workspaces: ['packages/*'],
      packageManager: 'pnpm@10.0.0',
      scripts: { 'check:changesets': 'node scripts/check.mjs' },
    }),
    'pnpm-lock.yaml': 'lockfileVersion: 9\n',
    '.changeset/config.json': JSON.stringify({
      baseBranch: 'main',
      fixed: [['package-a', 'package-b']],
      linked: [],
      ignore: [],
    }),
    'packages/a/package.json': JSON.stringify({ name: 'package-a', version: '1.0.0' }),
    'packages/b/package.json': JSON.stringify({ name: 'package-b', version: '1.0.0' }),
  });
  t.after(() => rmSync(root, { recursive: true, force: true }));

  const result = inspect(root, '--base', 'main');
  assert.equal(result.changesets.topology, 'workspace');
  assert.deepEqual(
    result.changesets.packages.map(({ name }) => name).sort(),
    ['package-a', 'package-b', 'workspace-root'],
  );
  assert.deepEqual(result.changesets.config.fixed, [['package-a', 'package-b']]);
});
