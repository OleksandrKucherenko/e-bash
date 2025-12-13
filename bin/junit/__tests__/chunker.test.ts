/**
 * Unit tests for chunk calculation functions.
 * Run with: bun test
 */

import { describe, test, expect } from "bun:test";
import {
    binPackingFFD,
    buildFileItemsFromTimings,
    buildExampleItemsFromTimings,
    collapseExampleOutput,
    parseChunkArgs,
    calculateStaticWeightFromContent,
    type TestItem,
    type FileTimingV2,
} from "../lib/chunker";

describe("binPackingFFD", () => {
    test("distributes items evenly across bins", () => {
        const items: TestItem[] = [
            { name: "a", weight: 10 },
            { name: "b", weight: 20 },
            { name: "c", weight: 15 },
            { name: "d", weight: 25 },
        ];

        const [bins, weights] = binPackingFFD(items, 2);

        expect(bins).toHaveLength(2);
        expect(weights).toHaveLength(2);

        // Total weight should be preserved
        const totalWeight = weights.reduce((a, b) => a + b, 0);
        expect(totalWeight).toBe(70);

        // Weights should be balanced (difference should be small)
        const maxWeight = Math.max(...weights);
        const minWeight = Math.min(...weights);
        expect(maxWeight - minWeight).toBeLessThanOrEqual(20); // Reasonable balance
    });

    test("handles single item", () => {
        const items: TestItem[] = [{ name: "a", weight: 100 }];
        const [bins, weights] = binPackingFFD(items, 3);

        expect(bins[0]).toHaveLength(1);
        expect(bins[1]).toHaveLength(0);
        expect(bins[2]).toHaveLength(0);
        expect(weights[0]).toBe(100);
    });

    test("handles empty items list", () => {
        const [bins, weights] = binPackingFFD([], 4);

        expect(bins).toHaveLength(4);
        bins.forEach((bin) => expect(bin).toHaveLength(0));
        weights.forEach((w) => expect(w).toBe(0));
    });

    test("assigns heaviest items first to different bins", () => {
        const items: TestItem[] = [
            { name: "small1", weight: 1 },
            { name: "small2", weight: 1 },
            { name: "large1", weight: 100 },
            { name: "large2", weight: 100 },
        ];

        const [bins, weights] = binPackingFFD(items, 2);

        // Each bin should have one large and potentially small items
        // The algorithm should put large items in different bins
        expect(Math.abs(weights[0] - weights[1])).toBeLessThanOrEqual(2);
    });

    test("achieves optimal distribution for known case", () => {
        // Classic bin-packing example
        const items: TestItem[] = [
            { name: "a", weight: 7 },
            { name: "b", weight: 5 },
            { name: "c", weight: 5 },
            { name: "d", weight: 3 },
            { name: "e", weight: 3 },
            { name: "f", weight: 2 },
        ];

        const [bins, weights] = binPackingFFD(items, 3);

        // Total = 25, ideal = ~8.3 per bin
        // FFD should achieve close to optimal
        const maxWeight = Math.max(...weights);
        expect(maxWeight).toBeLessThanOrEqual(10);
    });
});

describe("buildFileItemsFromTimings", () => {
    test("builds items from timing data", () => {
        const specFiles = ["spec/a_spec.sh", "spec/b_spec.sh"];
        const timings = {
            "spec/a_spec.sh": 5.0,
            "spec/b_spec.sh": 10.0,
        };

        const { items, usingStatic } = buildFileItemsFromTimings(specFiles, timings);

        expect(items).toHaveLength(2);
        expect(items[0]).toEqual({ name: "spec/a_spec.sh", weight: 5.0 });
        expect(items[1]).toEqual({ name: "spec/b_spec.sh", weight: 10.0 });
        expect(usingStatic).toHaveLength(0);
    });

    test("uses default weight for missing timing data", () => {
        const specFiles = ["spec/a_spec.sh", "spec/b_spec.sh"];
        const timings = { "spec/a_spec.sh": 5.0 };

        const { items, usingStatic } = buildFileItemsFromTimings(specFiles, timings, 100);

        expect(items[0].weight).toBe(5.0);
        expect(items[1].weight).toBe(100);
        expect(usingStatic).toContain("spec/b_spec.sh");
    });

    test("treats zero timing as missing", () => {
        const specFiles = ["spec/a_spec.sh"];
        const timings = { "spec/a_spec.sh": 0 };

        const { items, usingStatic } = buildFileItemsFromTimings(specFiles, timings, 50);

        expect(items[0].weight).toBe(50);
        expect(usingStatic).toContain("spec/a_spec.sh");
    });
});

describe("buildExampleItemsFromTimings", () => {
    test("builds example-level items from V2 timing data", () => {
        const specFiles = ["spec/a_spec.sh"];
        const v2Timings: { [file: string]: FileTimingV2 } = {
            "spec/a_spec.sh": {
                total: 3.0,
                examples: {
                    "@1": { time: 1.0, name: "test 1" },
                    "@2": { time: 2.0, name: "test 2" },
                },
            },
        };

        const { items, usingStatic } = buildExampleItemsFromTimings(specFiles, v2Timings);

        expect(items).toHaveLength(2);
        expect(items[0]).toEqual({
            name: "spec/a_spec.sh:@1",
            weight: 1.0,
            isExample: true,
        });
        expect(items[1]).toEqual({
            name: "spec/a_spec.sh:@2",
            weight: 2.0,
            isExample: true,
        });
        expect(usingStatic).toHaveLength(0);
    });

    test("falls back to file-level for files without examples", () => {
        const specFiles = ["spec/a_spec.sh", "spec/b_spec.sh"];
        const v2Timings: { [file: string]: FileTimingV2 } = {
            "spec/a_spec.sh": {
                total: 5.0,
                examples: {},
            },
        };

        const { items, usingStatic } = buildExampleItemsFromTimings(specFiles, v2Timings, 100);

        expect(items).toHaveLength(2);
        expect(items[0]).toEqual({ name: "spec/a_spec.sh", weight: 5.0 });
        expect(items[1]).toEqual({ name: "spec/b_spec.sh", weight: 100 });
        expect(usingStatic).toContain("spec/b_spec.sh");
    });
});

describe("collapseExampleOutput", () => {
    test("collapses examples from same file", () => {
        const items: TestItem[] = [
            { name: "spec/a_spec.sh:@1", weight: 1, isExample: true },
            { name: "spec/a_spec.sh:@2", weight: 2, isExample: true },
            { name: "spec/a_spec.sh:@3", weight: 3, isExample: true },
        ];

        const output = collapseExampleOutput(items);

        expect(output).toHaveLength(1);
        expect(output[0]).toBe("spec/a_spec.sh:@1:@2:@3");
    });

    test("keeps whole files as-is", () => {
        const items: TestItem[] = [
            { name: "spec/a_spec.sh", weight: 10 },
            { name: "spec/b_spec.sh", weight: 20 },
        ];

        const output = collapseExampleOutput(items);

        expect(output).toEqual(["spec/a_spec.sh", "spec/b_spec.sh"]);
    });

    test("handles mixed files and examples", () => {
        const items: TestItem[] = [
            { name: "spec/a_spec.sh", weight: 10 },
            { name: "spec/b_spec.sh:@1", weight: 1, isExample: true },
            { name: "spec/b_spec.sh:@2", weight: 2, isExample: true },
            { name: "spec/c_spec.sh", weight: 30 },
        ];

        const output = collapseExampleOutput(items);

        expect(output).toHaveLength(3);
        expect(output).toContain("spec/a_spec.sh");
        expect(output).toContain("spec/b_spec.sh:@1:@2");
        expect(output).toContain("spec/c_spec.sh");
    });

    test("handles examples with nested paths", () => {
        const items: TestItem[] = [
            { name: "spec/bin/git_spec.sh:@1", weight: 1, isExample: true },
            { name: "spec/bin/git_spec.sh:@2", weight: 2, isExample: true },
        ];

        const output = collapseExampleOutput(items);

        expect(output).toEqual(["spec/bin/git_spec.sh:@1:@2"]);
    });
});

describe("parseChunkArgs", () => {
    test("parses valid arguments", () => {
        const result = parseChunkArgs([".test-timings.json", "4", "2"]);

        expect(result).not.toBeNull();
        expect(result!.timingFile).toBe(".test-timings.json");
        expect(result!.numChunks).toBe(4);
        expect(result!.chunkIndex).toBe(2);
        expect(result!.granularity).toBe("file");
    });

    test("parses granularity option", () => {
        const result = parseChunkArgs([".test-timings.json", "4", "0", "--granularity=example"]);

        expect(result!.granularity).toBe("example");
    });

    test("parses hybrid granularity", () => {
        const result = parseChunkArgs(["--granularity=hybrid", "timings.json", "2", "1"]);

        expect(result!.granularity).toBe("hybrid");
        expect(result!.timingFile).toBe("timings.json");
    });

    test("returns null for insufficient arguments", () => {
        expect(parseChunkArgs(["timings.json", "4"])).toBeNull();
        expect(parseChunkArgs(["timings.json"])).toBeNull();
        expect(parseChunkArgs([])).toBeNull();
    });

    test("returns null for invalid chunk index", () => {
        expect(parseChunkArgs(["timings.json", "4", "5"])).toBeNull(); // index >= numChunks
        expect(parseChunkArgs(["timings.json", "4", "-1"])).toBeNull(); // negative index
    });

    test("returns null for non-numeric values", () => {
        expect(parseChunkArgs(["timings.json", "abc", "0"])).toBeNull();
        expect(parseChunkArgs(["timings.json", "4", "xyz"])).toBeNull();
    });
});

describe("calculateStaticWeightFromContent", () => {
    test("calculates weight from line count", () => {
        const content = "line1\nline2\nline3\nline4\nline5";
        const weight = calculateStaticWeightFromContent(content);

        expect(weight).toBe(5); // 5 lines, no test blocks
    });

    test("adds weight for It blocks", () => {
        const content = `
Describe 'test'
  It 'first test'
    echo "test"
  End
  It 'second test'
    echo "test"
  End
End
`;
        const weight = calculateStaticWeightFromContent(content);

        // 10 lines (including leading empty) + (1 Describe + 2 It) * 10 = 10 + 30 = 40
        expect(weight).toBe(40);
    });

    test("adds weight for Context blocks", () => {
        const content = `
Context 'when condition'
  It 'test'
  End
End
`;
        const weight = calculateStaticWeightFromContent(content);

        // 6 lines (including leading empty) + (1 Context + 1 It) * 10 = 6 + 20 = 26
        expect(weight).toBe(26);
    });

    test("handles empty content", () => {
        const weight = calculateStaticWeightFromContent("");
        expect(weight).toBe(1); // Single empty line
    });
});
