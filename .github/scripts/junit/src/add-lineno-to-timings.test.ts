import { describe, test, expect } from "bun:test";

import { attachLinenoByOrder, parseShellspecExamplesLinenoOutput } from "./add-lineno-to-timings";

describe("parseShellspecExamplesLinenoOutput", () => {
    test("parses shellspec --list examples:lineno output into file -> line numbers", () => {
        const stdout = `
spec/a_spec.sh:10
spec/a_spec.sh:20

spec/b_spec.sh:5
not-a-match
spec/b_spec.sh:15
`.trim();

        const map = parseShellspecExamplesLinenoOutput(stdout);
        expect(map.get("spec/a_spec.sh")).toEqual([10, 20]);
        expect(map.get("spec/b_spec.sh")).toEqual([5, 15]);
    });
});

describe("attachLinenoByOrder", () => {
    test("attaches lineno to examples in insertion order", () => {
        const data = {
            version: "2.0",
            granularity: "example",
            timings: {
                "spec/a_spec.sh": {
                    total: 3.0,
                    examples: {
                        "@a": { time: 1.0, name: "test a" },
                        "@b": { time: 2.0, name: "test b" },
                    },
                },
            },
        } as const;

        const fileLineNumbers = new Map([["spec/a_spec.sh", [35, 56]]]);
        const updated = attachLinenoByOrder(data as any, fileLineNumbers, { overwrite: true });

        expect(updated).toBe(2);
        expect((data as any).timings["spec/a_spec.sh"].examples["@a"].lineno).toBe(35);
        expect((data as any).timings["spec/a_spec.sh"].examples["@b"].lineno).toBe(56);
    });

    test("does not overwrite existing lineno when overwrite=false", () => {
        const data = {
            version: "2.0",
            granularity: "example",
            timings: {
                "spec/a_spec.sh": {
                    total: 3.0,
                    examples: {
                        "@a": { time: 1.0, name: "test a", lineno: 999 },
                        "@b": { time: 2.0, name: "test b" },
                    },
                },
            },
        } as const;

        const fileLineNumbers = new Map([["spec/a_spec.sh", [35, 56]]]);
        const updated = attachLinenoByOrder(data as any, fileLineNumbers, { overwrite: false });

        expect(updated).toBe(1);
        expect((data as any).timings["spec/a_spec.sh"].examples["@a"].lineno).toBe(999);
        expect((data as any).timings["spec/a_spec.sh"].examples["@b"].lineno).toBe(56);
    });
});

