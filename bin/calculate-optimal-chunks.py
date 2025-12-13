#!/usr/bin/env python3
"""
Calculate optimal test chunk distribution using bin-packing algorithm.

This script uses First Fit Decreasing (FFD) algorithm to distribute test files
across chunks to minimize maximum chunk execution time.

Usage:
    calculate-optimal-chunks.py <timing_json> <num_chunks> <chunk_index>

Example:
    calculate-optimal-chunks.py .test-timings.json 4 0

Output:
    Space-separated list of spec files for the specified chunk
"""

import json
import sys
from pathlib import Path


def load_timings(timing_file):
    """Load timing data from JSON file."""
    try:
        with open(timing_file, 'r') as f:
            data = json.load(f)
        return data.get('timings', {})
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Error loading timing data: {e}", file=sys.stderr)
        return {}


def calculate_static_weight(spec_file, project_root='.'):
    """
    Calculate static weight for a spec file when no timing data available.
    Weight = lines + (test_blocks * 10)
    """
    file_path = Path(project_root) / spec_file

    if not file_path.exists():
        return 100  # Default weight if file not found

    try:
        with open(file_path, 'r') as f:
            lines = f.readlines()

        line_count = len(lines)

        # Count test blocks (It, Describe, Context)
        test_blocks = sum(
            1 for line in lines
            if line.strip().startswith(('It ', 'Describe ', 'Context '))
        )

        return line_count + (test_blocks * 10)

    except Exception as e:
        print(f"Warning: Failed to calculate weight for {spec_file}: {e}", file=sys.stderr)
        return 100


def get_all_spec_files(project_root='.'):
    """Find all spec files in the project."""
    spec_dir = Path(project_root) / 'spec'
    if not spec_dir.exists():
        return []

    spec_files = []
    for spec_file in spec_dir.rglob('*_spec.sh'):
        # Convert to relative path from project root
        rel_path = spec_file.relative_to(project_root)
        spec_files.append(str(rel_path))

    return sorted(spec_files)


def bin_packing_ffd(items, num_bins):
    """
    First Fit Decreasing bin packing algorithm.

    Args:
        items: List of (name, weight) tuples
        num_bins: Number of bins to pack into

    Returns:
        List of bins, where each bin is a list of (name, weight) tuples
    """
    # Sort items by weight descending
    sorted_items = sorted(items, key=lambda x: x[1], reverse=True)

    # Initialize bins
    bins = [[] for _ in range(num_bins)]
    bin_weights = [0] * num_bins

    # Assign each item to the bin with minimum weight
    for item_name, item_weight in sorted_items:
        # Find bin with minimum weight
        min_idx = bin_weights.index(min(bin_weights))
        bins[min_idx].append((item_name, item_weight))
        bin_weights[min_idx] += item_weight

    return bins, bin_weights


def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <timing_json> <num_chunks> <chunk_index>", file=sys.stderr)
        print(f"\nExample: {sys.argv[0]} .test-timings.json 4 0", file=sys.stderr)
        sys.exit(1)

    timing_file = sys.argv[1]
    num_chunks = int(sys.argv[2])
    chunk_index = int(sys.argv[3])

    if chunk_index < 0 or chunk_index >= num_chunks:
        print(f"Error: chunk_index must be between 0 and {num_chunks - 1}", file=sys.stderr)
        sys.exit(1)

    # Get project root (parent of bin directory)
    project_root = Path(__file__).parent.parent

    # Load timing data
    timings = load_timings(timing_file)

    # Get all spec files
    all_spec_files = get_all_spec_files(project_root)

    if not all_spec_files:
        print("Error: No spec files found", file=sys.stderr)
        sys.exit(1)

    # Build items list with weights (timing or static)
    items = []
    using_static = []

    for spec_file in all_spec_files:
        if spec_file in timings and timings[spec_file] > 0:
            # Use timing data
            weight = timings[spec_file]
        else:
            # Fallback to static analysis
            weight = calculate_static_weight(spec_file, project_root)
            using_static.append(spec_file)

        items.append((spec_file, weight))

    if using_static:
        print(f"ℹ️  Using static weights for {len(using_static)} files (no timing data)", file=sys.stderr)

    # Calculate optimal distribution
    bins, bin_weights = bin_packing_ffd(items, num_chunks)

    # Debug output
    total_weight = sum(bin_weights)
    avg_weight = total_weight / num_chunks if num_chunks > 0 else 0

    print(f"📊 Chunk distribution (bin-packing algorithm):", file=sys.stderr)
    for i, (bin_items, weight) in enumerate(zip(bins, bin_weights)):
        deviation = ((weight - avg_weight) / avg_weight * 100) if avg_weight > 0 else 0
        print(f"  Chunk {i}: {weight:.1f}s ({len(bin_items)} files, {deviation:+.0f}% vs avg)", file=sys.stderr)

    # Output files for requested chunk
    chunk_files = bins[chunk_index]
    if chunk_files:
        # Print just the file names (space-separated)
        print(' '.join(item[0] for item in chunk_files))
    else:
        # Empty chunk
        print("")


if __name__ == '__main__':
    main()
