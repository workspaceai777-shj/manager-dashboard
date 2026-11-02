/**
 * Run once in Extensions > Apps Script from the existing V2 workbook.
 * Non-destructive: leaves Form responses, Setup Info and Task Catalog untouched.
 */
function initializeOntarioAppTabs() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const tabs = {
    App_Users: ['uid','email','name','role','active'],
    App_Assignments: ['uid','branch','category','active'],
    App_Entries: ['id','createdAt','uid','employeeName','date','branch','category','taskId','emr','remarks','quantity','hours']
  };
  for (const [title, header] of Object.entries(tabs)) {
    let sheet = ss.getSheetByName(title);
    if (sheet) {
      const existing = sheet.getRange(1,1,1,header.length).getDisplayValues()[0];
      if (existing.some(Boolean) && existing.join('|') !== header.join('|')) {
        throw new Error('Unexpected existing header in '+title+'; do not overwrite.');
      }
    } else sheet = ss.insertSheet(title);
    sheet.getRange(1,1,1,header.length).setValues([header]).setBackground('#263859').setFontColor('#ffffff').setFontWeight('bold');
    sheet.setFrozenRows(1);
  }
  Logger.log('App tabs initialized in '+ss.getUrl());
}
