/**
 * Tests for parse-test-timings.ts
 * Run with: bun test
 */

import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { spawnSync } from "node:child_process";

const PROJECT_ROOT = join(import.meta.dir, "../../../..");

describe("parse-test-timings", () => {
    describe("e2e", () => {
        let tempDir: string;

        beforeAll(() => {
            tempDir = mkdtempSync(join(tmpdir(), "junit-parse-test-"));
        });

        afterAll(() => {
            rmSync(tempDir, { recursive: true, force: true });
        });

        test("parses JUnit XML and produces v1.0 timing JSON", () => {
            const inputXml = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites tests="3" failures="0" errors="0" time="3.0">
  <testsuite name="spec/test_spec.sh" tests="3" time="3.0">
    <testcase classname="spec/test_spec.sh" name="test 1" time="1.0"/>
    <testcase classname="spec/test_spec.sh" name="test 2" time="1.5"/>
    <testcase classname="spec/test_spec.sh" name="test 3" time="0.5"/>
  </testsuite>
</testsuites>`;

            const inputPath = join(tempDir, "input.xml");
            const outputPath = join(tempDir, "output.json");
            writeFileSync(inputPath, inputXml);

            const result = spawnSync(
                "bun",
                [".github/scripts/junit/src/parse-test-timings.ts", outputPath, inputPath],
                { cwd: PROJECT_ROOT, encoding: "utf-8" }
            );

            expect(result.status).toBe(0);

            const output = JSON.parse(readFileSync(outputPath, "utf-8"));
            expect(output.version).toBe("1.0");
            expect(output.timings["spec/test_spec.sh"]).toBe(3.0);
            expect(output.file_count).toBe(1);
        });

        test("parses JUnit XML and produces v2.0 timing JSON with --granularity=example", () => {
            const inputXml = `<?xml version="1.0" encoding="UTF-8"?>
<testsuites tests="2" failures="0" errors="0" time="2.0">
  <testsuite name="spec/another_spec.sh" tests="2" time="2.0">
    <testcase classname="spec/another_spec.sh" name="first example" time="0.8"/>
    <testcase classname="spec/another_spec.sh" name="second example" time="1.2"/>
  </testsuite>
</testsuites>`;

            const inputPath = join(tempDir, "input2.xml");
            const outputPath = join(tempDir, "output2.json");
            writeFileSync(inputPath, inputXml);

            const result = spawnSync(
                "bun",
                [".github/scripts/junit/src/parse-test-timings.ts", outputPath, inputPath, "--granularity=example"],
                { cwd: PROJECT_ROOT, encoding: "utf-8" }
            );

            expect(result.status).toBe(0);

            const output = JSON.parse(readFileSync(outputPath, "utf-8"));
            expect(output.version).toBe("2.0");
            expect(output.granularity).toBe("example");
            expect(output.timings["spec/another_spec.sh"].total).toBe(2.0);
            expect(Object.keys(output.timings["spec/another_spec.sh"].examples)).toHaveLength(2);
            expect(output.example_count).toBe(2);
        });

        test("handles multiple XML files", () => {
            const xml1 = `<testsuites><testcase classname="spec/a_spec.sh" name="t1" time="1.0"/></testsuites>`;
            const xml2 = `<testsuites><testcase classname="spec/b_spec.sh" name="t1" time="2.0"/></testsuites>`;

            const input1 = join(tempDir, "multi1.xml");
            const input2 = join(tempDir, "multi2.xml");
            const output = join(tempDir, "multi.json");

            writeFileSync(input1, xml1);
            writeFileSync(input2, xml2);

            const result = spawnSync(
                "bun",
                [".github/scripts/junit/src/parse-test-timings.ts", output, input1, input2],
                { cwd: PROJECT_ROOT, encoding: "utf-8" }
            );

            expect(result.status).toBe(0);

            const parsed = JSON.parse(readFileSync(output, "utf-8"));
            expect(parsed.timings["spec/a_spec.sh"]).toBe(1.0);
            expect(parsed.timings["spec/b_spec.sh"]).toBe(2.0);
            expect(parsed.file_count).toBe(2);
        });
    });
});
