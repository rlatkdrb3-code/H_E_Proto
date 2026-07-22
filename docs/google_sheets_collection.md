# Google Sheets test data collection

## Sheet columns

Create a private sheet for pseudonymous experiment IDs. Do not commit the
sheet URL, Apps Script deployment URL, or collection token.

The first row has already been created:

```text
userID	Type	trial	Timestamp	isTemporaryMode	From	To	accessDuration(sec)	switchDuration(sec)	Misoperation	elapsed(sec)	startedAt	endedAt	receivedAt
```

## Apps Script

Open the sheet, then go to `Extensions > Apps Script` and paste this code.

```javascript
const SPREADSHEET_ID = '<YOUR_SPREADSHEET_ID>';
const SHEET_NAME = 'Sheet1';
const TOKEN = '<RANDOM_SHARED_SECRET>';

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
  --dart-define=SHEET_ENDPOINT='<YOUR_APPS_SCRIPT_WEB_APP_URL>' \
  --dart-define=SHEET_TOKEN='<SAME_SHARED_SECRET>'
```

For release builds, pass the same values to `flutter build`. Rotate the shared
secret immediately if it is ever committed or otherwise exposed.
