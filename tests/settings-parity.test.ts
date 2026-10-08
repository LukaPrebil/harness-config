/**
 * Parity tests for the pi Profile settings pair. Startup identity, the
 * Profile's own hook-bridge path, and the skill-sync exclusions are
 * per-Profile; every other key is shared and must stay identical across
 * settings.work.json and settings.personal.json, so a repo edit made in one
 * file cannot silently skip the other.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, it } from 'node:test';

const PI_DIR = join(dirname(fileURLToPath(import.meta.url)), '..', 'pi');

/**
 * Keys that legitimately differ per Profile: the startup identity trio, plus
 * lastChangelogVersion, which pi writes back per Profile at runtime. `skills`
 * differs because each Profile loads only its own account's skill-sync
 * buckets; the exclusions are checked separately below.
 */
const PER_PROFILE_KEYS = [
  'defaultProvider',
  'defaultModel',
  'defaultThinkingLevel',
  'lastChangelogVersion',
  'skills',
] as const;

/**
 * The exclusion shape the skill-sync scoping depends on: a `!` glob anchored
 * at the `~/.agents` scan root, naming one bucket by its prefix. Pi matches it
 * against `skills/synced/<bucket>/<skill>/SKILL.md`, so the pattern must keep
 * the `skills/synced/` prefix and the trailing `/**`.
 */
const BUCKET_EXCLUSION = /^!skills\/synced\/([0-9a-f]{8})-\*\/\*\*$/;

type ProfileSettings = Record<string, unknown>;

/**
 * The hook bridge sits in each Profile's own agent dir, so only that path
 * differs; every other subagents setting stays shared and is still compared.
 */
function normalizeProfileBridge(settings: ProfileSettings): void {
  const subagents = settings['subagents'];
  if (subagents === null || typeof subagents !== 'object') return;
  const entries = (subagents as Record<string, unknown>)['defaultSubagentOnlyExtensions'];
  if (!Array.isArray(entries)) return;
  (subagents as Record<string, unknown>)['defaultSubagentOnlyExtensions'] = entries.map(
    (entry) => String(entry).replace('/.pi-personal/agent/', '/.pi/agent/'),
  );
}

function loadSettings(profile: 'work' | 'personal'): ProfileSettings {
  const raw: ProfileSettings = JSON.parse(
    readFileSync(join(PI_DIR, `settings.${profile}.json`), 'utf8'),
  );
  for (const key of PER_PROFILE_KEYS) delete raw[key];
  normalizeProfileBridge(raw);
  return raw;
}

/** The skill-sync exclusions a Profile declares, unmodified. */
function bucketExclusions(profile: 'work' | 'personal'): string[] {
  const raw: ProfileSettings = JSON.parse(
    readFileSync(join(PI_DIR, `settings.${profile}.json`), 'utf8'),
  );
  const entries = raw['skills'];
  assert.ok(Array.isArray(entries), `settings.${profile}.json declares a skills array`);
  return (entries as unknown[]).map((entry) => String(entry));
}

/** The bucket prefix of each exclusion, or the raw entry when it does not match. */
function excludedBucketPrefixes(profile: 'work' | 'personal'): string[] {
  return bucketExclusions(profile).map(
    (entry) => BUCKET_EXCLUSION.exec(entry)?.[1] ?? entry,
  );
}

describe('profile settings parity', () => {
  it('keeps every non-Profile key identical across work and personal', () => {
    assert.deepEqual(loadSettings('work'), loadSettings('personal'));
  });

  it('pins the work startup identity to gpt-6.1-sol on high', () => {
    const work: ProfileSettings = JSON.parse(
      readFileSync(join(PI_DIR, 'settings.work.json'), 'utf8'),
    );
    assert.equal(work['defaultProvider'], 'openai-codex');
    assert.equal(work['defaultModel'], 'gpt-6.1-sol');
    assert.equal(work['defaultThinkingLevel'], 'high');
  });

  it('pins the personal startup identity to deepseek-v4.1-flash on high', () => {
    const personal: ProfileSettings = JSON.parse(
      readFileSync(join(PI_DIR, 'settings.personal.json'), 'utf8'),
    );
    assert.equal(personal['defaultProvider'], 'ollama-cloud');
    assert.equal(personal['defaultModel'], 'deepseek-v4.1-flash');
    assert.equal(personal['defaultThinkingLevel'], 'high');
  });
});

describe('skill-sync bucket scoping', () => {
  const PROFILES = ['work', 'personal'] as const;

  it('declares exclusions in the shape the skill scan matches', () => {
    for (const profile of PROFILES) {
      const entries = bucketExclusions(profile);
      assert.ok(entries.length > 0, `settings.${profile}.json excludes at least one bucket`);
      for (const entry of entries) {
        assert.match(entry, BUCKET_EXCLUSION, `${entry} is a bucket exclusion pattern`);
      }
    }
  });

  it('keeps an exclusion per Profile that the other does not share', () => {
    const work = new Set(excludedBucketPrefixes('work'));
    const personal = new Set(excludedBucketPrefixes('personal'));
    assert.ok(
      [...work].some((prefix) => !personal.has(prefix)),
      'work has an exclusion personal lacks, so the scoping is not lost',
    );
    assert.ok(
      [...personal].some((prefix) => !work.has(prefix)),
      'personal has an exclusion work lacks, so the scoping is not lost',
    );
  });
});