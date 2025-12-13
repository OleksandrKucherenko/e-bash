/**
 * E-Bash JUnit Tools Library
 * 
 * Exports core functions for parsing JUnit XML and calculating optimal test chunks.
 */

// Parser exports
export {
    normalizeSpecPath,
    extractExampleId,
    parseJUnitXMLContent,
    parseJUnitXMLContentExamples,
    mergeTimingsV1,
    mergeExamplesToV2,
    parseGranularity,
    type TimingDataV1,
    type TimingDataV2,
    type ExampleTiming,
    type FileTimingV2,
    type ParsedExample,
    type Granularity as ParserGranularity,
} from "./lib/parser";

// Chunker exports
export {
    binPackingFFD,
    buildFileItemsFromTimings,
    buildExampleItemsFromTimings,
    collapseExampleOutput,
    parseChunkArgs,
    calculateStaticWeightFromContent,
    type TestItem,
    type TimingData,
    type TimingDataV1 as ChunkerTimingDataV1,
    type TimingDataV2 as ChunkerTimingDataV2,
    type Granularity as ChunkerGranularity,
} from "./lib/chunker";
