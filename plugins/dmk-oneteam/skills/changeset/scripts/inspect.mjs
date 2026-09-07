#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

function parseArgs(argv) {
  const options = {};
  for (let index = 0; index < argv.length; index += 1) {
    const flag = argv[index];
    if (flag !== '--base' && flag !== '--head') fail(`Unknown argument: ${flag}`);
    const value = argv[index + 1];
    if (!value || value.startsWith('--')) fail(`${flag} requires a value`);
    options[flag.slice(2)] = value;
    index += 1;
  }
  return options;
}

function git(root, args, { optional = false } = {}) {
  try {
    return execFileSync('git', args, {
      cwd: root,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', optional ? 'ignore' : 'pipe'],
    });
  } catch (error) {
    if (optional) return undefined;
    const detail = error?.stderr?.toString().trim();
    throw new Error(`git ${args.join(' ')} failed${detail ? `: ${detail}` : ''}`);
  }
}

function readJson(path, label) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch (error) {
    throw new Error(`Cannot read ${label}: ${error.message}`);
  }
}

function resolveRef(root, requested, { preferRemote = false } = {}) {
  if (!requested) return undefined;
  const candidates =
    preferRemote && !requested.startsWith('origin/') ? [`origin/${requested}`, requested] : [requested];
  return candidates.find((candidate) =>
    git(root, ['rev-parse', '--verify', '--quiet', `${candidate}^{commit}`], { optional: true }),
  );
}

function diffEntries(root, range) {
  if (!range) return [];
  const fields = git(root, ['diff', '--no-renames', '--name-status', '-z', range, '--'])
    .split('\0')
    .filter(Boolean);
  const entries = [];
  for (let index = 0; index < fields.length; index += 2) {
    entries.push({ status: fields[index][0], path: fields[index + 1] });
  }
  return entries;
}

function workingTreeEntries(root) {
  const output = git(root, [
    '-c',
    'status.renames=false',
    'status',
    '--porcelain=v1',
    '-z',
    '--untracked-files=all',
  ]);
  return output
    .split('\0')
    .filter(Boolean)
    .map((record) => ({ status: record.slice(0, 2), path: record.slice(3) }));
}

function listPackageManifests(root) {
  const output = git(root, [
    'ls-files',
    '--cached',
    '--others',
    '--exclude-standard',
    '-z',
    '--',
    'package.json',
    ':(glob)**/package.json',
  ]);

  return [...new Set(output.split('\0').filter(Boolean))]
    .sort()
    .map((path) => {
      const manifest = readJson(join(root, path), path);
      return {
        path,
        directory: dirname(path) === '.' ? '' : dirname(path),
        name: typeof manifest.name === 'string' ? manifest.name : null,
        version: typeof manifest.version === 'string' ? manifest.version : null,
        private: manifest.private === true,
      };
    });
}

function detectPackageManager(root, rootPackage) {
  const declared = typeof rootPackage?.packageManager === 'string' ? rootPackage.packageManager : undefined;
  if (declared) return { name: declared.split('@')[0], source: 'packageManager' };

  const lockfiles = [
    ['bun', 'bun.lock'],
    ['bun', 'bun.lockb'],
    ['pnpm', 'pnpm-lock.yaml'],
    ['yarn', 'yarn.lock'],
    ['npm', 'package-lock.json'],
  ].filter(([, path]) => existsSync(join(root, path)));

  if (lockfiles.length === 0) return { name: null, source: null };
  return {
    name: lockfiles[0][0],
    source: lockfiles[0][1],
    ambiguous: new Set(lockfiles.map(([name]) => name)).size > 1,
  };
}

function isChangeset(path) {
  return /^\.changeset\/[^/]+\.md$/.test(path) && !/^\.changeset\/README\.md$/i.test(path);
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  const root = git(process.cwd(), ['rev-parse', '--show-toplevel']).trim();
  const configPath = join(root, '.changeset', 'config.json');
  const enabled = existsSync(configPath);
  const config = enabled ? readJson(configPath, relative(root, configPath)) : undefined;
  const rootPackagePath = join(root, 'package.json');
  const rootPackage = existsSync(rootPackagePath) ? readJson(rootPackagePath, 'package.json') : undefined;
  const packageManager = detectPackageManager(root, rootPackage);
  const branch = git(root, ['symbolic-ref', '--quiet', '--short', 'HEAD'], { optional: true })?.trim() || null;
  const headRequested = options.head ?? 'HEAD';
  const head = resolveRef(root, headRequested);
  if (!head) fail(`Head ref does not exist: ${headRequested}`);

  const baseRequested = options.base ?? config?.baseBranch;
  const base = resolveRef(root, baseRequested, { preferRemote: options.base === undefined });
  const committed = diffEntries(root, base ? `${base}...${head}` : undefined);
  const workingTree = workingTreeEntries(root);
  const packageManifests = listPackageManifests(root);
  const hasWorkspaceConfig =
    Array.isArray(rootPackage?.workspaces) ||
    Array.isArray(rootPackage?.workspaces?.packages) ||
    existsSync(join(root, 'pnpm-workspace.yaml')) ||
    existsSync(join(root, 'lerna.json')) ||
    existsSync(join(root, 'rush.json'));

  const result = {
    schemaVersion: 1,
    repositoryRoot: root,
    changesets: {
      enabled,
      configPath: enabled ? '.changeset/config.json' : null,
      baseBranch: config?.baseBranch ?? null,
      topology: hasWorkspaceConfig ? 'workspace' : 'single-package',
      packageManager,
      checker: {
        script: rootPackage?.scripts?.['check:changesets'] ?? null,
        available: typeof rootPackage?.scripts?.['check:changesets'] === 'string',
      },
      config: enabled
        ? {
            commit: config.commit ?? false,
            fixed: config.fixed ?? [],
            linked: config.linked ?? [],
            ignore: config.ignore ?? [],
            privatePackages: config.privatePackages ?? null,
            changedFilePatterns: config.changedFilePatterns ?? ['**'],
          }
        : null,
      packages: packageManifests,
    },
    git: {
      branch,
      head: headRequested,
      baseRequested: baseRequested ?? null,
      baseResolved: base ?? null,
      baseAvailable: baseRequested ? Boolean(base) : null,
      committedChanges: committed,
      workingTreeChanges: workingTree,
      committedChangesets: committed.filter(({ path }) => isChangeset(path)),
      workingTreeChangesets: workingTree.filter(({ path }) => isChangeset(path)),
    },
  };

  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}

try {
  main();
} catch (error) {
  fail(error instanceof Error ? error.message : String(error));
}
