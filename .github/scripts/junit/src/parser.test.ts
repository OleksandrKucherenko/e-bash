/**
 * Unit tests for JUnit XML parser functions.
 * Run with: bun test
 */

import { describe, test, expect } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
    normalizeSpecPath,
    extractExampleId,
    parseJUnitXMLContent,
    parseJUnitXMLContentExamples,
    mergeTimingsV1,
    mergeExamplesToV2,
    parseGranularity,
} from "./parser";

const FIXTURES_DIR = join(import.meta.dir, "./__fixtures__");

describe("normalizeSpecPath", () => {
    test("removes leading ./", () => {
        expect(normalizeSpecPath("./spec/test_spec.sh")).toBe("spec/test_spec.sh");
    });

    test("adds spec/ prefix if missing", () => {
        expect(normalizeSpecPath("test_spec.sh")).toBe("spec/test_spec.sh");
    });

    test("extracts spec/ from absolute path", () => {
        expect(normalizeSpecPath("/home/user/project/spec/test_spec.sh")).toBe("spec/test_spec.sh");
    });

    test("extracts nested spec path from absolute path", () => {
        expect(normalizeSpecPath("/project/spec/bin/git_spec.sh")).toBe("spec/bin/git_spec.sh");
    });

    test("leaves correct paths unchanged", () => {
        expect(normalizeSpecPath("spec/test_spec.sh")).toBe("spec/test_spec.sh");
        expect(normalizeSpecPath("spec/bin/nested_spec.sh")).toBe("spec/bin/nested_spec.sh");
    });

    test("handles path without spec/ in absolute path", () => {
        expect(normalizeSpecPath("/home/user/test_spec.sh")).toBe("spec/test_spec.sh");
    });
});

describe("extractExampleId", () => {
    test("generates stable hash-based IDs from test names", () => {
        expect(extractExampleId("first test", 0)).toBe("@7819cae9");
        expect(extractExampleId("second test", 1)).toBe("@edd187a3");
        expect(extractExampleId("tenth test", 9)).toBe("@8707b270");
    });

    test("generates different IDs for different test names", () => {
        const id1 = extractExampleId("test one", 0);
        const id2 = extractExampleId("test two", 0);
        expect(id1).not.toBe(id2);
    });

    test("generates same ID for same test name regardless of index", () => {
        const id1 = extractExampleId("same test name", 0);
        const id2 = extractExampleId("same test name", 5);
        expect(id1).toBe(id2);
    });
});

describe("parseJUnitXMLContent", () => {
    test("parses timing data from JUnit XML", () => {
        const xmlContent = readFileSync(join(FIXTURES_DIR, "sample-results.xml"), "utf-8");
        const timings = parseJUnitXMLContent(xmlContent);

        expect(timings["spec/arguments_spec.sh"]).toBeCloseTo(1.345, 2);
        expect(timings["spec/commons_spec.sh"]).toBeCloseTo(1.567, 2);
        expect(timings["spec/bin/git.conventional-commits_spec.sh"]).toBeCloseTo(0.876, 2);
    });

    test("handles empty XML gracefully", () => {
        const timings = parseJUnitXMLContent("");
        expect(Object.keys(timings)).toHaveLength(0);
    });

    test("handles XML with no testcases", () => {
        const xmlContent = readFileSync(join(FIXTURES_DIR, "empty-results.xml"), "utf-8");
        const timings = parseJUnitXMLContent(xmlContent);
        expect(Object.keys(timings)).toHaveLength(0);
    });

    test("aggregates times for same spec file", () => {
        const xml = `
      <testsuites>
        <testcase classname="spec/test_spec.sh" name="test 1" time="1.0"/>
        <testcase classname="spec/test_spec.sh" name="test 2" time="2.0"/>
        <testcase classname="spec/test_spec.sh" name="test 3" time="3.0"/>
      </testsuites>
    `;
        const timings = parseJUnitXMLContent(xml);
        expect(timings["spec/test_spec.sh"]).toBe(6.0);
    });

    test("handles malformed time attribute", () => {
        const xml = `
      <testsuites>
        <testcase classname="spec/test_spec.sh" name="test" time="invalid"/>
      </testsuites>
    `;
        const timings = parseJUnitXMLContent(xml);
        expect(timings["spec/test_spec.sh"]).toBe(0);
    });

    test("uses testsuite time as fallback when no testcase times", () => {
        const xml = `
      <testsuites>
        <testsuite name="spec/fallback_spec.sh" time="5.5">
        </testsuite>
      </testsuites>
    `;
        const timings = parseJUnitXMLContent(xml);
        expect(timings["spec/fallback_spec.sh"]).toBe(5.5);
    });
});

describe("parseJUnitXMLContentExamples", () => {
    test("extracts individual examples with hash-based IDs", () => {
        const xmlContent = readFileSync(join(FIXTURES_DIR, "sample-results.xml"), "utf-8");
        const examples = parseJUnitXMLContentExamples(xmlContent);

        expect(examples.length).toBe(10); // 5 + 3 + 2 test cases

        // Check we have correct number of examples per file
        const argumentsExamples = examples.filter((e) => e.specFile === "spec/arguments_spec.sh");
        expect(argumentsExamples).toHaveLength(5);

        // Check examples have hash-based IDs (start with @ followed by hex)
        for (const example of examples) {
            expect(example.exampleId).toMatch(/^@[0-9a-f]{8}$/);
        }
    });

    test("assigns unique hash-based IDs per test name", () => {
        const xml = `
      <testsuites>
        <testcase classname="spec/a_spec.sh" name="test 1" time="1.0"/>
        <testcase classname="spec/a_spec.sh" name="test 2" time="2.0"/>
        <testcase classname="spec/b_spec.sh" name="test 1" time="3.0"/>
      </testsuites>
    `;
        const examples = parseJUnitXMLContentExamples(xml);

        expect(examples).toHaveLength(3);
        // Same test name gets same hash (regardless of file)
        // "test 1" appears in both a_spec.sh (index 0) and b_spec.sh (index 2)
        expect(examples[0].name).toBe("test 1");
        expect(examples[2].name).toBe("test 1");
        expect(examples[0].exampleId).toBe(examples[2].exampleId);
        // Different test names get different hashes
        expect(examples[1].name).toBe("test 2");
        expect(examples[0].exampleId).not.toBe(examples[1].exampleId);
        // Verify hash format
        expect(examples[0].exampleId).toMatch(/^@[0-9a-f]{8}$/);
    });
});

describe("mergeTimingsV1", () => {
    test("averages timings from multiple sources", () => {
        const timings1 = { "spec/a_spec.sh": 2.0, "spec/b_spec.sh": 3.0 };
        const timings2 = { "spec/a_spec.sh": 4.0, "spec/b_spec.sh": 5.0 };

        const merged = mergeTimingsV1([timings1, timings2]);

        expect(merged["spec/a_spec.sh"]).toBe(3.0);
        expect(merged["spec/b_spec.sh"]).toBe(4.0);
    });

    test("handles files appearing in only one source", () => {
        const timings1 = { "spec/a_spec.sh": 2.0 };
        const timings2 = { "spec/b_spec.sh": 3.0 };

        const merged = mergeTimingsV1([timings1, timings2]);

        expect(merged["spec/a_spec.sh"]).toBe(2.0);
        expect(merged["spec/b_spec.sh"]).toBe(3.0);
    });

    test("handles empty input", () => {
        const merged = mergeTimingsV1([]);
        expect(Object.keys(merged)).toHaveLength(0);
    });
});

describe("mergeExamplesToV2", () => {
    test("groups examples by file and creates V2 structure", () => {
        const examples1 = [
            { specFile: "spec/a_spec.sh", exampleId: "@681c4c22", time: 1.0, name: "test 1" },
            { specFile: "spec/a_spec.sh", exampleId: "@681c4c21", time: 2.0, name: "test 2" },
        ];

        const merged = mergeExamplesToV2([examples1]);

        expect(merged["spec/a_spec.sh"]).toBeDefined();
        expect(merged["spec/a_spec.sh"].total).toBe(3.0);
        expect(merged["spec/a_spec.sh"].examples["@681c4c22"].time).toBe(1.0);
        expect(merged["spec/a_spec.sh"].examples["@681c4c21"].time).toBe(2.0);
    });

    test("averages times for same example from multiple sources", () => {
        const examples1 = [{ specFile: "spec/a_spec.sh", exampleId: "@7c73af33", time: 2.0, name: "test" }];
        const examples2 = [{ specFile: "spec/a_spec.sh", exampleId: "@7c73af33", time: 4.0, name: "test" }];

        const merged = mergeExamplesToV2([examples1, examples2]);

        expect(merged["spec/a_spec.sh"].examples["@7c73af33"].time).toBe(3.0);
    });
});

describe("parseGranularity", () => {
    test("defaults to file granularity", () => {
        const result = parseGranularity(["output.json", "input.xml"]);
        expect(result.granularity).toBe("file");
    });

    test("parses --granularity=file", () => {
        const result = parseGranularity(["--granularity=file", "output.json", "input.xml"]);
        expect(result.granularity).toBe("file");
    });

    test("parses --granularity=example", () => {
        const result = parseGranularity(["output.json", "--granularity=example", "input.xml"]);
        expect(result.granularity).toBe("example");
    });

    test("filters out --granularity from args", () => {
        const result = parseGranularity(["output.json", "--granularity=file", "input.xml"]);
        expect(result.filteredArgs).toEqual(["output.json", "input.xml"]);
    });

    test("filters out unknown -- options", () => {
        const result = parseGranularity(["output.json", "--unknown=value", "input.xml"]);
        expect(result.filteredArgs).toEqual(["output.json", "input.xml"]);
    });

    test("ignores invalid granularity value and uses default", () => {
        const result = parseGranularity(["--granularity=invalid", "output.json"]);
        expect(result.granularity).toBe("file");
    });
});

describe("e2e", () => {
    test("handles real-world ShellSpec JUnit format", () => {
        // This mimics actual ShellSpec output format
        const realWorldXml = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites tests="5" failures="0" errors="0" time="2.345">
  <testsuite name="spec/arguments_spec.sh" tests="3" failures="0" errors="0" skipped="0" time="1.234">
    <testcase classname="spec/arguments_spec.sh" name="_arguments.sh / On no ARGS_DEFINITION provided, expected fallback to predefined flags" time="0.234">
    </testcase>
    <testcase classname="spec/arguments_spec.sh" name="_arguments.sh / ARGS_DEFINITION set to &quot;-h,--help&quot; produce help env variable with value 1" time="0.500">
    </testcase>
    <testcase classname="spec/arguments_spec.sh" name="_arguments.sh / function parse:extract_output_definition() / Parameters Matrix / parse:extract_output_definition #00" time="0.500">
    </testcase>
  </testsuite>
  <testsuite name="spec/commons_spec.sh" tests="2" failures="0" errors="0" skipped="0" time="1.111">
    <testcase classname="spec/commons_spec.sh" name="commons / returns script directory" time="0.555">
    </testcase>
    <testcase classname="spec/commons_spec.sh" name="commons / is_function works" time="0.556">
    </testcase>
  </testsuite>
</testsuites>`;

        const timings = parseJUnitXMLContent(realWorldXml);

        expect(timings["spec/arguments_spec.sh"]).toBeCloseTo(1.234, 2);
        expect(timings["spec/commons_spec.sh"]).toBeCloseTo(1.111, 2);

        // Also test example-level parsing
        const examples = parseJUnitXMLContentExamples(realWorldXml);
        expect(examples).toHaveLength(5);

        const argumentsExamples = examples.filter((e) => e.specFile === "spec/arguments_spec.sh");
        expect(argumentsExamples).toHaveLength(3);
    });
});
