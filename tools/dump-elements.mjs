// Dumps the existing WASM's full computed output to the golden test fixture.
// This file is a dev-time fidelity check only and never ships in the app.
import { writeFileSync } from 'node:fs';
import { PeriodicTable } from '/Users/samutup/Developer/codews/chem-interactive/src/wasm/pkg/pt_wasm.js';

const OUT = new URL('../ChemCore/Tests/ChemCoreTests/Fixtures/elements.golden.json', import.meta.url);
const all = PeriodicTable.load().all().sort((a, b) => a.atomic_number - b.atomic_number);
if (all.length !== 118) throw new Error(`expected 118 elements, got ${all.length}`);
writeFileSync(OUT, JSON.stringify(all));
console.log(`wrote ${all.length} elements to elements.golden.json`);
