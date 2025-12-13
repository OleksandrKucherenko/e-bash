/**
 * Core chunking algorithm functions.
 * Exported for unit testing.
 */

export interface TestItem {
    name: string;
    weight: number;
    isExample?: boolean;
}

export interface ExampleTiming {
    time: number;
    name: string;
    lineno?: number;
}

export interface FileTimingV2 {
    total: number;
    examples: { [exampleId: string]: ExampleTiming };
}

// V1.0 format (file level)
export interface TimingDataV1 {
    version: "1.0";
    timings: { [key: string]: number };
    [key: string]: unknown;
}

// V2.0 format (example level)
export interface TimingDataV2 {
    version: "2.0";
    granularity: "example";
    timings: { [key: string]: FileTimingV2 };
    [key: string]: unknown;
}

export type TimingData = TimingDataV1 | TimingDataV2;
export type Granularity = "file" | "example" | "hybrid";

/**
 * First Fit Decreasing (FFD) bin-packing algorithm.
 * Distributes items across bins to minimize maximum bin weight.
 */
export function binPackingFFD(items: TestItem[], numBins: number): [TestItem[][], number[]] {
    // Sort items by weight descending
    const sortedItems = [...items].sort((a, b) => b.weight - a.weight);

    // Initialize bins
    const bins: TestItem[][] = Array.from({ length: numBins }, () => []);
    const binWeights: number[] = Array(numBins).fill(0);

    // Assign each item to the bin with minimum weight
    for (const item of sortedItems) {
        const minIdx = binWeights.indexOf(Math.min(...binWeights));
        bins[minIdx].push(item);
        binWeights[minIdx] += item.weight;
    }

    return [bins, binWeights];
}

/**
 * Build items list at file granularity from timing data
 */
export function buildFileItemsFromTimings(
    specFiles: string[],
    timings: { [key: string]: number },
    defaultWeight: number = 100
): { items: TestItem[]; usingStatic: string[] } {
    const items: TestItem[] = [];
    const usingStatic: string[] = [];

    for (const specFile of specFiles) {
        let weight: number;

        if (timings[specFile] && timings[specFile] > 0) {
            weight = timings[specFile];
        } else {
            weight = defaultWeight;
            usingStatic.push(specFile);
        }

        items.push({ name: specFile, weight });
    }

    return { items, usingStatic };
}

/**
 * Build items list at example granularity from V2 timing data
 */
export function buildExampleItemsFromTimings(
    specFiles: string[],
    v2Timings: { [file: string]: FileTimingV2 },
    defaultWeight: number = 100
): { items: TestItem[]; usingStatic: string[] } {
    const items: TestItem[] = [];
    const usingStatic: string[] = [];

    for (const specFile of specFiles) {
        const fileData = v2Timings[specFile];

        if (fileData && fileData.examples && Object.keys(fileData.examples).length > 0) {
            // Add individual examples
            for (const [exampleId, example] of Object.entries(fileData.examples)) {
                items.push({
                    name: `${specFile}:${exampleId}`,
                    weight: example.time,
                    isExample: true,
                });
            }
        } else {
            // No example data, use file-level
            const weight = fileData?.total || defaultWeight;
            items.push({ name: specFile, weight });

            if (!fileData?.total) {
                usingStatic.push(specFile);
            }
        }
    }

    return { items, usingStatic };
}

/**
 * Collapse consecutive example IDs from same file for cleaner output
 * e.g., "spec/a.sh:@1 spec/a.sh:@2" -> "spec/a.sh:@1:@2"
 */
export function collapseExampleOutput(chunkItems: TestItem[]): string[] {
    const fileGroups: { [file: string]: string[] } = {};
    const fileOrder: string[] = [];

    for (const item of chunkItems) {
        if (item.isExample) {
            const colonIndex = item.name.indexOf(":");
            const file = item.name.substring(0, colonIndex);
            const exampleId = item.name.substring(colonIndex + 1);

            if (!fileGroups[file]) {
                fileGroups[file] = [];
                fileOrder.push(file);
            }
            fileGroups[file].push(exampleId);
        } else {
            // Whole file - add directly
            if (!fileGroups[item.name]) {
                fileOrder.push(item.name);
                fileGroups[item.name] = [];
            }
        }
    }

    const output: string[] = [];
    const processed = new Set<string>();

    for (const file of fileOrder) {
        if (processed.has(file)) continue;
        processed.add(file);

        const examples = fileGroups[file];
        if (!examples || examples.length === 0) {
            output.push(file);
        } else {
            output.push(`${file}:${examples.join(":")}`);
        }
    }

    return output;
}

/**
 * Parse CLI arguments for chunk calculation
 */
export function parseChunkArgs(args: string[]): {
    timingFile: string;
    numChunks: number;
    chunkIndex: number;
    granularity: Granularity;
} | null {
    let granularity: Granularity = "file";
    const positionalArgs: string[] = [];

    for (const arg of args) {
        if (arg.startsWith("--granularity=")) {
            const value = arg.split("=")[1];
            if (value === "file" || value === "example" || value === "hybrid") {
                granularity = value;
            }
        } else if (!arg.startsWith("--")) {
            positionalArgs.push(arg);
        }
    }

    if (positionalArgs.length !== 3) {
        return null;
    }

    const numChunks = parseInt(positionalArgs[1]);
    const chunkIndex = parseInt(positionalArgs[2]);

    if (isNaN(numChunks) || isNaN(chunkIndex)) {
        return null;
    }

    if (chunkIndex < 0 || chunkIndex >= numChunks) {
        return null;
    }

    return {
        timingFile: positionalArgs[0],
        numChunks,
        chunkIndex,
        granularity,
    };
}

/**
 * Calculate static weight for a spec file based on content analysis
 */
export function calculateStaticWeightFromContent(content: string): number {
    const lines = content.split("\n");
    const lineCount = lines.length;

    const testBlocks = lines.filter((line) => {
        const trimmed = line.trim();
        return (
            trimmed.startsWith("It ") ||
            trimmed.startsWith("Describe ") ||
            trimmed.startsWith("Context ")
        );
    }).length;

    return lineCount + testBlocks * 10;
}
