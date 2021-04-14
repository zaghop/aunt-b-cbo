import { LightningElement , wire , track , api} from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import getAllReferrals from '@salesforce/apex/auntBerthaCBO.getAllReferrals';
import sendStatusToEndpoint from '@salesforce/apex/auntBerthaCBO.sendStatusToEndpoint';
import processNewReferralRecord from '@salesforce/apex/auntBerthaCBO.processNewReferralRecord';
import REFERRALID_FIELD from '@salesforce/schema/Referral__c.Referral_ID__c';
import STATUS_FIELD from '@salesforce/schema/Referral__c.Status__c';
import FOLLOWUP_FIELD from '@salesforce/schema/Referral__c.Needs_Follow_Up__c';
import PROGRAM_FIELD from '@salesforce/schema/Referral__c.Program__c';
const actions = [
    { label: 'Show details', name: 'show_details' },
    { label: 'Delete', name: 'delete' },
];

const columns = [
    /*{
        type: 'button',
        typeAttributes: {label: 'View', variant: 'base', onclick: ''}
    },*/
    { label: 'Name', fieldName: 'Name', type: 'text' },
    { label: 'Referral Id', fieldName: 'Referral_ID__c', type: 'text' },
    { label: 'Status', fieldName: 'Status__c', type: 'text' },
    { label: 'Program', fieldName: 'Program__c', type: 'text' },
    { label: 'Follow Up?', fieldName: 'Needs_Follow_Up__c', type: 'boolean' },
    {
        type: 'action',
        typeAttributes: { rowActions: actions },
    }
];
export default class AuntBerthaCBO extends LightningElement {
    data = [];
    columns = columns;
    showNewModal = false;
    showRecordModal = false;
    recordId = '';
    fields = [REFERRALID_FIELD, STATUS_FIELD, FOLLOWUP_FIELD, PROGRAM_FIELD];

    connectedCallback() {
		this.loadReferrals();
	}
	loadReferrals() {
		getAllReferrals()
			.then(result => {
                this.data = result;
                console.log(this.data);
			})
			.catch(error => {
                this.error = error;
                console.log(this.error);
			});
    }
    
    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        switch (action.name) {
            case 'show_details':
                this.recordId = row.Id;
                this.showRecordModal = true;
                console.log('this.showRecordModal = ', this.showRecordModal);
                break;
            case 'delete':
                /*const rows = this.data;
                const rowIndex = rows.indexOf(row);
                rows.splice(rowIndex, 1);
                this.data = rows;*/
                console.log('delete');
                break;
        }
    }

    openNewModal = () => {
        this.showNewModal = true;
    }

    closeNewModal = () => {
        this.showNewModal = false;
    }

    closeRecordModal = () => {
        this.showRecordModal = false;
    }

    // after new record save is successful 
    handleCreateReferralSuccess = (event) => {
        console.log('1');

        console.log('fields raw: ', event.detail.fields);

        const fields = JSON.stringify(event.detail.fields);
        console.log('fields json: ', fields);


        // newly created Id
        this.recordId = event.detail.id;
        console.log(`new record id[${this.recordId}]`);

        // all fields
        //fields.Street = '32 Prince Street';
        //this.loadReferrals();
        //refreshApex(this.data);
        processNewReferralRecord({ recordId: this.recordId })
            .then(result => {
                /* close modal */
                this.closeNewModal();
                
                /* refresh list */
                //refreshApex(this);
            })
			.then(result => {
                this.data = result;
                const evt = new ShowToastEvent({
                    title: "New record saved",
                    message: "New record saved",
                    variant: "success"
                });
                this.dispatchEvent(evt);
            })
			.catch(error => {
                this.error = error;
                const evt = new ShowToastEvent({
                    title: "Error saving new record",
                    message: this.error,
                    variant: "error"
                });
                this.dispatchEvent(evt);
            });

    }

    // after submit is successful 
    handleEditReferralSuccess = (event) => {
        console.log('in handleEditReferralSuccess() 1');

        const fields = event.detail.fields;
        //console.log(`fields[${JSON.stringify(fields)}]`);
        const newStat = fields.Status__c.value;
        //console.log(`newStat[${newStat}]`);
        const refId = fields.Referral_ID__c.value;
        //console.log(`refId[${refId}]`);

        sendStatusToEndpoint({ referralId: refId, newStatus: newStat })
            .then(result => {
                /* close modal */
                this.closeRecordModal();
                
                /* refresh list */
                //refreshApex(this);
            })
			.then(result => {
                this.data = result;
                const evt = new ShowToastEvent({
                    title: "Record updated",
                    message: "Record updated",
                    variant: "success"
                });
                this.dispatchEvent(evt);
            })
			.catch(error => {
                this.error = error;
                const evt = new ShowToastEvent({
                    title: "Error updating Record",
                    message: this.error,
                    variant: "error"
                });
                this.dispatchEvent(evt);
            });

    }

}