/**
 * Core parsing and utility functions for JUnit XML timing extraction.
 * Exported for unit testing.
 */

import { readFileSync, existsSync } from "node:fs";

// V1.0 format (backward compatible)
export interface TimingDataV1 {
    [specFile: string]: number;
}

// V2.0 format (per-example granularity)
export interface ExampleTiming {
    time: number;
    name: string;
    lineno?: number;
}

export interface FileTimingV2 {
    total: number;
    examples: { [exampleId: string]: ExampleTiming };
}

export interface TimingDataV2 {
    [specFile: string]: FileTimingV2;
}

// Parsed example with all metadata
export interface ParsedExample {
    specFile: string;
    exampleId: string;
    time: number;
    name: string;
    lineno?: number;
}

export type Granularity = "file" | "example";

/**
 * Normalize spec file path to consistent format
 */
export function normalizeSpecPath(specFile: string): string {
    // Remove leading ./
    if (specFile.startsWith("./")) {
        specFile = specFile.slice(2);
    }

    // Ensure it starts with spec/
    if (!specFile.startsWith("spec/")) {
        if (specFile.startsWith("/")) {
            // Extract spec/ portion from absolute path
            const parts = specFile.split("/");
            const specIndex = parts.indexOf("spec");
            if (specIndex >= 0) {
                specFile = parts.slice(specIndex).join("/");
            } else {
                // No spec/ in path - use just the filename
                const filename = parts[parts.length - 1];
                specFile = `spec/${filename}`;
            }
        } else {
            specFile = `spec/${specFile}`;
        }
    }

    return specFile;
}

/**
 * Extract example ID from test name using shellspec conventions.
 */
export function extractExampleId(testName: string, index: number): string {
    return `@${index + 1}`;
}

/**
 * Parse JUnit XML content for file-level timing (v1.0 format)
 * This version takes XML content directly for easier testing.
 */
export function parseJUnitXMLContent(xmlContent: string): TimingDataV1 {
    const timings: TimingDataV1 = {};

    // Match testcase elements with time attribute
    const testcaseRegex = /<testcase[^>]*>/g;
    const matches = xmlContent.match(testcaseRegex);

    if (matches) {
        for (const testcaseTag of matches) {
            // Extract attributes
            const classnameMatch = testcaseTag.match(/classname="([^"]*)"/);
            const nameMatch = testcaseTag.match(/name="([^"]*)"/);
            const timeMatch = testcaseTag.match(/time="([^"]*)"/);

            const classname = classnameMatch ? classnameMatch[1] : "";
            const name = nameMatch ? nameMatch[1] : "";
            const timeStr = timeMatch ? timeMatch[1] : "0";

            let timeVal = parseFloat(timeStr);
            if (isNaN(timeVal)) {
                timeVal = 0;
            }

            // Extract spec file from classname or name
            let specFile = classname || name;

            // Sometimes the spec file is in the name if classname is not a path
            if (specFile && !specFile.endsWith(".sh")) {
                const parts = name.split(/\s+/);
                for (const part of parts) {
                    if (part.endsWith("_spec.sh")) {
                        specFile = part;
                        break;
                    }
                }
            }

            if (specFile && specFile.endsWith(".sh")) {
                const normalized = normalizeSpecPath(specFile);
                timings[normalized] = (timings[normalized] || 0) + timeVal;
            }
        }
    }

    // Also try to extract from testsuite time attribute as fallback
    const testsuiteRegex = /<testsuite[^>]*>/g;
    const suiteMatches = xmlContent.match(testsuiteRegex);

    if (suiteMatches) {
        for (const suiteTag of suiteMatches) {
            const nameMatch = suiteTag.match(/name="([^"]*)"/);
            const timeMatch = suiteTag.match(/time="([^"]*)"/);

            if (nameMatch && timeMatch) {
                const specFile = nameMatch[1];
                const timeStr = timeMatch[1];
                const timeVal = parseFloat(timeStr);

                if (!isNaN(timeVal) && timeVal > 0 && specFile.endsWith(".sh")) {
                    const normalized = normalizeSpecPath(specFile);
                    // Use testsuite time if we don't have testcase times or they're zero
                    if (timings[normalized] === undefined || timings[normalized] === 0) {
                        timings[normalized] = timeVal;
                    }
                }
            }
        }
    }

    return timings;
}

/**
 * Parse JUnit XML content for example-level timing (v2.0 format)
 */
export function parseJUnitXMLContentExamples(xmlContent: string): ParsedExample[] {
    const examples: ParsedExample[] = [];
    const fileExampleCounts: { [file: string]: number } = {};

    const testcaseRegex = /<testcase[^>]*>/g;
    const matches = xmlContent.match(testcaseRegex);

    if (!matches) {
        return examples;
    }

    for (const testcaseTag of matches) {
        const classnameMatch = testcaseTag.match(/classname="([^"]*)"/);
        const nameMatch = testcaseTag.match(/name="([^"]*)"/);
        const timeMatch = testcaseTag.match(/time="([^"]*)"/);

        const classname = classnameMatch ? classnameMatch[1] : "";
        const name = nameMatch ? nameMatch[1] : "";
        const timeStr = timeMatch ? timeMatch[1] : "0";

        let timeVal = parseFloat(timeStr);
        if (isNaN(timeVal)) {
            timeVal = 0;
        }

        let specFile = classname;
        if (!specFile || !specFile.endsWith(".sh")) {
            const parts = name.split(/\s+/);
            for (const part of parts) {
                if (part.endsWith("_spec.sh")) {
                    specFile = part;
                    break;
                }
            }
        }

        if (specFile && specFile.endsWith(".sh")) {
            const normalized = normalizeSpecPath(specFile);

            if (!fileExampleCounts[normalized]) {
                fileExampleCounts[normalized] = 0;
            }
            const exampleIndex = fileExampleCounts[normalized]++;

            examples.push({
                specFile: normalized,
                exampleId: extractExampleId(name, exampleIndex),
                time: timeVal,
                name: name,
            });
        }
    }

    return examples;
}

/**
 * Merge multiple timing data sets into one (averaging times)
 */
export function mergeTimingsV1(allTimings: TimingDataV1[]): TimingDataV1 {
    const merged: { [key: string]: number[] } = {};

    for (const timingDict of allTimings) {
        for (const [specFile, timeVal] of Object.entries(timingDict)) {
            if (!merged[specFile]) {
                merged[specFile] = [];
            }
            merged[specFile].push(timeVal);
        }
    }

    const result: TimingDataV1 = {};
    for (const [specFile, times] of Object.entries(merged)) {
        result[specFile] = times.reduce((a, b) => a + b, 0) / times.length;
    }

    return result;
}

/**
 * Merge examples into V2 timing format
 */
export function mergeExamplesToV2(allExamples: ParsedExample[][]): TimingDataV2 {
    const result: TimingDataV2 = {};
    const fileGroups: { [file: string]: { [exampleId: string]: ParsedExample[] } } = {};

    for (const examples of allExamples) {
        for (const example of examples) {
            if (!fileGroups[example.specFile]) {
                fileGroups[example.specFile] = {};
            }
            if (!fileGroups[example.specFile][example.exampleId]) {
                fileGroups[example.specFile][example.exampleId] = [];
            }
            fileGroups[example.specFile][example.exampleId].push(example);
        }
    }

    for (const [specFile, exampleGroups] of Object.entries(fileGroups)) {
        let fileTotal = 0;
        const examples: { [id: string]: ExampleTiming } = {};

        for (const [exampleId, exampleList] of Object.entries(exampleGroups)) {
            const avgTime = exampleList.reduce((sum, e) => sum + e.time, 0) / exampleList.length;
            const firstName = exampleList[0].name;

            examples[exampleId] = {
                time: avgTime,
                name: firstName,
            };
            fileTotal += avgTime;
        }

        result[specFile] = {
            total: fileTotal,
            examples,
        };
    }

    return result;
}

/**
 * Parse granularity from command line args
 */
export function parseGranularity(args: string[]): { granularity: Granularity; filteredArgs: string[] } {
    let granularity: Granularity = "file";
    const filteredArgs: string[] = [];

    for (const arg of args) {
        if (arg.startsWith("--granularity=")) {
            const value = arg.split("=")[1];
            if (value === "file" || value === "example") {
                granularity = value;
            }
        } else if (!arg.startsWith("--")) {
            filteredArgs.push(arg);
        }
    }

    return { granularity, filteredArgs };
}
