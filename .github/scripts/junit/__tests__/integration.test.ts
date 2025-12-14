/**
 * Integration tests for the complete parsing and chunking workflow.
 * Run with: bun test
 */

import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

// Import from library
import {
  parseJUnitXMLContent,
  mergeTimingsV1,
  parseJUnitXMLContentExamples,
  mergeExamplesToV2,
} from "../lib/parser";

import {
  binPackingFFD,
  buildFileItemsFromTimings,
  collapseExampleOutput,
} from "../lib/chunker";

describe("Integration: End-to-end workflow", () => {
  let tempDir: string;

  beforeAll(() => {
    tempDir = mkdtempSync(join(tmpdir(), "junit-test-"));
  });

  afterAll(() => {
    rmSync(tempDir, { recursive: true, force: true });
  });

  test("parses multiple XML files and calculates optimal chunks", () => {
    // Step 1: Parse multiple JUnit XML files
    const xml1 = `
      <testsuites>
        <testcase classname="spec/a_spec.sh" name="test 1" time="5.0"/>
        <testcase classname="spec/a_spec.sh" name="test 2" time="3.0"/>
        <testcase classname="spec/b_spec.sh" name="test 1" time="2.0"/>
      </testsuites>
    `;

    const xml2 = `
      <testsuites>
        <testcase classname="spec/c_spec.sh" name="test 1" time="4.0"/>
        <testcase classname="spec/d_spec.sh" name="test 1" time="6.0"/>
      </testsuites>
    `;

    const timings1 = parseJUnitXMLContent(xml1);
    const timings2 = parseJUnitXMLContent(xml2);

    expect(timings1["spec/a_spec.sh"]).toBe(8.0);
    expect(timings1["spec/b_spec.sh"]).toBe(2.0);
    expect(timings2["spec/c_spec.sh"]).toBe(4.0);
    expect(timings2["spec/d_spec.sh"]).toBe(6.0);

    // Step 2: Merge timings
    const merged = mergeTimingsV1([timings1, timings2]);

    // Step 3: Build items and run bin-packing
    const specFiles = Object.keys(merged);
    const { items } = buildFileItemsFromTimings(specFiles, merged);

    // Step 4: Distribute into 2 chunks
    const [bins, weights] = binPackingFFD(items, 2);

    // Verify total weight is preserved
    const totalWeight = weights.reduce((a, b) => a + b, 0);
    expect(totalWeight).toBe(20.0); // 8 + 2 + 4 + 6

    // Verify balance (should be 10 each ideally)
    expect(Math.abs(weights[0] - weights[1])).toBeLessThanOrEqual(4);
  });

  test("example-level chunking provides finer distribution", () => {
    // Use unique test names to avoid hash collisions
    const xml = `
      <testsuites>
        <testcase classname="spec/big_spec.sh" name="big test one" time="10.0"/>
        <testcase classname="spec/big_spec.sh" name="big test two" time="10.0"/>
        <testcase classname="spec/big_spec.sh" name="big test three" time="10.0"/>
        <testcase classname="spec/big_spec.sh" name="big test four" time="10.0"/>
        <testcase classname="spec/small_spec.sh" name="small test one" time="2.0"/>
      </testsuites>
    `;

    // Parse at example level
    const examples = parseJUnitXMLContentExamples(xml);
    const v2Timings = mergeExamplesToV2([examples]);

    expect(v2Timings["spec/big_spec.sh"].total).toBe(40.0);
    expect(Object.keys(v2Timings["spec/big_spec.sh"].examples)).toHaveLength(4);

    // Build example-level items
    const items = [];
    for (const [file, data] of Object.entries(v2Timings)) {
      for (const [id, example] of Object.entries(data.examples)) {
        items.push({ name: `${file}:${id}`, weight: example.time, isExample: true });
      }
    }

    // Distribute into 4 chunks
    const [bins, weights] = binPackingFFD(items, 4);

    // With example-level, we can split the big file across chunks
    // Each chunk should have ~10.5 weight
    for (const weight of weights) {
      expect(weight).toBeLessThanOrEqual(12);
    }

    // Collapse output for verification
    const chunk0Output = collapseExampleOutput(bins[0]);
    expect(chunk0Output.length).toBeGreaterThan(0);
  });

  test("writes and reads timing JSON correctly", () => {
    const timings = {
      "spec/a_spec.sh": 5.5,
      "spec/b_spec.sh": 3.2,
    };

    const output = {
      version: "1.0",
      description: "Test timings",
      timings,
      total_time: 8.7,
      file_count: 2,
      source_files: ["results.xml"],
    };

    // Write to temp file
    const outputPath = join(tempDir, "timings.json");
    writeFileSync(outputPath, JSON.stringify(output, null, 2));

    // Read back and verify
    const content = readFileSync(outputPath, "utf-8");
    const parsed = JSON.parse(content);

    expect(parsed.version).toBe("1.0");
    expect(parsed.timings["spec/a_spec.sh"]).toBe(5.5);
    expect(parsed.file_count).toBe(2);
  });

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
