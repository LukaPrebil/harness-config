/**
 * Parity tests for the pi Profile settings pair. Startup identity is
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
 * lastChangelogVersion, which pi writes back per Profile at runtime.
 */
const PER_PROFILE_KEYS = [
  'defaultProvider',
  'defaultModel',
  'defaultThinkingLevel',
  'lastChangelogVersion',
] as const;

type ProfileSettings = Record<string, unknown>;

function loadSettings(profile: 'work' | 'personal'): ProfileSettings {
  const raw: ProfileSettings = JSON.parse(
    readFileSync(join(PI_DIR, `settings.${profile}.json`), 'utf8'),
  );
  for (const key of PER_PROFILE_KEYS) delete raw[key];
  return raw;
}

describe('profile settings parity', () => {
  it('keeps every non-Profile key identical across work and personal', () => {
    assert.deepEqual(loadSettings('work'), loadSettings('personal'));
  });

  it('pins the work startup identity to gpt-6-astra on high', () => {
    const work: ProfileSettings = JSON.parse(
      readFileSync(join(PI_DIR, 'settings.work.json'), 'utf8'),
    );
    assert.equal(work['defaultProvider'], 'openai-codex');
    assert.equal(work['defaultModel'], 'gpt-6-astra');
    assert.equal(work['defaultThinkingLevel'], 'high');
  });

  it('pins the personal startup identity to glm-5.3-flash on high', () => {
    const personal: ProfileSettings = JSON.parse(
      readFileSync(join(PI_DIR, 'settings.personal.json'), 'utf8'),
    );
    assert.equal(personal['defaultProvider'], 'ollama-cloud');
    assert.equal(personal['defaultModel'], 'glm-5.3-flash');
    assert.equal(personal['defaultThinkingLevel'], 'high');
  });
});