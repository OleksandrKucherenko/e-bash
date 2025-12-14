#!/usr/bin/env bun
/**
 * Calculate optimal test chunk distribution using bin-packing algorithm.
 *
 * This script uses First Fit Decreasing (FFD) algorithm to distribute test items
 * across chunks to minimize maximum chunk execution time.
 *
 * Supports three granularity levels:
 *   - file: Distribute whole spec files (default, faster)
 *   - example: Distribute individual examples (finer balance, requires v2.0 timing data)
 *   - hybrid: Auto-split large files into examples when beneficial
 *
 * Usage:
 *   bun calculate-optimal-chunks.ts <timing_json> <num_chunks> <chunk_index> [--granularity=file|example|hybrid]
 *
 * Example:
 *   bun calculate-optimal-chunks.ts .test-timings.json 4 0
 *   bun calculate-optimal-chunks.ts .test-timings.json 4 0 --granularity=example
 *
 * Output:
 *   Space-separated list of spec files (or file:@id for example granularity) for the specified chunk
 */

import { readFileSync, existsSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import {
    binPackingFFD,
    buildFileItemsFromTimings,
    buildExampleItemsFromTimings,
    collapseExampleOutput,
    parseChunkArgs,
    calculateStaticWeightFromContent,
    type TestItem,
    type FileTimingV2,
    type TimingData,
    type Granularity,
} from "./lib/chunker";

// Re-export types for V1/V2 timing data
interface TimingDataV1 {
    version: "1.0";
    timings: { [key: string]: number };
    [key: string]: unknown;
}

interface TimingDataV2 {
    version: "2.0";
    granularity: "example";
    timings: { [key: string]: FileTimingV2 };
    [key: string]: unknown;
}

function loadTimings(timingFile: string): TimingData | null {
    try {
        if (!existsSync(timingFile)) {
            return null;
        }

        const content = readFileSync(timingFile, "utf-8");
        const data = JSON.parse(content);
        return data as TimingData;
    } catch (error) {
        console.error(`Error loading timing data: ${error}`);
        return null;
    }
}

function calculateStaticWeight(specFile: string, projectRoot: string): number {
    const filePath = join(projectRoot, specFile);

    if (!existsSync(filePath)) {
        return 100;
    }

    try {
        const content = readFileSync(filePath, "utf-8");
        return calculateStaticWeightFromContent(content);
    } catch (error) {
        console.error(`Warning: Failed to calculate weight for ${specFile}:`, error);
        return 100;
    }
}

function getAllSpecFiles(projectRoot: string): string[] {
    const specDir = join(projectRoot, "spec");
    if (!existsSync(specDir)) {
        return [];
    }

    const specFiles: string[] = [];

    function walkDir(dir: string) {
        const entries = readdirSync(dir);
        for (const entry of entries) {
            const fullPath = join(dir, entry);
            const stat = statSync(fullPath);

            if (stat.isDirectory()) {
                walkDir(fullPath);
            } else if (entry.endsWith("_spec.sh")) {
                const relPath = fullPath.replace(projectRoot + "/", "");
                specFiles.push(relPath);
            }
        }
    }

    walkDir(specDir);
    return specFiles.sort();
}

/**
 * Build items with static weight calculation for files without timing data
 */
function buildItemsWithStaticFallback(
    specFiles: string[],
    timings: { [key: string]: number },
    projectRoot: string
): { items: TestItem[]; usingStatic: string[] } {
    const items: TestItem[] = [];
    const usingStatic: string[] = [];

    for (const specFile of specFiles) {
        let weight: number;

        if (timings[specFile] && timings[specFile] > 0) {
            weight = timings[specFile];
        } else {
            weight = calculateStaticWeight(specFile, projectRoot);
            usingStatic.push(specFile);
        }

        items.push({ name: specFile, weight });
    }

    return { items, usingStatic };
}

/**
 * Build hybrid items - split large files into examples
 */
function buildHybridItems(
    allSpecFiles: string[],
    timingData: TimingData | null,
    projectRoot: string,
    numChunks: number
): { items: TestItem[]; usingStatic: string[]; splitFiles: string[] } {
    const items: TestItem[] = [];
    const usingStatic: string[] = [];
    const splitFiles: string[] = [];

    let fileTimings: { [key: string]: number } = {};
    let exampleData: { [file: string]: { [id: string]: { time: number; name: string } } } = {};
    const isV2 = timingData?.version === "2.0";

    if (timingData) {
        if (isV2) {
            const v2Data = timingData as TimingDataV2;
            for (const [file, data] of Object.entries(v2Data.timings)) {
                if (typeof data === "object" && data !== null && "total" in data) {
                    const fileData = data as FileTimingV2;
                    fileTimings[file] = fileData.total;
                    if (fileData.examples) {
                        exampleData[file] = fileData.examples;
                    }
                }
            }
        } else {
            fileTimings = (timingData as TimingDataV1).timings || {};
        }
    }

    // Calculate total time and target per chunk
    let totalTime = 0;
    for (const specFile of allSpecFiles) {
        totalTime += fileTimings[specFile] || calculateStaticWeight(specFile, projectRoot);
    }
    const targetPerChunk = totalTime / numChunks;
    const splitThreshold = targetPerChunk * 0.5;

    for (const specFile of allSpecFiles) {
        const fileTime = fileTimings[specFile] || 0;
        const hasExamples = exampleData[specFile] && Object.keys(exampleData[specFile]).length > 0;

        if (fileTime > splitThreshold && hasExamples) {
            splitFiles.push(specFile);

            for (const [exampleId, example] of Object.entries(exampleData[specFile])) {
                items.push({
                    name: `${specFile}:${exampleId}`,
                    weight: example.time,
                    isExample: true,
                });
            }
        } else {
            let weight: number;
            if (fileTime > 0) {
                weight = fileTime;
            } else {
                weight = calculateStaticWeight(specFile, projectRoot);
                usingStatic.push(specFile);
            }
            items.push({ name: specFile, weight });
        }
    }

    return { items, usingStatic, splitFiles };
}

function main() {
    const parsed = parseChunkArgs(process.argv.slice(2));

    if (!parsed) {
        console.error(`Usage: bun calculate-optimal-chunks.ts <timing_json> <num_chunks> <chunk_index> [--granularity=file|example|hybrid]`);
        console.error(`\nExample: bun calculate-optimal-chunks.ts .test-timings.json 4 0`);
        console.error(`         bun calculate-optimal-chunks.ts .test-timings.json 4 0 --granularity=example`);
        process.exit(1);
    }

    const { timingFile, numChunks, chunkIndex, granularity } = parsed;

    // Get project root (parent of bin/junit directory)
    const scriptDir = import.meta.dir;
    const projectRoot = join(scriptDir, "../..");

    // Load timing data
    const timingData = loadTimings(timingFile);

    // Get all spec files
    const allSpecFiles = getAllSpecFiles(projectRoot);

    if (allSpecFiles.length === 0) {
        console.error("Error: No spec files found");
        process.exit(1);
    }

    // Build items list based on granularity
    let items: TestItem[];
    let usingStatic: string[] = [];
    let effectiveGranularity = granularity;

    console.error(`🔧 Granularity: ${granularity}`);

    if (granularity === "file") {
        // Extract file timings from data
        let fileTimings: { [key: string]: number } = {};
        if (timingData) {
            if (timingData.version === "2.0") {
                for (const [file, data] of Object.entries((timingData as TimingDataV2).timings)) {
                    if (typeof data === "object" && data !== null && "total" in data) {
                        fileTimings[file] = (data as FileTimingV2).total;
                    }
                }
            } else {
                fileTimings = (timingData as TimingDataV1).timings || {};
            }
        }

        const result = buildItemsWithStaticFallback(allSpecFiles, fileTimings, projectRoot);
        items = result.items;
        usingStatic = result.usingStatic;
    } else if (granularity === "example") {
        // Check if we have V2 data
        if (!timingData || timingData.version !== "2.0") {
            console.error("⚠️  Example-level granularity requires v2.0 timing data, falling back to file level");
            effectiveGranularity = "file";

            let fileTimings: { [key: string]: number } = {};
            if (timingData) {
                fileTimings = (timingData as TimingDataV1).timings || {};
            }

            const result = buildItemsWithStaticFallback(allSpecFiles, fileTimings, projectRoot);
            items = result.items;
            usingStatic = result.usingStatic;
        } else {
            const v2Timings: { [file: string]: FileTimingV2 } = {};
            for (const [file, data] of Object.entries((timingData as TimingDataV2).timings)) {
                if (typeof data === "object" && data !== null && "total" in data) {
                    v2Timings[file] = data as FileTimingV2;
                }
            }

            const result = buildExampleItemsFromTimings(allSpecFiles, v2Timings, 100);
            items = result.items;
            usingStatic = result.usingStatic;
        }
    } else {
        // hybrid
        const result = buildHybridItems(allSpecFiles, timingData, projectRoot, numChunks);
        items = result.items;
        usingStatic = result.usingStatic;
        if (result.splitFiles.length > 0) {
            console.error(`📦 Split ${result.splitFiles.length} large files into examples`);
        }
    }

    if (usingStatic.length > 0) {
        console.error(`ℹ️  Using static weights for ${usingStatic.length} files (no timing data)`);
    }

    console.error(`📋 Total items to distribute: ${items.length}`);

    // Calculate optimal distribution
    const [bins, binWeights] = binPackingFFD(items, numChunks);

    // Debug output
    const totalWeight = binWeights.reduce((a, b) => a + b, 0);
    const avgWeight = totalWeight / numChunks;
    const maxWeight = binWeights.length > 0 ? Math.max(...binWeights) : 0;
    const minWeight = binWeights.length > 0 ? Math.min(...binWeights) : 0;

    function formatDurationSeconds(seconds: number): string {
        if (!Number.isFinite(seconds)) return `${seconds}`;
        const total = Math.max(0, seconds);
        const hours = Math.floor(total / 3600);
        const minutes = Math.floor((total % 3600) / 60);
        const secs = total % 60;

        if (hours > 0) return `${hours}h${minutes}m${secs.toFixed(0)}s`;
        if (minutes > 0) return `${minutes}m${secs.toFixed(0)}s`;
        return `${total.toFixed(1)}s`;
    }

    const requestedWeight = binWeights[chunkIndex] ?? 0;
    const requestedDeviation = avgWeight > 0 ? ((requestedWeight - avgWeight) / avgWeight) * 100 : 0;
    console.error(
        `⏱️  Estimated time for chunk ${chunkIndex}/${numChunks - 1}: ${formatDurationSeconds(requestedWeight)} (${requestedWeight.toFixed(
            1
        )}s, ${requestedDeviation >= 0 ? "+" : ""}${requestedDeviation.toFixed(0)}% vs avg ${avgWeight.toFixed(
            1
        )}s; min ${formatDurationSeconds(minWeight)}, max ${formatDurationSeconds(maxWeight)})`
    );

    console.error(`📊 Chunk distribution (bin-packing algorithm):`);
    for (let i = 0; i < bins.length; i++) {
        const weight = binWeights[i];
        const deviation = avgWeight > 0 ? ((weight - avgWeight) / avgWeight) * 100 : 0;
        const exampleCount = bins[i].filter((item) => item.isExample).length;
        const fileCount = bins[i].filter((item) => !item.isExample).length;

        let itemDesc = `${bins[i].length} items`;
        if (effectiveGranularity !== "file" && exampleCount > 0) {
            itemDesc = `${fileCount} files, ${exampleCount} examples`;
        } else {
            itemDesc = `${bins[i].length} files`;
        }

        console.error(
            `  Chunk ${i}: ${weight.toFixed(1)}s (${itemDesc}, ${deviation >= 0 ? "+" : ""}${deviation.toFixed(0)}% vs avg)`
        );
    }

    // Output files for requested chunk
    const chunkItems = bins[chunkIndex];
    if (chunkItems.length > 0) {
        let output: string[];

        if (effectiveGranularity === "file") {
            output = chunkItems.map((item) => item.name);
        } else {
            output = collapseExampleOutput(chunkItems);
        }

        console.log(output.join(" "));
    } else {
        console.log("");
    }
}

main();
