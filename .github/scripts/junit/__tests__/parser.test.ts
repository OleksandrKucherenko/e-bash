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
} from "../lib/parser";

const FIXTURES_DIR = join(import.meta.dir, "../__fixtures__");

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
    test("generates sequential IDs starting from @1", () => {
        expect(extractExampleId("first test", 0)).toBe("@1");
        expect(extractExampleId("second test", 1)).toBe("@2");
        expect(extractExampleId("tenth test", 9)).toBe("@10");
    });

    test("ignores test name content", () => {
        expect(extractExampleId("any name here", 5)).toBe("@6");
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
    test("extracts individual examples with IDs", () => {
        const xmlContent = readFileSync(join(FIXTURES_DIR, "sample-results.xml"), "utf-8");
        const examples = parseJUnitXMLContentExamples(xmlContent);

        expect(examples.length).toBe(10); // 5 + 3 + 2 test cases

        // Check we have correct number of examples per file
        const argumentsExamples = examples.filter((e) => e.specFile === "spec/arguments_spec.sh");
        expect(argumentsExamples).toHaveLength(5);

        // Check first example has correct timing
        const firstExample = argumentsExamples.find((e) => e.exampleId === "@1");
        expect(firstExample).toBeDefined();
        expect(firstExample!.time).toBeCloseTo(0.234, 3);
    });

    test("assigns sequential IDs per file", () => {
        const xml = `
      <testsuites>
        <testcase classname="spec/a_spec.sh" name="test 1" time="1.0"/>
        <testcase classname="spec/a_spec.sh" name="test 2" time="2.0"/>
        <testcase classname="spec/b_spec.sh" name="test 1" time="3.0"/>
      </testsuites>
    `;
        const examples = parseJUnitXMLContentExamples(xml);

        expect(examples).toHaveLength(3);
        expect(examples[0].exampleId).toBe("@1");
        expect(examples[0].specFile).toBe("spec/a_spec.sh");
        expect(examples[1].exampleId).toBe("@2");
        expect(examples[1].specFile).toBe("spec/a_spec.sh");
        expect(examples[2].exampleId).toBe("@1");
        expect(examples[2].specFile).toBe("spec/b_spec.sh");
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
            { specFile: "spec/a_spec.sh", exampleId: "@1", time: 1.0, name: "test 1" },
            { specFile: "spec/a_spec.sh", exampleId: "@2", time: 2.0, name: "test 2" },
        ];

        const merged = mergeExamplesToV2([examples1]);

        expect(merged["spec/a_spec.sh"]).toBeDefined();
        expect(merged["spec/a_spec.sh"].total).toBe(3.0);
        expect(merged["spec/a_spec.sh"].examples["@1"].time).toBe(1.0);
        expect(merged["spec/a_spec.sh"].examples["@2"].time).toBe(2.0);
    });

    test("averages times for same example from multiple sources", () => {
        const examples1 = [{ specFile: "spec/a_spec.sh", exampleId: "@1", time: 2.0, name: "test" }];
        const examples2 = [{ specFile: "spec/a_spec.sh", exampleId: "@1", time: 4.0, name: "test" }];

        const merged = mergeExamplesToV2([examples1, examples2]);

        expect(merged["spec/a_spec.sh"].examples["@1"].time).toBe(3.0);
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
