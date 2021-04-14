import { LightningElement , wire , track , api} from 'lwc';
import getAllReferrals from '@salesforce/apex/auntBerthaCBO.getAllReferrals';
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

    @api showSettings;
    
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

    openSettings = () => {
        this.showSettings = true;
    }

    closeSettings = () => {
        this.showSettings = false;
    }

    handleCreateNewReferral = (event) => {
        console.log('Referral detail : ',event.detail.fields);
        this.showNewModal = false;
        console.log('2');
        //this.loadReferrals();
        //refreshApex(this.data);
        console.log('3');
    }
}