import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { FileBlob, SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const here = path.dirname(fileURLToPath(import.meta.url));
const outputDir = path.resolve(here, "..");
const dataPath = path.join(outputDir, "pad_data.json");
const workbookPath = path.join(
  outputDir,
  "PAD_ReadV2_Comparison_CorrectedWildcard.xlsx",
);
const v32PreviewPath = path.join(
  here,
  "preview_v32_contract_corrected_wildcard.png",
);
const backmapPreviewPath = path.join(
  here,
  "preview_pad_cod_backmap_corrected_wildcard.png",
);
const data = JSON.parse(await fs.readFile(dataPath, "utf8"));
const mapRows = [...data.mapping_rows].sort((left, right) => {
  const mappingOrder =
    (left.ReadV2Code ? 0 : 1) - (right.ReadV2Code ? 0 : 1);
  if (mappingOrder !== 0) return mappingOrder;
  const conceptOrder = String(left.SnomedConceptId).localeCompare(
    String(right.SnomedConceptId),
  );
  if (conceptOrder !== 0) return conceptOrder;
  const routeRank = {
    Direct: 0,
    "Concept history": 1,
    "Description history": 2,
    Unmapped: 3,
  };
  const routeOrder =
    (routeRank[left.BackMapRoute] ?? 9) -
    (routeRank[right.BackMapRoute] ?? 9);
  if (routeOrder !== 0) return routeOrder;
  const resolvedOrder = String(left.ResolvedConceptId).localeCompare(
    String(right.ResolvedConceptId),
  );
  if (resolvedOrder !== 0) return resolvedOrder;
  return String(left.ReadV2Code).localeCompare(String(right.ReadV2Code));
});
const mapStartRow = 24;
const mapEndRow = mapStartRow + mapRows.length - 1;

const workbook = Workbook.create();
const v32Sheet = workbook.worksheets.add("V32 Contract");
const backmapSheet = workbook.worksheets.add("PAD_COD Backmap");
v32Sheet.showGridLines = false;
backmapSheet.showGridLines = false;

const palette = {
  navy: "#17365D",
  teal: "#0F6B78",
  paleTeal: "#DDEBF7",
  paleBlue: "#EAF2F8",
  green: "#E2F0D9",
  greenText: "#375623",
  amber: "#FFF2CC",
  amberText: "#7F6000",
  red: "#FCE4D6",
  redText: "#9C0006",
  grey: "#E7E6E6",
  greyText: "#595959",
  white: "#FFFFFF",
  ink: "#1F2937",
  line: "#B4C6E7",
};

const titleFormat = {
  fill: palette.navy,
  font: { bold: true, color: palette.white, size: 18 },
  verticalAlignment: "center",
  horizontalAlignment: "left",
};
const subtitleFormat = {
  fill: palette.paleBlue,
  font: { color: palette.ink, size: 10 },
  verticalAlignment: "center",
  wrapText: true,
};
const sectionFormat = {
  fill: palette.teal,
  font: { bold: true, color: palette.white, size: 11 },
  verticalAlignment: "center",
};
const headerFormat = {
  fill: palette.navy,
  font: { bold: true, color: palette.white, size: 10 },
  verticalAlignment: "center",
  horizontalAlignment: "center",
  wrapText: true,
  borders: {
    bottom: { style: "medium", color: palette.navy },
  },
};
const bodyFormat = {
  font: { color: palette.ink, size: 9 },
  verticalAlignment: "top",
  wrapText: true,
};
const auditFormat = {
  fill: "#F2F2F2",
  font: { color: palette.greyText, size: 8 },
  horizontalAlignment: "center",
};

function yyyymmddToDate(value) {
  const text = String(value ?? "");
  if (!/^\d{8}$/.test(text)) return null;
  return new Date(
    Date.UTC(
      Number(text.slice(0, 4)),
      Number(text.slice(4, 6)) - 1,
      Number(text.slice(6, 8)),
    ),
  );
}

function setColumnWidths(sheet, widths) {
  for (const [column, pixels] of Object.entries(widths)) {
    sheet.getRange(`${column}:${column}`).format.columnWidthPx = pixels;
  }
}

function addComparisonConditionalFormatting(range) {
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
    format: { fill: palette.grey, font: { color: palette.greyText } },
  });
  range.conditionalFormats.add("containsText", {
    text: "excluded",
    format: { fill: palette.red, font: { color: palette.redText } },
  });
}

// ---------------------------------------------------------------------------
// Sheet 1: corrected v32 contract definition with wildcard-only expansion
// ---------------------------------------------------------------------------
const v32Rows = data.v32_candidates;
const v32StartRow = 18;
const v32EndRow = v32StartRow + v32Rows.length - 1;

v32Sheet.getRange("A1:H1").merge();
v32Sheet.getRange("A1").values = [["Peripheral arterial disease - v32 Read v2 contract"]];
v32Sheet.getRange("A1:H1").format = titleFormat;
v32Sheet.getRange("A1:H1").format.rowHeightPx = 34;

v32Sheet.getRange("A2:H2").merge();
v32Sheet.getRange("A2").values = [[
  "Authoritative transcription from v32ContractQOFReadCodes-V1-0.xlsx. Exact codes remain exact; only a source expression ending in % expands down the Read v2 hierarchy.",
]];
v32Sheet.getRange("A2:H2").format = subtitleFormat;
v32Sheet.getRange("A2:H2").format.rowHeightPx = 38;

v32Sheet.getRange("A4:H4").values = [[
  "Included Read v2 codes",
  "",
  "Explicitly excluded",
  "",
  "PAD_COD overlap",
  "",
  "V32 only",
  "",
]];
v32Sheet.getRange("A4:H4").format = {
  fill: palette.paleTeal,
  font: { bold: true, color: palette.navy, size: 9 },
  horizontalAlignment: "center",
  wrapText: true,
};
v32Sheet.getRange("A5:H5").formulas = [[
  `=COUNTIF(A${v32StartRow}:A${v32EndRow},"Yes")`,
  '=""',
  `=COUNTIF(A${v32StartRow}:A${v32EndRow},"No")`,
  '=""',
  `=COUNTIFS(A${v32StartRow}:A${v32EndRow},"Yes",G${v32StartRow}:G${v32EndRow},"Yes")`,
  '=""',
  `=COUNTIFS(A${v32StartRow}:A${v32EndRow},"Yes",G${v32StartRow}:G${v32EndRow},"No")`,
  '=""',
]];
v32Sheet.getRange("A5:H5").format = {
  fill: palette.white,
  font: { bold: true, color: palette.navy, size: 16 },
  horizontalAlignment: "center",
  borders: { bottom: { style: "thin", color: palette.line } },
};
v32Sheet.getRange("A5:H5").format.numberFormat = "0";

v32Sheet.getRange("A7:H7").merge();
v32Sheet.getRange("A7").values = [[
  "Corrected interpretation: G73.., G734., G73y. and Gyu74 are exact codes. G73z% expands to G73z., G73z0, G73z1 and G73zz; the explicit exclusion removes G73z1. Final v32 PAD diagnosis set: 7 Read v2 codes.",
]];
v32Sheet.getRange("A7:H7").format = {
  fill: palette.amber,
  font: { color: palette.amberText, size: 9 },
  wrapText: true,
  verticalAlignment: "center",
};
v32Sheet.getRange("A7:H7").format.rowHeightPx = 48;

v32Sheet.getRange("A9:H9").merge();
v32Sheet.getRange("A9").values = [[
  "Contract transcription from authoritative v32 workbook",
]];
v32Sheet.getRange("A9:H9").format = sectionFormat;
v32Sheet.getRange("B10:C10").merge();
v32Sheet.getRange("E10:H10").merge();
v32Sheet.getRange("A10").values = [["Contract expression"]];
v32Sheet.getRange("B10").values = [["Term"]];
v32Sheet.getRange("D10").values = [["Action"]];
v32Sheet.getRange("E10").values = [["Applied interpretation"]];
v32Sheet.getRange("A10:H10").format = headerFormat;
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
  size: 10,
};
v32Sheet.getRange(`D11:D${10 + contractRows.length}`).format.horizontalAlignment =
  "center";
v32Sheet.getRange(`D11:D${10 + contractRows.length}`).conditionalFormats.add(
  "containsText",
  {
    text: "Exclude",
    format: { fill: palette.red, font: { color: palette.redText, bold: true } },
  },
);

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
const v32Values = v32Rows.map((row) => [
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
  .getRangeByIndexes(v32StartRow - 1, 0, v32Values.length, 8)
  .values = v32Values;
v32Sheet
  .getRange(`G${v32StartRow}:G${v32EndRow}`)
  .formulas = v32Rows.map((_, index) => {
    const row = v32StartRow + index;
    return [
      `=IF(COUNTIF('PAD_COD Backmap'!$N$${mapStartRow}:$N$${mapEndRow},B${row})>0,"Yes","No")`,
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
  color: palette.navy,
  size: 9,
  bold: true,
};
v32Sheet.getRange(`D${v32StartRow}:D${v32EndRow}`).format.horizontalAlignment =
  "center";
v32Sheet.getRange(`G${v32StartRow}:G${v32EndRow}`).format.horizontalAlignment =
  "center";
addComparisonConditionalFormatting(
  v32Sheet.getRange(`H${v32StartRow}:H${v32EndRow}`),
);
v32Sheet.getRange(`A${v32StartRow}:A${v32EndRow}`).conditionalFormats.add(
  "containsText",
  {
    text: "No",
    format: { fill: palette.red, font: { color: palette.redText, bold: true } },
  },
);

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
v32Sheet.getRange(`A${v32SourceRow}`).values = [[
  "Sources and audit trail",
]];
v32Sheet.getRange(`A${v32SourceRow}:H${v32SourceRow}`).format = sectionFormat;
const v32SourceRows = [
  [
    "Authoritative v32 workbook",
    String.raw`O:\GitHub\snomed-database-loader\outputs\v32ContractQOFReadCodes-V1-0.xlsx; Contract codes!A1881:E1887`,
  ],
  [
    "Wildcard rule",
    "Contract codes!A31:A32: only codes ending in % include the code and descendants",
  ],
  [
    "Supporting supplied image",
    String.raw`C:\Users\mik78\.codex\attachments\683d6110-d8cd-405b-a0aa-89baed55af54\image-1.png`,
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
for (let index = 0; index < v32SourceRows.length; index += 1) {
  const rowNumber = v32SourceRow + 1 + index;
  v32Sheet.getRange(`A${rowNumber}:B${rowNumber}`).merge();
  v32Sheet.getRange(`C${rowNumber}:H${rowNumber}`).merge();
  v32Sheet.getRange(`A${rowNumber}`).values = [[v32SourceRows[index][0]]];
  v32Sheet.getRange(`C${rowNumber}`).values = [[v32SourceRows[index][1]]];
}
v32Sheet
  .getRange(`A${v32SourceRow + 1}:H${v32SourceRow + v32SourceRows.length}`)
  .format = bodyFormat;
v32Sheet
  .getRange(`A${v32SourceRow + 1}:B${v32SourceRow + v32SourceRows.length}`)
  .format.font = {
    bold: true,
    color: palette.navy,
    size: 9,
  };

setColumnWidths(v32Sheet, {
  A: 92,
  B: 92,
  C: 280,
  D: 85,
  E: 205,
  F: 245,
  G: 135,
  H: 190,
});
v32Sheet
  .getRange(`A1:H${v32SourceRow + v32SourceRows.length}`)
  .format.autofitRows();
v32Sheet.getRange("A17:H17").format.rowHeightPx = 40;
v32Sheet.freezePanes.freezeRows(17);

// ---------------------------------------------------------------------------
// Sheet 2: current PAD_COD active refset and full-history DMWB reverse maps
// ---------------------------------------------------------------------------
backmapSheet.getRange("A1:AD1").merge();
backmapSheet.getRange("A1").values = [[
  "Current PAD_COD SNOMED refset - full-history Read v2 back-map",
]];
backmapSheet.getRange("A1:AD1").format = titleFormat;
backmapSheet.getRange("A1:AD1").format.rowHeightPx = 34;

backmapSheet.getRange("A2:AD2").merge();
backmapSheet.getRange("A2").values = [[
  "One row per PAD_COD member-to-Read v2 mapping route. Direct RCTSCTMAP matches are retained; concept history follows active associations in each valid direction, and incoming retired descriptions are included only where the description ID exactly matches RCTSCTMAP.TTUI.",
]];
backmapSheet.getRange("A2:AD2").format = subtitleFormat;
backmapSheet.getRange("A2:AD2").format.rowHeightPx = 44;

const metricLabels = [
  "Active PAD_COD refset members",
  "Members mapped directly",
  "Members mapped only via concept history",
  "Members mapped only via retired descriptions",
  "Members mapped by any route",
  "Members with no map after full history",
  "Unique back-mapped Read codes",
  "Unique Read codes overlapping v32",
  "Unique back-map-only Read codes",
  "Active refset members absent from loaded PCD table",
];
for (let index = 0; index < metricLabels.length; index += 1) {
  const startCol = index * 3;
  backmapSheet
    .getRangeByIndexes(3, startCol, 1, 3)
    .merge();
  backmapSheet
    .getRangeByIndexes(3, startCol, 1, 3)
    .values = [[metricLabels[index]]];
  backmapSheet
    .getRangeByIndexes(3, startCol, 1, 3)
    .format = {
      fill: palette.paleTeal,
      font: { bold: true, color: palette.navy, size: 8 },
      horizontalAlignment: "center",
      verticalAlignment: "center",
      wrapText: true,
      borders: { bottom: { style: "thin", color: palette.line } },
    };
  backmapSheet
    .getRangeByIndexes(4, startCol, 1, 3)
    .merge();
}
backmapSheet.getRange("A5:C5").formulas = [[
  `=SUM(Y${mapStartRow}:Y${mapEndRow})`,
]];
backmapSheet.getRange("D5:F5").formulas = [[
  `=COUNTIFS(Y${mapStartRow}:Y${mapEndRow},1,F${mapStartRow}:F${mapEndRow},"Direct")`,
]];
backmapSheet.getRange("G5:I5").formulas = [[
  `=COUNTIFS(Y${mapStartRow}:Y${mapEndRow},1,F${mapStartRow}:F${mapEndRow},"Concept history")`,
]];
backmapSheet.getRange("J5:L5").formulas = [[
  `=COUNTIFS(Y${mapStartRow}:Y${mapEndRow},1,F${mapStartRow}:F${mapEndRow},"Description history")`,
]];
backmapSheet.getRange("M5:O5").formulas = [[
  `=SUM(Z${mapStartRow}:Z${mapEndRow})`,
]];
backmapSheet.getRange("P5:R5").formulas = [[
  `=SUM(AA${mapStartRow}:AA${mapEndRow})`,
]];
backmapSheet.getRange("S5:U5").formulas = [[
  `=SUM(AB${mapStartRow}:AB${mapEndRow})`,
]];
backmapSheet.getRange("V5:X5").formulas = [[
  `=SUM(AC${mapStartRow}:AC${mapEndRow})`,
]];
backmapSheet.getRange("Y5:AA5").formulas = [[
  `=SUM(AD${mapStartRow}:AD${mapEndRow})`,
]];
backmapSheet.getRange("AB5:AD5").formulas = [[
  `=COUNTIFS(Y${mapStartRow}:Y${mapEndRow},1,E${mapStartRow}:E${mapEndRow},"No")`,
]];
backmapSheet.getRange("A5:AD5").format = {
  fill: palette.white,
  font: { bold: true, color: palette.navy, size: 16 },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  numberFormat: "0",
};
backmapSheet.getRange("A5:AD5").format.rowHeightPx = 30;

backmapSheet.getRange("A7:AD8").merge();
backmapSheet.getRange("A7").formulas = [[
  `="Objective result: full-history reverse maps cover "&M5&" of "&A5&" active PAD_COD refset members: "&D5&" directly, "&G5&" via concept history only, and "&J5&" via retired-description history only. They produce "&S5&" unique Read v2 codes: "&V5&" overlap v32 and "&Y5&" are additional. "&P5&" members remain unmapped."`,
]];
backmapSheet.getRange("A7:AD8").format = {
  fill: palette.amber,
  font: { color: palette.amberText, size: 10 },
  wrapText: true,
  verticalAlignment: "center",
};

backmapSheet.getRange("A10:H10").merge();
backmapSheet.getRange("A10").values = [["Provenance and limitations"]];
backmapSheet.getRange("A10:H10").format = sectionFormat;
const metadataRows = [
  ["PAD_COD refset ID", `'${data.metadata.PADRefsetId}`],
  ["Official refset FSN", data.metadata.PADRefsetFSN],
  [
    "Current terminology database max effective time",
    data.metadata.SnomedDatabaseReleaseDate,
  ],
  [
    "Active simple refset vs loaded PCD table",
    `${data.metadata.ActivePADConceptCount} vs ${data.metadata.LoadedPCDClusterCount}; active member missing from loaded PCD table: ${data.metadata.LoadedPCDClusterMissingActiveMembers.join(", ")}`,
  ],
  [
    "DMWB map source",
    `${data.metadata.MapType}; release ${data.metadata.MapReleaseDate}; build ${data.metadata.MapBuildDate}; snapshot ${data.metadata.MapSnapshotDate}`,
  ],
  ["DMWB map file", data.metadata.MapSourceFile],
  [
    "Direct mapping",
    "RCTSCTMAP.TCUI (SNOMED concept) → SCUI (Read v2 code); all term-level rows are retained and aggregated per SNOMED/Read pair",
  ],
  [
    "Historical resolution (concept + description)",
    `Concept history follows every active association type forward for replacements and backward for predecessor concepts without mixing directions (maximum ${data.metadata.MaximumHistoricalAssociationDepth} hops). Description history uses incoming active associations from descriptions and accepts only an exact RCTSCTMAP.TTUI description-ID match.`,
  ],
  [
    "Critical limitation",
    "RCTSCTMAP is final static April 2020 data. Broad active historical associations are included, but an unmapped result means no exact direct, concept-history, or retired-description route was found; it does not mean the concept is outside PAD. DMWB source: https://isd.digital.nhs.uk/trud/users/guest/filters/0/categories/7/items/98/releases",
  ],
];
for (let index = 0; index < metadataRows.length; index += 1) {
  const rowNumber = 11 + index;
  const [key, rawValue] = metadataRows[index];
  const value = key.includes("effective time")
    ? yyyymmddToDate(rawValue)
    : rawValue;
  backmapSheet.getRange(`A${rowNumber}:B${rowNumber}`).merge();
  backmapSheet.getRange(`C${rowNumber}:H${rowNumber}`).merge();
  backmapSheet.getRange(`A${rowNumber}`).values = [[key]];
  backmapSheet.getRange(`C${rowNumber}`).values = [[value]];
}
backmapSheet.getRange(`A11:H${10 + metadataRows.length}`).format = bodyFormat;
backmapSheet.getRange(`A11:B${10 + metadataRows.length}`).format.font = {
  bold: true,
  color: palette.navy,
  size: 9,
};
backmapSheet.getRange("C11").format.numberFormat = "@";
backmapSheet.getRange("C13").format.numberFormat = "yyyy-mm-dd";
backmapSheet.getRange("C11:H19").format.horizontalAlignment = "left";
backmapSheet.getRange(`A21:AD21`).merge();
backmapSheet.getRange("A21").values = [[
  "Detailed PAD_COD membership, direct mappings, concept history and retired-description history",
]];
backmapSheet.getRange("A21:AD21").format = sectionFormat;

backmapSheet.getRange("A23:AD23").values = [[
  "PAD_COD SNOMED concept ID",
  "PAD_COD SNOMED FSN",
  "Concept active?",
  "Refset member effective time",
  "In loaded PCD table?",
  "Back-map route",
  "Mapping SNOMED concept ID",
  "Mapping SNOMED FSN",
  "Mapped description ID",
  "Mapped description term",
  "Description active?",
  "Historical association path",
  "History depth",
  "Read v2 code",
  "Read v2 preferred term",
  "Read v2 status",
  "DMWB map type",
  "Assurance",
  "Mapped term ID(s)",
  "Map term basis",
  "Closure code?",
  "In v32?",
  "Objective comparison",
  "Audit note",
  "First concept row",
  "Mapped concept flag",
  "Unmapped concept flag",
  "First Read code row",
  "Unique overlap flag",
  "Unique back-map-only flag",
]];
backmapSheet.getRange("A23:AD23").format = headerFormat;

const mapValues = mapRows.map((row) => [
  `'${String(row.SnomedConceptId)}`,
  row.SnomedFSN,
  row.ConceptIsActive ? "Yes" : "No",
  yyyymmddToDate(row.MemberEffectiveTime),
  row.InLoadedPCDCluster ? "Yes" : "No",
  row.BackMapRoute,
  row.ResolvedConceptId ? `'${String(row.ResolvedConceptId)}` : "",
  row.ResolvedFSN,
  row.MappedDescriptionId ? `'${String(row.MappedDescriptionId)}` : "",
  row.MappedDescriptionTerm,
  row.MappedDescriptionIsActive === ""
    ? ""
    : row.MappedDescriptionIsActive
      ? "Yes"
      : "No",
  row.HistoricalAssociationPath,
  row.HistoricalDepth,
  row.ReadV2Code,
  row.ReadV2Term,
  row.ReadV2Status,
  row.MapType,
  row.Assurance,
  row.MapTermIDs ? `'${row.MapTermIDs}` : "",
  row.MapTermBasis,
  row.ListClosureCode,
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  null,
]);
backmapSheet
  .getRangeByIndexes(mapStartRow - 1, 0, mapValues.length, 30)
  .values = mapValues;

backmapSheet
  .getRange(`V${mapStartRow}:V${mapEndRow}`)
  .formulas = mapRows.map((_, index) => {
    const row = mapStartRow + index;
    return [
      `=IF(N${row}="","N/A",IF(COUNTIFS('V32 Contract'!$A$${v32StartRow}:$A$${v32EndRow},"Yes",'V32 Contract'!$B$${v32StartRow}:$B$${v32EndRow},N${row})>0,"Yes","No"))`,
    ];
  });
backmapSheet
  .getRange(`W${mapStartRow}:W${mapEndRow}`)
  .formulas = mapRows.map((_, index) => {
    const row = mapStartRow + index;
    return [
      `=IF(N${row}="","No Read v2 back-map after full history",IF(V${row}="Yes",IF(F${row}="Concept history","Overlap - concept-history route",IF(F${row}="Description history","Overlap - retired-description route","Overlap - direct route")),IF(F${row}="Concept history","Concept-history back-map only - not in v32",IF(F${row}="Description history","Retired-description back-map only - not in v32","Direct back-map only - not in v32"))))`,
    ];
  });
backmapSheet
  .getRange(`X${mapStartRow}:X${mapEndRow}`)
  .formulas = mapRows.map((_, index) => {
    const row = mapStartRow + index;
    return [
      `=IF(E${row}="No","Active refset member missing from loaded PCD_Refset_Content_V2 cluster","")&IF(F${row}="Concept history",IF(E${row}="No","; ","")&"Concept association resolved before Read v2 lookup","")&IF(F${row}="Description history",IF(OR(E${row}="No",F${row}="Concept history"),"; ","")&"Exact retired description ID matched RCTSCTMAP.TTUI","")`,
    ];
  });
backmapSheet
  .getRange(`Y${mapStartRow}:Y${mapEndRow}`)
  .formulas = mapRows.map((_, index) => {
    const row = mapStartRow + index;
    return [`=IF(COUNTIF($A$${mapStartRow}:A${row},A${row})=1,1,0)`];
  });
backmapSheet
  .getRange(`Z${mapStartRow}:Z${mapEndRow}`)
  .formulas = mapRows.map((_, index) => {
    const row = mapStartRow + index;
    return [
      `=IF(Y${row}=1,IF(N${row}<>"",1,0),0)`,
    ];
  });
backmapSheet
  .getRange(`AA${mapStartRow}:AA${mapEndRow}`)
  .formulas = mapRows.map((_, index) => {
    const row = mapStartRow + index;
    return [`=Y${row}-Z${row}`];
  });
backmapSheet
  .getRange(`AB${mapStartRow}:AB${mapEndRow}`)
  .formulas = mapRows.map((_, index) => {
    const row = mapStartRow + index;
    return [
      `=IF(N${row}="",0,IF(COUNTIF($N$${mapStartRow}:N${row},N${row})=1,1,0))`,
    ];
  });
backmapSheet
  .getRange(`AC${mapStartRow}:AC${mapEndRow}`)
  .formulas = mapRows.map((_, index) => {
    const row = mapStartRow + index;
    return [`=IF(AB${row}=1,IF(V${row}="Yes",1,0),0)`];
  });
backmapSheet
  .getRange(`AD${mapStartRow}:AD${mapEndRow}`)
  .formulas = mapRows.map((_, index) => {
    const row = mapStartRow + index;
    return [`=IF(AB${row}=1,IF(V${row}="No",1,0),0)`];
  });

backmapSheet.getRange(`A${mapStartRow}:AD${mapEndRow}`).format = bodyFormat;
backmapSheet.getRange(`A${mapStartRow}:A${mapEndRow}`).format.font = {
  name: "Consolas",
  color: palette.navy,
  size: 9,
};
backmapSheet.getRange(`A${mapStartRow}:A${mapEndRow}`).format.numberFormat = "@";
backmapSheet.getRange(`G${mapStartRow}:G${mapEndRow}`).format.font = {
  name: "Consolas",
  color: palette.navy,
  size: 9,
};
backmapSheet.getRange(`G${mapStartRow}:G${mapEndRow}`).format.numberFormat = "@";
backmapSheet.getRange(`I${mapStartRow}:I${mapEndRow}`).format.font = {
  name: "Consolas",
  color: palette.navy,
  size: 9,
};
backmapSheet.getRange(`I${mapStartRow}:I${mapEndRow}`).format.numberFormat = "@";
backmapSheet.getRange(`N${mapStartRow}:N${mapEndRow}`).format.font = {
  name: "Consolas",
  color: palette.navy,
  size: 9,
  bold: true,
};
backmapSheet
  .getRange(`D${mapStartRow}:D${mapEndRow}`)
  .format.numberFormat = "yyyy-mm-dd";
backmapSheet
  .getRange(`S${mapStartRow}:S${mapEndRow}`)
  .format.numberFormat = "@";
backmapSheet.getRange(`C${mapStartRow}:G${mapEndRow}`).format.horizontalAlignment =
  "center";
backmapSheet.getRange(`K${mapStartRow}:V${mapEndRow}`).format.horizontalAlignment =
  "center";
backmapSheet.getRange(`Y${mapStartRow}:AD${mapEndRow}`).format = auditFormat;
backmapSheet
  .getRange(`E${mapStartRow}:E${mapEndRow}`)
  .conditionalFormats.add("containsText", {
    text: "No",
    format: { fill: palette.red, font: { color: palette.redText, bold: true } },
  });
backmapSheet
  .getRange(`F${mapStartRow}:F${mapEndRow}`)
  .conditionalFormats.add("containsText", {
    text: "Direct",
    format: { fill: palette.green, font: { color: palette.greenText } },
  });
backmapSheet
  .getRange(`F${mapStartRow}:F${mapEndRow}`)
  .conditionalFormats.add("containsText", {
    text: "Concept history",
    format: {
      fill: palette.amber,
      font: { color: palette.amberText, bold: true },
    },
  });
backmapSheet
  .getRange(`F${mapStartRow}:F${mapEndRow}`)
  .conditionalFormats.add("containsText", {
    text: "Description history",
    format: {
      fill: palette.paleTeal,
      font: { color: palette.navy, bold: true },
    },
  });
backmapSheet
  .getRange(`F${mapStartRow}:F${mapEndRow}`)
  .conditionalFormats.add("containsText", {
    text: "Unmapped",
    format: { fill: palette.grey, font: { color: palette.greyText } },
  });
addComparisonConditionalFormatting(
  backmapSheet.getRange(`W${mapStartRow}:W${mapEndRow}`),
);

const backmapTable = backmapSheet.tables.add(
  `A23:AD${mapEndRow}`,
  true,
  "PADCurrentBackmap",
);
backmapTable.style = "TableStyleMedium2";
backmapTable.showBandedRows = true;
backmapTable.showFilterButton = true;

setColumnWidths(backmapSheet, {
  A: 128,
  B: 305,
  C: 76,
  D: 110,
  E: 92,
  F: 105,
  G: 128,
  H: 260,
  I: 120,
  J: 220,
  K: 80,
  L: 300,
  M: 62,
  N: 90,
  O: 225,
  P: 76,
  Q: 78,
  R: 82,
  S: 105,
  T: 132,
  U: 80,
  V: 72,
  W: 190,
  X: 250,
  Y: 66,
  Z: 66,
  AA: 66,
  AB: 66,
  AC: 66,
  AD: 66,
});
backmapSheet.getRange(`A1:AD${mapEndRow}`).format.autofitRows();
backmapSheet.getRange("A23:AD23").format.rowHeightPx = 50;
backmapSheet.freezePanes.freezeRows(23);

// Compact inspection and formula/error verification before export.
const v32Inspection = await workbook.inspect({
  kind: "table",
  range: `V32 Contract!A1:H${Math.min(v32EndRow, 26)}`,
  include: "values,formulas",
  tableMaxRows: 26,
  tableMaxCols: 8,
  maxChars: 8000,
});
console.log("V32_INSPECTION");
console.log(v32Inspection.ndjson);

const backmapInspection = await workbook.inspect({
  kind: "table",
  range: `PAD_COD Backmap!A1:AD${Math.min(mapEndRow, 27)}`,
  include: "values,formulas",
  tableMaxRows: 27,
  tableMaxCols: 30,
  maxChars: 14000,
});
console.log("BACKMAP_INSPECTION");
console.log(backmapInspection.ndjson);

const missingPcdRow =
  mapStartRow +
  mapRows.findIndex(
    (row) => String(row.SnomedConceptId) === "275520000",
  );
const discrepancyInspection = await workbook.inspect({
  kind: "table",
  range: `PAD_COD Backmap!A${missingPcdRow}:X${missingPcdRow}`,
  include: "values,formulas",
  tableMaxRows: 2,
  tableMaxCols: 24,
  maxChars: 3500,
});
console.log("PCD_DISCREPANCY_INSPECTION");
console.log(discrepancyInspection.ndjson);

const retiredDescriptionRow =
  mapStartRow +
  mapRows.findIndex(
    (row) => String(row.SnomedConceptId) === "840580004",
  );
const retiredDescriptionInspection = await workbook.inspect({
  kind: "table",
  range: `PAD_COD Backmap!A${retiredDescriptionRow}:X${retiredDescriptionRow}`,
  include: "values,formulas",
  tableMaxRows: 2,
  tableMaxCols: 24,
  maxChars: 4000,
});
console.log("RETIRED_DESCRIPTION_INSPECTION");
console.log(retiredDescriptionInspection.ndjson);

const formulaErrors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "final formula error scan",
});
console.log("FORMULA_ERRORS");
console.log(formulaErrors.ndjson);

const v32Preview = await workbook.render({
  sheetName: "V32 Contract",
  range: `A1:H${v32SourceRow + v32SourceRows.length}`,
  scale: 1,
  format: "png",
});
await fs.writeFile(
  v32PreviewPath,
  new Uint8Array(await v32Preview.arrayBuffer()),
);
const backmapPreview = await workbook.render({
  sheetName: "PAD_COD Backmap",
  range: `A1:AD${Math.min(mapEndRow, 46)}`,
  scale: 0.5,
  format: "png",
});
await fs.writeFile(
  backmapPreviewPath,
  new Uint8Array(await backmapPreview.arrayBuffer()),
);

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(workbookPath);
const exportedBlob = await FileBlob.load(workbookPath);
const exportedWorkbook = await SpreadsheetFile.importXlsx(exportedBlob);
const exportedSheets = await exportedWorkbook.inspect({
  kind: "sheet",
  include: "id,name",
  maxChars: 2000,
});
console.log("EXPORTED_SHEETS");
console.log(exportedSheets.ndjson);
const exportedErrors = await exportedWorkbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "exported workbook formula error scan",
});
console.log("EXPORTED_FORMULA_ERRORS");
console.log(exportedErrors.ndjson);
console.log(
  JSON.stringify(
    {
      workbookPath,
      v32PreviewPath,
      backmapPreviewPath,
      v32Rows: v32Rows.length,
      mappingRows: mapRows.length,
      mapEndRow,
    },
    null,
    2,
  ),
);
