import fs from "node:fs/promises";
import path from "node:path";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const sourcePath =
  "O:\\GitHub\\snomed-database-loader\\outputs\\v32ContractQOFReadCodes-V1-0.xlsx";
const outputDir =
  "O:\\GitHub\\snomed-database-loader\\outputs\\019f8f67-pad-readv2\\work";

const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(sourcePath));
const sheetSummary = await workbook.inspect({
  kind: "sheet",
  include: "id,name",
  maxChars: 4000,
});
console.log("SHEETS");
console.log(sheetSummary.ndjson);

const padMatches = await workbook.inspect({
  kind: "match",
  searchTerm: "Peripheral Arterial Disease",
  options: { useRegex: false, maxResults: 20 },
  summary: "PAD source locations",
});
console.log("PAD_MATCHES");
console.log(padMatches.ndjson);

const percentMatches = await workbook.inspect({
  kind: "match",
  searchTerm: "Codes that end with '%'",
  options: { useRegex: false, maxResults: 20 },
  summary: "wildcard note locations",
});
console.log("WILDCARD_NOTE_MATCHES");
console.log(percentMatches.ndjson);

const padSheet = workbook.worksheets.getItemAt(0);
const padRows = await workbook.inspect({
  kind: "table",
  range: `${padSheet.name}!A1875:F1900`,
  include: "values,formulas",
  tableMaxRows: 20,
  tableMaxCols: 8,
  maxChars: 8000,
});
console.log("PAD_ROWS");
console.log(padRows.ndjson);

const noteRows = await workbook.inspect({
  kind: "table",
  range: `${padSheet.name}!A25:F36`,
  include: "values,formulas",
  tableMaxRows: 20,
  tableMaxCols: 8,
  maxChars: 8000,
});
console.log("NOTE_ROWS");
console.log(noteRows.ndjson);

for (const [name, range, filename, scale] of [
  ["PAD", "A1875:F1900", "source_v32_pad_rows.png", 1.2],
  ["Notes", "A25:F36", "source_v32_notes.png", 1.1],
]) {
  const rendered = await workbook.render({
    sheetName: padSheet.name,
    range,
    scale,
    format: "png",
  });
  await fs.writeFile(
    path.join(outputDir, filename),
    new Uint8Array(await rendered.arrayBuffer()),
  );
  console.log(`${name}_PREVIEW=${path.join(outputDir, filename)}`);
}
