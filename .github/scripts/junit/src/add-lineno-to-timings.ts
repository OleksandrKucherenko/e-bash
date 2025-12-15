#!/usr/bin/env bun
/**
 * Add line numbers to test-timings.json by matching test names with shellspec --dry-run output.
 * 
 * Usage:
 *   bun add-lineno-to-timings.ts <test-timings.json> <output.json>
 * 
 * This script:
 * 1. Runs `shellspec --dry-run` to get test names with line numbers
 * 2. Matches test names from timing data to line numbers
 * 3. Updates the timing data with lineno field
 */

import { readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

interface ExampleTiming {
    time: number;
    name: string;
    lineno?: number;
}

interface FileTimingV2 {
    total: number;
    examples: { [exampleId: string]: ExampleTiming };
}

interface TimingDataV2 {
    version: "2.0";
    granularity: "example";
    timings: { [key: string]: FileTimingV2 };
    [key: string]: unknown;
}

export function parseShellspecExamplesLinenoOutput(stdout: string): Map<string, number[]> {
    const fileLineNumbers: Map<string, number[]> = new Map();
    for (const rawLine of stdout.trim().split("\n")) {
        const line = rawLine.trim();
        if (!line) continue;
        const match = line.match(/^(.+):(\d+)$/);
        if (!match) continue;
        const [, file, lineno] = match;
        const n = parseInt(lineno, 10);
        if (!Number.isFinite(n)) continue;
        if (!fileLineNumbers.has(file)) fileLineNumbers.set(file, []);
        fileLineNumbers.get(file)!.push(n);
    }
    return fileLineNumbers;
}

export function attachLinenoByOrder(
    data: TimingDataV2,
    fileLineNumbers: Map<string, number[]>,
    opts: { overwrite?: boolean } = {}
): number {
    const overwrite = opts.overwrite ?? true;
    let updatedCount = 0;

    for (const [file, fileData] of Object.entries(data.timings)) {
        const lineNumbers = fileLineNumbers.get(file);
        if (!lineNumbers) continue;

        const exampleEntries = Object.entries(fileData.examples);
        let lineIndex = 0;

        for (const [, example] of exampleEntries) {
            if (lineIndex >= lineNumbers.length) break;
            if (!overwrite && example.lineno !== undefined) {
                lineIndex++;
                continue;
            }
            example.lineno = lineNumbers[lineIndex];
            updatedCount++;
            lineIndex++;
        }
    }

    return updatedCount;
}

function main() {
    const args = process.argv.slice(2);
    if (args.length < 2) {
        console.error("Usage: bun add-lineno-to-timings.ts <input.json> <output.json>");
        process.exit(1);
    }

    const [inputFile, outputFile] = args;

    // Read timing data
    const content = readFileSync(inputFile, "utf-8");
    const data: TimingDataV2 = JSON.parse(content);

    if (data.version !== "2.0") {
        console.error("This script requires v2.0 timing data");
        process.exit(1);
    }

    // Get line numbers from shellspec - run from project root
    const projectRoot = new URL("../../../../", import.meta.url).pathname;
    const linenoResult = spawnSync("shellspec", ["--list", "examples:lineno"], {
        encoding: "utf-8",
        cwd: projectRoot,
    });

    if (linenoResult.error || !linenoResult.stdout) {
        console.error("Failed to get line numbers from shellspec");
        console.error("Error:", linenoResult.error);
        console.error("Stderr:", linenoResult.stderr);
        process.exit(1);
    }

    const fileLineNumbers = parseShellspecExamplesLinenoOutput(linenoResult.stdout);
    const updatedCount = attachLinenoByOrder(data, fileLineNumbers, { overwrite: true });

    // Write updated timing data
    writeFileSync(outputFile, JSON.stringify(data, null, 2) + "\n");
    console.log(`✅ Updated ${updatedCount} examples with line numbers`);
    console.log(`💾 Saved to: ${outputFile}`);
}

if (import.meta.main) {
    main();
}
