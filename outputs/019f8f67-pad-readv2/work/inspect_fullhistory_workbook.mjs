import fs from "node:fs/promises";
import path from "node:path";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const workbookPath =
  "O:\\GitHub\\snomed-database-loader\\outputs\\019f8f67-pad-readv2\\PAD_ReadV2_Comparison_FullHistory.xlsx";
const outputDir =
  "O:\\GitHub\\snomed-database-loader\\outputs\\019f8f67-pad-readv2\\work";

const workbook = await SpreadsheetFile.importXlsx(
  await FileBlob.load(workbookPath),
);

for (const [label, request] of [
  [
    "SHEETS",
    {
      kind: "sheet",
      include: "id,name",
      maxChars: 3000,
    },
  ],
  [
    "V32_VALUES_FORMULAS",
    {
      kind: "table",
      range: "V32 Contract!A1:H56",
      include: "values,formulas",
      tableMaxRows: 56,
      tableMaxCols: 8,
      maxChars: 16000,
    },
  ],
  [
    "BACKMAP_SUMMARY_VALUES_FORMULAS",
    {
      kind: "table",
      range: "PAD_COD Backmap!A1:H63",
      include: "values,formulas",
      tableMaxRows: 63,
      tableMaxCols: 8,
      maxChars: 30000,
    },
  ],
  [
    "BROADEST_COVERAGE_VALUES_FORMULAS",
    {
      kind: "table",
      range: "Broadest Coverage!A1:G46",
      include: "values,formulas",
      tableMaxRows: 46,
      tableMaxCols: 7,
      maxChars: 24000,
    },
  ],
  [
    "V32_STYLES",
    {
      kind: "computedStyle",
      sheetId: "V32 Contract",
      range: "A1:H18",
      maxChars: 5000,
    },
  ],
  [
    "FORMULA_ERRORS",
    {
      kind: "match",
      searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
      options: { useRegex: true, maxResults: 300 },
      summary: "existing workbook formula error scan",
    },
  ],
]) {
  const result = await workbook.inspect(request);
  console.log(label);
  console.log(result.ndjson);
}

for (const [sheetName, range, filename, scale] of [
  [
    "V32 Contract",
    "A1:H56",
    "existing_fullhistory_v32.png",
    1,
  ],
  [
    "PAD_COD Backmap",
    "A1:H63",
    "existing_fullhistory_backmap.png",
    0.75,
  ],
  [
    "Broadest Coverage",
    "A1:G46",
    "existing_fullhistory_broadest_coverage.png",
    1,
  ],
]) {
  const rendered = await workbook.render({
    sheetName,
    range,
    scale,
    format: "png",
  });
  const previewPath = path.join(outputDir, filename);
  await fs.writeFile(
    previewPath,
    new Uint8Array(await rendered.arrayBuffer()),
  );
  console.log(`PREVIEW=${previewPath}`);
}
