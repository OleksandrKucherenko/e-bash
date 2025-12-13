#!/usr/bin/env bun
/**
 * Calculate optimal test chunk distribution using bin-packing algorithm.
 *
 * This script uses First Fit Decreasing (FFD) algorithm to distribute test files
 * across chunks to minimize maximum chunk execution time.
 *
 * Usage:
 *   bun calculate-optimal-chunks.ts <timing_json> <num_chunks> <chunk_index>
 *
 * Example:
 *   bun calculate-optimal-chunks.ts .test-timings.json 4 0
 *
 * Output:
 *   Space-separated list of spec files for the specified chunk
 */

import { readFileSync, existsSync, readdirSync, statSync } from "fs";
import { join } from "path";

interface TimingData {
  timings: { [key: string]: number };
  [key: string]: any;
}

interface TestItem {
  name: string;
  weight: number;
}

function loadTimings(timingFile: string): { [key: string]: number } {
  try {
    if (!existsSync(timingFile)) {
      return {};
    }

    const content = readFileSync(timingFile, "utf-8");
    const data: TimingData = JSON.parse(content);
    return data.timings || {};
  } catch (error) {
    console.error(`Error loading timing data: ${error}`);
    return {};
  }
}

function calculateStaticWeight(specFile: string, projectRoot: string): number {
  const filePath = join(projectRoot, specFile);

  if (!existsSync(filePath)) {
    return 100; // Default weight if file not found
  }

  try {
    const content = readFileSync(filePath, "utf-8");
    const lines = content.split("\n");
    const lineCount = lines.length;

    // Count test blocks (It, Describe, Context)
    const testBlocks = lines.filter((line) => {
      const trimmed = line.trim();
      return (
        trimmed.startsWith("It ") ||
        trimmed.startsWith("Describe ") ||
        trimmed.startsWith("Context ")
      );
    }).length;

    return lineCount + testBlocks * 10;
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
        // Convert to relative path from project root
        const relPath = fullPath.replace(projectRoot + "/", "");
        specFiles.push(relPath);
      }
    }
  }

  walkDir(specDir);
  return specFiles.sort();
}

function binPackingFFD(items: TestItem[], numBins: number): [TestItem[][], number[]] {
  // Sort items by weight descending
  const sortedItems = [...items].sort((a, b) => b.weight - a.weight);

  // Initialize bins
  const bins: TestItem[][] = Array.from({ length: numBins }, () => []);
  const binWeights = Array(numBins).fill(0);

  // Assign each item to the bin with minimum weight
  for (const item of sortedItems) {
    // Find bin with minimum weight
    const minIdx = binWeights.indexOf(Math.min(...binWeights));
    bins[minIdx].push(item);
    binWeights[minIdx] += item.weight;
  }

  return [bins, binWeights];
}

function main() {
  const args = process.argv.slice(2);

  if (args.length !== 3) {
    console.error(`Usage: bun calculate-optimal-chunks.ts <timing_json> <num_chunks> <chunk_index>`);
    console.error(`\nExample: bun calculate-optimal-chunks.ts .test-timings.json 4 0`);
    process.exit(1);
  }

  const timingFile = args[0];
  const numChunks = parseInt(args[1]);
  const chunkIndex = parseInt(args[2]);

  if (chunkIndex < 0 || chunkIndex >= numChunks) {
    console.error(`Error: chunk_index must be between 0 and ${numChunks - 1}`);
    process.exit(1);
  }

  // Get project root (parent of bin directory)
  const scriptDir = import.meta.dir;
  const projectRoot = join(scriptDir, "..");

  // Load timing data
  const timings = loadTimings(timingFile);

  // Get all spec files
  const allSpecFiles = getAllSpecFiles(projectRoot);

  if (allSpecFiles.length === 0) {
    console.error("Error: No spec files found");
    process.exit(1);
  }

  // Build items list with weights (timing or static)
  const items: TestItem[] = [];
  const usingStatic: string[] = [];

  for (const specFile of allSpecFiles) {
    let weight: number;

    if (timings[specFile] && timings[specFile] > 0) {
      // Use timing data
      weight = timings[specFile];
    } else {
      // Fallback to static analysis
      weight = calculateStaticWeight(specFile, projectRoot);
      usingStatic.push(specFile);
    }

    items.push({ name: specFile, weight });
  }

  if (usingStatic.length > 0) {
    console.error(`ℹ️  Using static weights for ${usingStatic.length} files (no timing data)`);
  }

  // Calculate optimal distribution
  const [bins, binWeights] = binPackingFFD(items, numChunks);

  // Debug output
  const totalWeight = binWeights.reduce((a, b) => a + b, 0);
  const avgWeight = totalWeight / numChunks;

  console.error(`📊 Chunk distribution (bin-packing algorithm):`);
  for (let i = 0; i < bins.length; i++) {
    const weight = binWeights[i];
    const deviation = avgWeight > 0 ? ((weight - avgWeight) / avgWeight) * 100 : 0;
    console.error(
      `  Chunk ${i}: ${weight.toFixed(1)}s (${bins[i].length} files, ${deviation >= 0 ? "+" : ""}${deviation.toFixed(0)}% vs avg)`
    );
  }

  // Output files for requested chunk
  const chunkFiles = bins[chunkIndex];
  if (chunkFiles.length > 0) {
    // Print just the file names (space-separated)
    console.log(chunkFiles.map((item) => item.name).join(" "));
  } else {
    // Empty chunk
    console.log("");
  }
}

main();
