const fs = require('fs');
const { PDFParse } = require('pdf-parse');

const pdfPath = process.argv[2];
const outPath = process.argv[3] || pdfPath.replace(/\.pdf$/i, '.txt');

(async () => {
  try {
    const buf = fs.readFileSync(pdfPath);
    const parser = new PDFParse({ data: buf });
    const result = await parser.getText();
    let combined = '';
    if (Array.isArray(result.pages)) {
      result.pages.forEach((p, i) => {
        combined += `\n\n===== PAGE ${i + 1} =====\n\n` + (p.text || '');
      });
    } else if (typeof result.text === 'string') {
      combined = result.text;
    }
    fs.writeFileSync(outPath, combined, 'utf8');
    console.log(JSON.stringify({
      pages: Array.isArray(result.pages) ? result.pages.length : (result.numpages || null),
      chars: combined.length,
      out: outPath
    }));
  } catch (e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
