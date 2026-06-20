// Converts the 118 canonical YAML files into a single minified elements.raw.json
// containing only the stored fields pt-domain::Element holds.
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import yaml from 'js-yaml';

const SRC = '/Users/samutup/Developer/codews/periodic-table/data/elements';
const OUT = new URL('../ChemCore/Sources/ChemCore/Resources/elements.raw.json', import.meta.url);

const STATE = { solid: 'Solid', liquid: 'Liquid', gas: 'Gas' };
const KEYS = ['atomic_number','name','symbol','atomic_mass','mass_number','melting_point',
  'boiling_point','density','electronegativity','state','discovery_year','discoverer','isotopes'];

const elements = readdirSync(SRC)
  .filter(f => f.endsWith('.yaml'))
  .map(f => yaml.load(readFileSync(join(SRC, f), 'utf8')))
  .map(e => {
    const out = {};
    for (const k of KEYS) {
      if (e[k] === undefined || e[k] === null) continue;
      out[k] = k === 'state' ? (STATE[e[k]] ?? e[k]) : e[k];
    }
    return out;
  })
  .sort((a, b) => a.atomic_number - b.atomic_number);

if (elements.length !== 118) throw new Error(`expected 118 elements, got ${elements.length}`);
writeFileSync(OUT, JSON.stringify(elements));
console.log(`wrote ${elements.length} elements to elements.raw.json`);
