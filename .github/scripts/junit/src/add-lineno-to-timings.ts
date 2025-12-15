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

function getTestLineNumbers(): Map<string, Map<string, number>> {
    // Run shellspec --dry-run to get test names with line info
    const result = spawnSync("shellspec", ["--dry-run", "--format", "documentation"], {
        encoding: "utf-8",
        maxBuffer: 10 * 1024 * 1024,
    });

    if (result.error) {
        console.error("Failed to run shellspec:", result.error);
        process.exit(1);
    }

    // Also get examples with line numbers
    const linenoResult = spawnSync("shellspec", ["--list", "examples:lineno"], {
        encoding: "utf-8",
    });

    const lineMap = new Map<string, Map<string, number>>();

    if (linenoResult.stdout) {
        // Parse: spec/file.sh:35
        const lines = linenoResult.stdout.trim().split("\n");
        for (const line of lines) {
            const match = line.match(/^(.+):(\d+)$/);
            if (match) {
                const [, file, lineno] = match;
                if (!lineMap.has(file)) {
                    lineMap.set(file, new Map());
                }
                // Store line number indexed by line number (we'll match by position later)
                lineMap.get(file)!.set(lineno, parseInt(lineno, 10));
            }
        }
    }

    return lineMap;
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

    // Build mapping: file -> array of line numbers (in order)
    const fileLineNumbers: Map<string, number[]> = new Map();
    const lines = linenoResult.stdout.trim().split("\n");
    for (const line of lines) {
        const match = line.match(/^(.+):(\d+)$/);
        if (match) {
            const [, file, lineno] = match;
            if (!fileLineNumbers.has(file)) {
                fileLineNumbers.set(file, []);
            }
            fileLineNumbers.get(file)!.push(parseInt(lineno, 10));
        }
    }

    // Update timing data with line numbers
    let updatedCount = 0;

    for (const [file, fileData] of Object.entries(data.timings)) {
        const lineNumbers = fileLineNumbers.get(file);
        if (!lineNumbers) {
            console.error(`Warning: No line numbers found for ${file}`);
            continue;
        }

        // Sort examples by their order in the file (assuming hash order corresponds to order in XML)
        const exampleEntries = Object.entries(fileData.examples);

        // Assign line numbers based on order
        // This assumes the examples in timing data are in the same order as in the spec file
        let lineIndex = 0;
        for (const [exampleId, example] of exampleEntries) {
            if (lineIndex < lineNumbers.length) {
                example.lineno = lineNumbers[lineIndex];
                updatedCount++;
                lineIndex++;
            }
        }
    }

    // Write updated timing data
    writeFileSync(outputFile, JSON.stringify(data, null, 2) + "\n");
    console.log(`✅ Updated ${updatedCount} examples with line numbers`);
    console.log(`💾 Saved to: ${outputFile}`);
}

main();
