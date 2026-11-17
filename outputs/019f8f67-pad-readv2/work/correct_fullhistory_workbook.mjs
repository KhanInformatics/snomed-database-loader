import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { FileBlob, SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const here = path.dirname(fileURLToPath(import.meta.url));
const outputDir = path.resolve(here, "..");
const dataPath = path.join(outputDir, "pad_data.json");
const workbookPath = path.join(
  outputDir,
  "PAD_ReadV2_Comparison_FullHistory.xlsx",
);
const previews = {
  v32: path.join(here, "corrected_fullhistory_v32.png"),
  backmap: path.join(here, "corrected_fullhistory_backmap.png"),
  broadest: path.join(here, "corrected_fullhistory_broadest_coverage.png"),
};

const data = JSON.parse(await fs.readFile(dataPath, "utf8"));
const v32Rows = [...data.v32_candidates];
const v32StartRow = 18;
const v32EndRow = v32StartRow + v32Rows.length - 1;

const routeRank = {
  Direct: 0,
  "Concept history": 1,
  "Description history": 2,
  Unmapped: 3,
};
const mapRows = [...data.mapping_rows].sort((left, right) => {
  const mappedOrder =
    Number(!left.ReadV2Code) - Number(!right.ReadV2Code);
  if (mappedOrder !== 0) return mappedOrder;
  const conceptOrder = String(left.SnomedConceptId).localeCompare(
    String(right.SnomedConceptId),
  );
  if (conceptOrder !== 0) return conceptOrder;
  const routeOrder =
    (routeRank[left.BackMapRoute] ?? 9) -
    (routeRank[right.BackMapRoute] ?? 9);
  if (routeOrder !== 0) return routeOrder;
  return String(left.ReadV2Code).localeCompare(String(right.ReadV2Code));
});
const mapStartRow = 8;
const mapEndRow = mapStartRow + mapRows.length - 1;

const v32Included = v32Rows.filter(
  (row) => row.IncludedInV32 === "Yes",
);
const v32Set = new Set(v32Included.map((row) => row.ReadV2Code));
const backmapByCode = new Map();
for (const row of mapRows) {
  if (!row.ReadV2Code) continue;
  const current = backmapByCode.get(row.ReadV2Code) ?? {
    code: row.ReadV2Code,
    term: row.ReadV2Term,
    routes: new Set(),
  };
  current.routes.add(row.BackMapRoute);
  if (!current.term) current.term = row.ReadV2Term;
  backmapByCode.set(row.ReadV2Code, current);
}

function aggregatedRoutes(code) {
  const item = backmapByCode.get(code);
  if (!item) return "-";
  return [...item.routes]
    .sort((left, right) => (routeRank[left] ?? 9) - (routeRank[right] ?? 9))
    .map((route) => route.toLowerCase())
    .join(" + ")
    .replace(/^direct/, "Direct");
}

const coverageRows = [
  ...v32Included.map((row) => ({
    ReadV2Code: row.ReadV2Code,
    ReadV2Term: row.ReadV2Term,
    Source: "V32 contract",
    Note: "Exact or percent-wildcard-derived v32 contracted code",
  })),
  ...[...backmapByCode.values()]
    .filter((row) => !v32Set.has(row.code))
    .sort((left, right) => left.code.localeCompare(right.code))
    .map((row) => ({
      ReadV2Code: row.code,
      ReadV2Term: row.term,
      Source: "PAD_COD back-map addition",
      Note: "Added via PAD_COD back-map; not in the v32 contract",
    })),
];
const coverageStartRow = 8;
const coverageEndRow = coverageStartRow + coverageRows.length - 1;

const workbook = Workbook.create();
const v32Sheet = workbook.worksheets.add("V32 Contract");
const backmapSheet = workbook.worksheets.add("PAD_COD Backmap");
const broadestSheet = workbook.worksheets.add("Broadest Coverage");
for (const sheet of [v32Sheet, backmapSheet, broadestSheet]) {
  sheet.showGridLines = false;
}

const palette = {
  navy: "#17365D",
  teal: "#0F6B78",
  paleBlue: "#DDEBF7",
  lightBlue: "#EAF4F8",
  white: "#FFFFFF",
  ink: "#1F2937",
  grey: "#595959",
  lightGrey: "#F2F2F2",
  line: "#5B9BD5",
  green: "#E2F0D9",
  greenText: "#375623",
  amber: "#FFF2CC",
  amberText: "#7F6000",
  red: "#FCE4D6",
  redText: "#9C0006",
};

const titleFormat = {
  font: { bold: true, color: "#000000", size: 14 },
  verticalAlignment: "center",
  horizontalAlignment: "left",
};
const subtitleFormat = {
  font: { bold: true, color: "#000000", size: 10 },
  verticalAlignment: "center",
  wrapText: true,
};
const kpiLabelFormat = {
  fill: palette.paleBlue,
  font: { bold: true, color: palette.grey, size: 9 },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  wrapText: true,
};
const kpiValueFormat = {
  fill: palette.white,
  font: { bold: true, color: palette.navy, size: 14 },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  numberFormat: "0",
  borders: { bottom: { style: "thin", color: "#B4C6E7" } },
};
const headerFormat = {
  fill: palette.navy,
  font: { bold: true, color: palette.white, size: 9 },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  wrapText: true,
  borders: { bottom: { style: "medium", color: palette.navy } },
};
const tealHeaderFormat = {
  ...headerFormat,
  fill: palette.teal,
};
const bodyFormat = {
  font: { color: palette.ink, size: 9 },
  verticalAlignment: "top",
  wrapText: true,
};
const sourceHeadingFormat = {
  font: { bold: true, color: "#000000", size: 10 },
  verticalAlignment: "center",
};

function setColumnWidths(sheet, widths) {
  for (const [column, pixels] of Object.entries(widths)) {
    sheet.getRange(`${column}:${column}`).format.columnWidthPx = pixels;
  }
}

function styleComparison(range) {
  range.conditionalFormats.add("containsText", {
    text: "Overlap",
    format: { fill: palette.green, font: { color: palette.greenText } },
  });
  range.conditionalFormats.add("containsText", {
    text: "only",
    format: { fill: palette.amber, font: { color: palette.amberText } },
  });
  range.conditionalFormats.add("containsText", {
    text: "No Read",
    format: { fill: palette.lightGrey, font: { color: palette.grey } },
  });
  range.conditionalFormats.add("containsText", {
    text: "excluded",
    format: { fill: palette.red, font: { color: palette.redText } },
  });
}

// ---------------------------------------------------------------------------
// V32 Contract: exact codes remain exact; only G73z% expands.
// ---------------------------------------------------------------------------
v32Sheet.getRange("A1:H1").merge();
v32Sheet.getRange("A1").values = [[
  "Peripheral arterial disease - v32 Read v2 contract",
]];
v32Sheet.getRange("A1:H1").format = titleFormat;
v32Sheet.getRange("A1:H1").format.rowHeightPx = 32;

v32Sheet.getRange("A2:H2").merge();
v32Sheet.getRange("A2").values = [[
  "Corrected against v32ContractQOFReadCodes-V1-0.xlsx: exact entries remain exact, and only an expression ending in % expands down the Read v2 hierarchy.",
]];
v32Sheet.getRange("A2:H2").format = subtitleFormat;
v32Sheet.getRange("A2:H2").format.rowHeightPx = 38;

for (const [labelRange, label, valueRange, formula] of [
  ["A4:B4", "Included Read v2 codes", "A5:B5", `=COUNTIF(A${v32StartRow}:A${v32EndRow},"Yes")`],
  ["C4:D4", "Explicitly excluded", "C5:D5", `=COUNTIF(A${v32StartRow}:A${v32EndRow},"No")`],
  ["E4:F4", "PAD_COD overlap", "E5:F5", `=COUNTIFS(A${v32StartRow}:A${v32EndRow},"Yes",G${v32StartRow}:G${v32EndRow},"Yes")`],
  ["G4:H4", "V32 only", "G5:H5", `=COUNTIFS(A${v32StartRow}:A${v32EndRow},"Yes",G${v32StartRow}:G${v32EndRow},"No")`],
]) {
  v32Sheet.getRange(labelRange).merge();
  v32Sheet.getRange(labelRange.split(":")[0]).values = [[label]];
  v32Sheet.getRange(labelRange).format = kpiLabelFormat;
  v32Sheet.getRange(valueRange).merge();
  v32Sheet.getRange(valueRange.split(":")[0]).formulas = [[formula]];
  v32Sheet.getRange(valueRange).format = kpiValueFormat;
}

v32Sheet.getRange("A7:H7").merge();
v32Sheet.getRange("A7").values = [[
  "Corrected interpretation: G73.., G734., G73y. and Gyu74 are exact codes. G73z% expands to G73z., G73z0, G73z1 and G73zz; the explicit exclusion removes G73z1. Final v32 PAD diagnosis set: 7 Read v2 codes.",
]];
v32Sheet.getRange("A7:H7").format = {
  font: { color: palette.grey, size: 9 },
  verticalAlignment: "center",
  wrapText: true,
};
v32Sheet.getRange("A7:H7").format.rowHeightPx = 44;

v32Sheet.getRange("A10").values = [["Contract expression"]];
v32Sheet.getRange("B10:C10").merge();
v32Sheet.getRange("B10").values = [["Term"]];
v32Sheet.getRange("D10").values = [["Action"]];
v32Sheet.getRange("E10:H10").merge();
v32Sheet.getRange("E10").values = [["Applied interpretation"]];
v32Sheet.getRange("A10:H10").format = {
  font: { bold: true, color: "#000000", size: 9 },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  wrapText: true,
  borders: { bottom: { style: "thin", color: palette.navy } },
};

const contractRows = data.contract_rules;
for (let index = 0; index < contractRows.length; index += 1) {
  const rowNumber = 11 + index;
  const row = contractRows[index];
  v32Sheet.getRange(`B${rowNumber}:C${rowNumber}`).merge();
  v32Sheet.getRange(`E${rowNumber}:H${rowNumber}`).merge();
  v32Sheet.getRange(`A${rowNumber}`).values = [[row.ContractExpression]];
  v32Sheet.getRange(`B${rowNumber}`).values = [[row.ContractTerm]];
  v32Sheet.getRange(`D${rowNumber}`).values = [[row.Action]];
  v32Sheet.getRange(`E${rowNumber}`).values = [[row.AppliedInterpretation]];
}
v32Sheet.getRange(`A11:H${10 + contractRows.length}`).format = bodyFormat;
v32Sheet.getRange(`A11:A${10 + contractRows.length}`).format.font = {
  bold: true,
  color: palette.navy,
  size: 9,
};
v32Sheet.getRange(`D11:D${10 + contractRows.length}`).format.horizontalAlignment =
  "center";
v32Sheet
  .getRange(`D11:D${10 + contractRows.length}`)
  .conditionalFormats.add("containsText", {
    text: "Exclude",
    format: { fill: palette.red, font: { color: palette.redText } },
  });

v32Sheet.getRange("A17:H17").values = [[
  "Included in v32?",
  "Read v2 code",
  "Preferred term",
  "Dictionary status",
  "Contract rule(s) triggered",
  "Decision basis",
  "Current or historical PAD_COD back-map?",
  "Objective comparison",
]];
v32Sheet.getRange("A17:H17").format = headerFormat;
v32Sheet
  .getRangeByIndexes(
    v32StartRow - 1,
    0,
    v32Rows.length,
    8,
  )
  .values = v32Rows.map((row) => [
    row.IncludedInV32,
    row.ReadV2Code,
    row.ReadV2Term,
    row.ReadV2Status,
    row.ContractRuleTriggered,
    row.DecisionBasis,
    null,
    null,
  ]);
v32Sheet
  .getRange(`G${v32StartRow}:G${v32EndRow}`)
  .formulas = v32Rows.map((_, index) => {
    const row = v32StartRow + index;
    return [
      `=IF(COUNTIF('PAD_COD Backmap'!$E$${mapStartRow}:$E$${mapEndRow},B${row})>0,"Yes","No")`,
    ];
  });
v32Sheet
  .getRange(`H${v32StartRow}:H${v32EndRow}`)
  .formulas = v32Rows.map((_, index) => {
    const row = v32StartRow + index;
    return [
      `=IF(A${row}="No","Explicitly excluded",IF(G${row}="Yes","Overlap - PAD_COD back-map","V32 only - no PAD_COD back-map"))`,
    ];
  });
v32Sheet.getRange(`A${v32StartRow}:H${v32EndRow}`).format = bodyFormat;
v32Sheet.getRange(`A${v32StartRow}:A${v32EndRow}`).format.horizontalAlignment =
  "center";
v32Sheet.getRange(`B${v32StartRow}:B${v32EndRow}`).format.font = {
  name: "Consolas",
  bold: true,
  color: palette.navy,
  size: 9,
};
v32Sheet.getRange(`D${v32StartRow}:D${v32EndRow}`).format.horizontalAlignment =
  "center";
v32Sheet.getRange(`G${v32StartRow}:G${v32EndRow}`).format.horizontalAlignment =
  "center";
styleComparison(v32Sheet.getRange(`H${v32StartRow}:H${v32EndRow}`));
v32Sheet
  .getRange(`A${v32StartRow}:A${v32EndRow}`)
  .conditionalFormats.add("containsText", {
    text: "No",
    format: { fill: palette.red, font: { color: palette.redText } },
  });
const v32Table = v32Sheet.tables.add(
  `A17:H${v32EndRow}`,
  true,
  "V32CorrectedDefinition",
);
v32Table.style = "TableStyleMedium2";
v32Table.showBandedRows = true;
v32Table.showFilterButton = true;

const v32SourceRow = v32EndRow + 2;
v32Sheet.getRange(`A${v32SourceRow}:H${v32SourceRow}`).merge();
v32Sheet.getRange(`A${v32SourceRow}`).values = [["Sources and audit trail"]];
v32Sheet.getRange(`A${v32SourceRow}:H${v32SourceRow}`).format =
  sourceHeadingFormat;
const v32Sources = [
  [
    "Authoritative v32 workbook",
    String.raw`O:\GitHub\snomed-database-loader\outputs\v32ContractQOFReadCodes-V1-0.xlsx; Contract codes!A1881:E1887`,
  ],
  [
    "Wildcard rule",
    "Contract codes!A31:A32: only codes ending in % include the code and descendants",
  ],
  [
    "Scottish Read v2 dictionary",
    String.raw`O:\GitHub\snomed-database-loader\Readv2\Data\Readv2_codes_full.csv`,
  ],
  [
    "Applied interpretation",
    "Exact G73.., G734., G73y. and Gyu74; expand G73z% only; exclude G73z1",
  ],
];
for (let index = 0; index < v32Sources.length; index += 1) {
  const row = v32SourceRow + 1 + index;
  v32Sheet.getRange(`A${row}:B${row}`).merge();
  v32Sheet.getRange(`C${row}:H${row}`).merge();
  v32Sheet.getRange(`A${row}`).values = [[v32Sources[index][0]]];
  v32Sheet.getRange(`C${row}`).values = [[v32Sources[index][1]]];
}
v32Sheet
  .getRange(`A${v32SourceRow + 1}:H${v32SourceRow + v32Sources.length}`)
  .format = bodyFormat;
v32Sheet
  .getRange(`A${v32SourceRow + 1}:B${v32SourceRow + v32Sources.length}`)
  .format.font = { bold: true, color: palette.grey, size: 9 };

setColumnWidths(v32Sheet, {
  A: 95,
  B: 105,
  C: 285,
  D: 85,
  E: 220,
  F: 255,
  G: 145,
  H: 195,
});
v32Sheet
  .getRange(`A1:H${v32SourceRow + v32Sources.length}`)
  .format.autofitRows();
v32Sheet.getRange("A17:H17").format.rowHeightPx = 42;
v32Sheet.freezePanes.freezeRows(17);

// ---------------------------------------------------------------------------
// PAD_COD Backmap: complete current refset membership and mapping evidence.
// ---------------------------------------------------------------------------
backmapSheet.getRange("A1:H1").merge();
backmapSheet.getRange("A1").values = [[
  "Current PAD_COD SNOMED refset - full-history Read v2 back-map",
]];
backmapSheet.getRange("A1:H1").format = titleFormat;
backmapSheet.getRange("A1:H1").format.rowHeightPx = 32;

backmapSheet.getRange("A2:H2").merge();
backmapSheet.getRange("A2").values = [[
  `Full-history reverse maps cover ${data.metadata.BackMappedConceptCount} of ${data.metadata.ActivePADConceptCount} active PAD_COD refset members: ${data.metadata.DirectBackMappedConceptCount} directly, ${data.metadata.ConceptHistoryOnlyBackMappedConceptCount} via concept history only, and ${data.metadata.DescriptionHistoryOnlyBackMappedConceptCount} via retired-description history only. They produce ${data.metadata.BackMappedUniqueReadCodeCount} unique Read v2 codes: ${data.metadata.OverlapReadCodeCount} overlap the corrected v32 definition and ${data.metadata.BackMapOnlyReadCodeCount} are additional. ${data.metadata.UnmappedConceptCount} members remain unmapped.`,
]];
backmapSheet.getRange("A2:H2").format = subtitleFormat;
backmapSheet.getRange("A2:H2").format.rowHeightPx = 46;

backmapSheet.getRange("A4:H4").merge();
backmapSheet.getRange("A4").values = [[
  `PAD_COD refset ID: ${data.metadata.PADRefsetId} - UK NHS primary care data extraction: peripheral arterial disease diagnoses simple reference set.`,
]];
backmapSheet.getRange("A4:H4").format = {
  font: { color: palette.grey, size: 8 },
  wrapText: true,
};
backmapSheet.getRange("A5:H5").merge();
backmapSheet.getRange("A5").values = [[
  `DMWB map source: ${data.metadata.MapType}, release ${data.metadata.MapReleaseDate} (static April 2020). 'Unmapped' means no exact direct, concept-history, or retired-description route was found - not that the concept is outside PAD.`,
]];
backmapSheet.getRange("A5:H5").format = {
  font: { color: palette.grey, size: 8 },
  wrapText: true,
};

backmapSheet.getRange("A7:H7").values = [[
  "PAD_COD SNOMED concept ID",
  "PAD_COD SNOMED FSN",
  "Back-map route",
  "Historical association path",
  "Read v2 code",
  "Read v2 preferred term",
  "In corrected v32?",
  "Objective comparison",
]];
backmapSheet.getRange("A7:H7").format = tealHeaderFormat;
backmapSheet
  .getRangeByIndexes(mapStartRow - 1, 0, mapRows.length, 8)
  .values = mapRows.map((row) => [
    `'${String(row.SnomedConceptId)}`,
    row.SnomedFSN,
    row.BackMapRoute,
    row.BackMapRoute === "Direct"
      ? ""
      : row.HistoricalAssociationPath,
    row.ReadV2Code || "",
    row.ReadV2Term || "",
    null,
    null,
  ]);
backmapSheet
  .getRange(`G${mapStartRow}:G${mapEndRow}`)
  .formulas = mapRows.map((_, index) => {
    const row = mapStartRow + index;
    return [
      `=IF(E${row}="","N/A",IF(COUNTIFS('V32 Contract'!$A$${v32StartRow}:$A$${v32EndRow},"Yes",'V32 Contract'!$B$${v32StartRow}:$B$${v32EndRow},E${row})>0,"Yes","No"))`,
    ];
  });
backmapSheet
  .getRange(`H${mapStartRow}:H${mapEndRow}`)
  .formulas = mapRows.map((_, index) => {
    const row = mapStartRow + index;
    return [
      `=IF(E${row}="","No Read v2 back-map after full history",IF(G${row}="Yes",IF(C${row}="Concept history","Overlap - concept-history route",IF(C${row}="Description history","Overlap - retired-description route","Overlap - direct route")),IF(C${row}="Concept history","Concept-history back-map only - not in corrected v32",IF(C${row}="Description history","Retired-description back-map only - not in corrected v32","Direct back-map only - not in corrected v32"))))`,
    ];
  });
backmapSheet.getRange(`A${mapStartRow}:H${mapEndRow}`).format = bodyFormat;
backmapSheet.getRange(`A${mapStartRow}:A${mapEndRow}`).format.numberFormat =
  "@";
backmapSheet.getRange(`A${mapStartRow}:A${mapEndRow}`).format.font = {
  name: "Consolas",
  color: palette.navy,
  size: 9,
};
backmapSheet.getRange(`E${mapStartRow}:E${mapEndRow}`).format.numberFormat =
  "@";
backmapSheet.getRange(`E${mapStartRow}:E${mapEndRow}`).format.font = {
  name: "Consolas",
  color: palette.navy,
  bold: true,
  size: 9,
};
backmapSheet.getRange(`C${mapStartRow}:C${mapEndRow}`).format.horizontalAlignment =
  "center";
backmapSheet.getRange(`G${mapStartRow}:G${mapEndRow}`).format.horizontalAlignment =
  "center";
backmapSheet
  .getRange(`C${mapStartRow}:C${mapEndRow}`)
  .conditionalFormats.add("containsText", {
    text: "Direct",
    format: { fill: palette.green, font: { color: palette.greenText } },
  });
backmapSheet
  .getRange(`C${mapStartRow}:C${mapEndRow}`)
  .conditionalFormats.add("containsText", {
    text: "Concept history",
    format: { fill: palette.amber, font: { color: palette.amberText } },
  });
backmapSheet
  .getRange(`C${mapStartRow}:C${mapEndRow}`)
  .conditionalFormats.add("containsText", {
    text: "Description history",
    format: { fill: palette.paleBlue, font: { color: palette.navy } },
  });
backmapSheet
  .getRange(`C${mapStartRow}:C${mapEndRow}`)
  .conditionalFormats.add("containsText", {
    text: "Unmapped",
    format: { fill: palette.lightGrey, font: { color: palette.grey } },
  });
styleComparison(backmapSheet.getRange(`H${mapStartRow}:H${mapEndRow}`));
const backmapTable = backmapSheet.tables.add(
  `A7:H${mapEndRow}`,
  true,
  "PADCurrentFullHistoryBackmap",
);
backmapTable.style = "TableStyleMedium2";
backmapTable.showBandedRows = true;
backmapTable.showFilterButton = true;

setColumnWidths(backmapSheet, {
  A: 150,
  B: 330,
  C: 110,
  D: 300,
  E: 95,
  F: 255,
  G: 100,
  H: 230,
});
backmapSheet.getRange(`A1:H${mapEndRow}`).format.autofitRows();
backmapSheet.getRange("A7:H7").format.rowHeightPx = 42;
backmapSheet.freezePanes.freezeRows(7);

// ---------------------------------------------------------------------------
// Broadest Coverage: corrected union of v32 and all Read codes from back-map.
// ---------------------------------------------------------------------------
broadestSheet.getRange("A1:G1").merge();
broadestSheet.getRange("A1").values = [[
  "Broadest coverage - corrected v32 contract + PAD_COD back-map additions",
]];
broadestSheet.getRange("A1:G1").format = titleFormat;
broadestSheet.getRange("A1:G1").format.rowHeightPx = 32;

broadestSheet.getRange("A2:G2").merge();
broadestSheet.getRange("A2").values = [[
  "Union of the 7 corrected v32 Read v2 codes and the 11 additional Read v2 codes reached only through the current PAD_COD full-history back-map. This is a coverage option, not an assured map for the 34 unmapped SNOMED concepts.",
]];
broadestSheet.getRange("A2:G2").format = subtitleFormat;
broadestSheet.getRange("A2:G2").format.rowHeightPx = 46;

for (const [labelRange, label, valueRange, formula] of [
  ["A4:B4", "Total codes", "A5:B5", `=COUNTA(A${coverageStartRow}:A${coverageEndRow})`],
  ["C4:D4", "From corrected v32 contract", "C5:D5", `=COUNTIF(D${coverageStartRow}:D${coverageEndRow},"Yes")`],
  ["E4:F4", "Added via PAD_COD back-map", "E5:F5", `=COUNTIFS(D${coverageStartRow}:D${coverageEndRow},"No",E${coverageStartRow}:E${coverageEndRow},"Yes")`],
]) {
  broadestSheet.getRange(labelRange).merge();
  broadestSheet.getRange(labelRange.split(":")[0]).values = [[label]];
  broadestSheet.getRange(labelRange).format = kpiLabelFormat;
  broadestSheet.getRange(valueRange).merge();
  broadestSheet.getRange(valueRange.split(":")[0]).formulas = [[formula]];
  broadestSheet.getRange(valueRange).format = kpiValueFormat;
}

broadestSheet.getRange("A7:G7").values = [[
  "Read v2 code",
  "Read v2 preferred term",
  "Source",
  "In corrected v32?",
  "In PAD_COD back-map?",
  "Back-map route(s)",
  "Note",
]];
broadestSheet.getRange("A7:G7").format = tealHeaderFormat;
broadestSheet
  .getRangeByIndexes(
    coverageStartRow - 1,
    0,
    coverageRows.length,
    7,
  )
  .values = coverageRows.map((row) => [
    row.ReadV2Code,
    row.ReadV2Term,
    row.Source,
    null,
    null,
    aggregatedRoutes(row.ReadV2Code),
    row.Note,
  ]);
broadestSheet
  .getRange(`D${coverageStartRow}:D${coverageEndRow}`)
  .formulas = coverageRows.map((_, index) => {
    const row = coverageStartRow + index;
    return [
      `=IF(COUNTIFS('V32 Contract'!$A$${v32StartRow}:$A$${v32EndRow},"Yes",'V32 Contract'!$B$${v32StartRow}:$B$${v32EndRow},A${row})>0,"Yes","No")`,
    ];
  });
broadestSheet
  .getRange(`E${coverageStartRow}:E${coverageEndRow}`)
  .formulas = coverageRows.map((_, index) => {
    const row = coverageStartRow + index;
    return [
      `=IF(COUNTIF('PAD_COD Backmap'!$E$${mapStartRow}:$E$${mapEndRow},A${row})>0,"Yes","No")`,
    ];
  });
broadestSheet
  .getRange(`A${coverageStartRow}:G${coverageEndRow}`)
  .format = bodyFormat;
broadestSheet
  .getRange(`A${coverageStartRow}:A${coverageEndRow}`)
  .format.numberFormat = "@";
broadestSheet
  .getRange(`A${coverageStartRow}:A${coverageEndRow}`)
  .format.font = {
    name: "Consolas",
    bold: true,
    color: palette.navy,
    size: 9,
  };
broadestSheet
  .getRange(`D${coverageStartRow}:F${coverageEndRow}`)
  .format.horizontalAlignment = "center";
broadestSheet
  .getRange(`C${coverageStartRow}:C${coverageEndRow}`)
  .conditionalFormats.add("containsText", {
    text: "addition",
    format: { fill: palette.amber, font: { color: palette.amberText } },
  });
const coverageTable = broadestSheet.tables.add(
  `A7:G${coverageEndRow}`,
  true,
  "PADBroadestCoverage",
);
coverageTable.style = "TableStyleMedium2";
coverageTable.showBandedRows = true;
coverageTable.showFilterButton = true;

const coverageSourceRow = coverageEndRow + 2;
broadestSheet
  .getRange(`A${coverageSourceRow}:G${coverageSourceRow}`)
  .merge();
broadestSheet.getRange(`A${coverageSourceRow}`).values = [[
  "Sources, interpretation and decision note",
]];
broadestSheet
  .getRange(`A${coverageSourceRow}:G${coverageSourceRow}`)
  .format = sourceHeadingFormat;
const coverageNotes = [
  [
    "Authoritative v32 source",
    String.raw`v32ContractQOFReadCodes-V1-0.xlsx; Contract codes!A31:A32 and A1881:E1887`,
  ],
  [
    "PAD_COD back-map source",
    `${data.metadata.MapType}; release ${data.metadata.MapReleaseDate}; full concept and retired-description history`,
  ],
  [
    "Decision note",
    "The union maximises Read v2 coverage among defensible historical maps. It does not add semantic proxy codes for unmapped SNOMED concepts.",
  ],
];
for (let index = 0; index < coverageNotes.length; index += 1) {
  const row = coverageSourceRow + 1 + index;
  broadestSheet.getRange(`A${row}:B${row}`).merge();
  broadestSheet.getRange(`C${row}:G${row}`).merge();
  broadestSheet.getRange(`A${row}`).values = [[coverageNotes[index][0]]];
  broadestSheet.getRange(`C${row}`).values = [[coverageNotes[index][1]]];
}
broadestSheet
  .getRange(
    `A${coverageSourceRow + 1}:G${coverageSourceRow + coverageNotes.length}`,
  )
  .format = bodyFormat;
broadestSheet
  .getRange(
    `A${coverageSourceRow + 1}:B${coverageSourceRow + coverageNotes.length}`,
  )
  .format.font = { bold: true, color: palette.grey, size: 9 };

setColumnWidths(broadestSheet, {
  A: 115,
  B: 310,
  C: 190,
  D: 115,
  E: 135,
  F: 155,
  G: 285,
});
broadestSheet
  .getRange(`A1:G${coverageSourceRow + coverageNotes.length}`)
  .format.autofitRows();
broadestSheet.getRange("A7:G7").format.rowHeightPx = 38;
broadestSheet.freezePanes.freezeRows(7);

// ---------------------------------------------------------------------------
// Compact verification, visual rendering, export and re-import checks.
// ---------------------------------------------------------------------------
for (const [label, range, maxRows, maxCols, maxChars] of [
  ["V32_CHECK", `V32 Contract!A1:H${v32EndRow}`, v32EndRow, 8, 10000],
  ["BACKMAP_CHECK", "PAD_COD Backmap!A1:H12", 12, 8, 9000],
  [
    "BROADEST_CHECK",
    `Broadest Coverage!A1:G${coverageEndRow}`,
    coverageEndRow,
    7,
    13000,
  ],
]) {
  const inspection = await workbook.inspect({
    kind: "table",
    range,
    include: "values,formulas",
    tableMaxRows: maxRows,
    tableMaxCols: maxCols,
    maxChars,
  });
  console.log(label);
  console.log(inspection.ndjson);
}

const unmappedRow =
  mapStartRow +
  mapRows.findIndex(
    (row) => String(row.SnomedConceptId) === "10653951000119109",
  );
const unmappedCheck = await workbook.inspect({
  kind: "table",
  range: `PAD_COD Backmap!A${unmappedRow}:H${unmappedRow}`,
  include: "values,formulas",
  tableMaxRows: 2,
  tableMaxCols: 8,
  maxChars: 3000,
});
console.log("UNMAPPED_READ_CODE_CHECK");
console.log(unmappedCheck.ndjson);

const retiredDescriptionRow =
  mapStartRow +
  mapRows.findIndex(
    (row) => String(row.SnomedConceptId) === "840580004",
  );
const retiredDescriptionCheck = await workbook.inspect({
  kind: "table",
  range: `PAD_COD Backmap!A${retiredDescriptionRow}:H${retiredDescriptionRow}`,
  include: "values,formulas",
  tableMaxRows: 2,
  tableMaxCols: 8,
  maxChars: 3500,
});
console.log("RETIRED_DESCRIPTION_CHECK");
console.log(retiredDescriptionCheck.ndjson);

const formulaErrors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "corrected workbook formula error scan",
});
console.log("FORMULA_ERRORS");
console.log(formulaErrors.ndjson);

for (const [sheetName, range, scale, previewPath] of [
  [
    "V32 Contract",
    `A1:H${v32SourceRow + v32Sources.length}`,
    1,
    previews.v32,
  ],
  [
    "PAD_COD Backmap",
    `A1:H${Math.min(mapEndRow, 46)}`,
    0.72,
    previews.backmap,
  ],
  [
    "Broadest Coverage",
    `A1:G${coverageSourceRow + coverageNotes.length}`,
    1,
    previews.broadest,
  ],
]) {
  const rendered = await workbook.render({
    sheetName,
    range,
    scale,
    format: "png",
  });
  await fs.writeFile(
    previewPath,
    new Uint8Array(await rendered.arrayBuffer()),
  );
}

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(workbookPath);
const exportedWorkbook = await SpreadsheetFile.importXlsx(
  await FileBlob.load(workbookPath),
);
const exportedSheets = await exportedWorkbook.inspect({
  kind: "sheet",
  include: "id,name",
  maxChars: 3000,
});
console.log("EXPORTED_SHEETS");
console.log(exportedSheets.ndjson);
const exportedErrors = await exportedWorkbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "exported corrected workbook formula error scan",
});
console.log("EXPORTED_FORMULA_ERRORS");
console.log(exportedErrors.ndjson);
console.log(
  JSON.stringify(
    {
      workbookPath,
      previews,
      v32IncludedCodes: v32Included.length,
      mappingRows: mapRows.length,
      coverageCodes: coverageRows.length,
    },
    null,
    2,
  ),
);
