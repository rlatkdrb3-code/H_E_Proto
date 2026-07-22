# Google Sheets test data collection

## Sheet columns

Created sheet:

https://docs.google.com/spreadsheets/d/1aQM3jwwH3hyc5hz5Ol7MJt-CJZWU6FKUTZClWa6qu_o/edit

The first row has already been created:

```text
userID	Type	trial	Timestamp	isTemporaryMode	From	To	accessDuration(sec)	switchDuration(sec)	Misoperation	elapsed(sec)	startedAt	endedAt	receivedAt
```

## Apps Script

Open the sheet, then go to `Extensions > Apps Script` and paste this code.

```javascript
const SPREADSHEET_ID = '1aQM3jwwH3hyc5hz5Ol7MJt-CJZWU6FKUTZClWa6qu_o';
const SHEET_NAME = 'Sheet1';
const TOKEN = 'a6d087b47cddd90b7b0b9b1cf6ea4a26';

function doPost(e) {
  const payload = JSON.parse(e.postData.contents || '{}');
  if (TOKEN && payload.token !== TOKEN) {
    return jsonResponse({ ok: false, error: 'unauthorized' }, 401);
  }

  const sheet = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(SHEET_NAME);
  if (!sheet) {
    return jsonResponse({ ok: false, error: 'sheet not found' }, 404);
  }

  const rows = Array.isArray(payload.rows) ? payload.rows : [];
  const receivedAt = new Date();
  const values = rows.map((row) => [
    payload.userID || '',
    payload.type || '',
    row.trial || '',
    row.timestamp || '',
    row.isTemporaryMode ?? '',
    row.from || '',
    row.to || '',
    row.accessDurationSec ?? '',
    row.switchDurationSec ?? '',
    row.misoperation ?? '',
    row.elapsedSec ?? '',
    payload.startedAt || '',
    payload.endedAt || '',
    receivedAt,
  ]);

  if (values.length > 0) {
    sheet.getRange(sheet.getLastRow() + 1, 1, values.length, values[0].length)
      .setValues(values);
  }

  return jsonResponse({ ok: true, inserted: values.length });
}

function jsonResponse(data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}
```

## Deploy

1. Click `Deploy > New deployment`.
2. Select `Web app`.
3. Set `Execute as` to `Me`.
4. Set `Who has access` to `Anyone`.
5. Deploy and copy the `/exec` URL.

## Run/build the app with collection enabled

Use the copied web app URL and the same token from the script.

```bash
flutter run \
  --dart-define=SHEET_ENDPOINT='https://script.google.com/macros/s/AKfycbxPIHJYPo0VotYjlftKwe4rtaQ-0mOKyD7elNp-wCtEEYjQ84hmbWLA2O9tMnwYIZGw/exec' \
  --dart-define=SHEET_TOKEN='a6d087b47cddd90b7b0b9b1cf6ea4a26'
```

For release builds, pass the same values to `flutter build`.
