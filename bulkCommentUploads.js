import processData from '@salesforce/apex/BulkCommentUploads.processData';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import {api, LightningElement, track} from 'lwc';

const columns = [
  {label: 'Case Number', fieldName: 'caseNumber'},
  {label: 'Comment', fieldName: 'comment', type: 'text', wrapText: true},
  {label: 'LDAPS', fieldName: 'ldaps'},
  {label: 'Status', fieldName: 'status', type: 'richtext', wrapText: true},
];

const errColumns = [{label: 'Message', fieldName: 'errorMsg'}];
export default class BulkCommentUploads extends LightningElement {
  @track successRecords;
  @track failedRecords;
  @track columns = columns;
  @track errColumns = errColumns;
  @track showError = false;
  @track errorMsg;
  @track successHeader;
  @track failHeader;
  @track showResult = false;
  @track loading = false;
  // accepted parameters
  get acceptedFormats() {
    return ['.csv'];
  }
  handleDone(event) {
    location.reload();
  }
  displayError(msg) {
    this.loading = false;
    this.showError = true;
    this.errorMsg = msg;
  }
  handleUploadFinished(event) {
    var txt;
    var confirmResponse =
        confirm('Are you sure you want to proceed with updating these cases ?');
    if (confirmResponse == true) {
      this.loading = true;
      const uploadedFiles = event.detail.files;
      processData({idContentDocument: uploadedFiles[0].documentId})
          .then(result => {
            this.errorMsg = result.errorMsg;
            if (this.errorMsg == '') {
              this.successRecords = result.successRecords;
              this.successHeader =
                  'Success Records (' + this.successRecords.length + ')';
              this.failedRecords = result.failedRecords;
              this.failHeader =
                  'Failed Records (' + this.failedRecords.length + ')';
              this.showResult = true;
            } else {
              this.showError = true;
            }
            this.loading = false;
          })
          .catch(error => {
            this.error = error;
            this.displayError(JSON.stringify(error));
          })
    } else {
      this.displayError('Process Canceled');
    }
  }
}
