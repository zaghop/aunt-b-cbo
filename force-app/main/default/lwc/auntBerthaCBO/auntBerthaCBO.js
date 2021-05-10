import { LightningElement , wire , track , api} from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSettings from "@salesforce/apex/AuntBerthaReferralManager.getSettings";
import getAllReferrals from '@salesforce/apex/auntBerthaCBO.getAllReferrals';
import sendStatusToEndpoint from '@salesforce/apex/auntBerthaCBO.sendStatusToEndpoint';
import processNewReferralRecord from '@salesforce/apex/auntBerthaCBO.processNewReferralRecord';
import getAllRefsFromAB from '@salesforce/apex/AuntBerthaReferralManager.getAllRefsFromAB';
import REFERRALID_FIELD from '@salesforce/schema/Referral__c.Referral_ID__c';
import STATUS_FIELD from '@salesforce/schema/Referral__c.Status__c';
import FOLLOWUP_FIELD from '@salesforce/schema/Referral__c.Needs_Follow_Up__c';
import PROGRAM_FIELD from '@salesforce/schema/Referral__c.Program__c';

// Import message service features required for subscribing and the message channel
import {
    subscribe,
    unsubscribe,
    APPLICATION_SCOPE,
    MessageContext
} from 'lightning/messageService';
import ReferralImportIsComplete from '@salesforce/messageChannel/Referral_Import_Completed__c';


const columns = [
    {
        label: 'View',
        type: 'button-icon',
        initialWidth: 25,
        size: 'x-small',
        typeAttributes: {
            iconName: 'action:preview',
            title: 'Details',
            variant: 'bare',
            alternativeText: 'Details'
        }
      },
    { label: 'Name', fieldName: 'Name', type: 'text' },
    { label: 'Referral Id', fieldName: 'Referral_ID__c', type: 'text' },
    { label: 'Status', fieldName: 'Status__c', type: 'text' },
    { label: 'Program', fieldName: 'Program__c', type: 'text' },
    { label: 'Follow Up?', fieldName: 'Needs_Follow_Up__c', type: 'boolean' }
];
export default class AuntBerthaCBO extends LightningElement {
    data = [];
    columns = columns;
    showNewModal = false;
    showRecordModal = false;
    recordId = '';
    fields = [REFERRALID_FIELD, STATUS_FIELD, FOLLOWUP_FIELD, PROGRAM_FIELD];

    @api showSettings;
    @api canConfig;
    @api theSpinner;
    
    get showSpinner(){
        return this.theSpinner;
    }

///////////////   Begin. Lightningn Messaging Service implementation     ///////////////////////////
// Used for inter-component communication with auntBerthaReferralManagerAuth

    @wire(MessageContext)
    messageContext;

    // Encapsulate logic for Lightning message service subscribe and unsubsubscribe
    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                ReferralImportIsComplete,
                (message) => this.handleMessage(message),
                { scope: APPLICATION_SCOPE }
            );
        }
    }

    unsubscribeToMessageChannel() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    // Handler for LMS message received by component
    handleMessage(message) {
        console.log(`inside handleMessage for importCompleted LMS message [${JSON.stringify(message)}]`)
        if(message.myMsg.toUpperCase() === 'IMPORTCOMPLETED'){
            getAllReferrals()
			.then(result => {
                this.data = result;
                if(! this.data.length > 0){
                    this.noReferralsInDb = true;
                }
                console.log(`importCompleted. data length[${this.data.length}]`);
			})
			.catch(error => {
                console.log('catching it here');
                this.error = error;
                console.log(this.error);
			});
        }
    }

    disconnectedCallback() {
        this.unsubscribeToMessageChannel();
    }
///////////////   End. Lightningn Messaging Service implementation     ///////////////////////////


    connectedCallback() {
        this.subscribeToMessageChannel();
        getSettings().then(result => {
            if(result.profile == 'admin'){
                this.canConfig = true;
            }
            else{
                this.canConfig = false;
            }
        });
		this.loadReferrals();
    }

    loadReferrals() {
        this.theSpinner = true;

        getAllRefsFromAB();
		getAllReferrals()
			.then(result => {
                this.data = result;
                if(! this.data.length > 0){
                    this.noReferralsInDb = true;
                }
                console.log(`local all data after getAllRefsFromAB() length[${this.data.length}]`);
                this.theSpinner = false;
			})
			.catch(error => {
                this.error = error;
                console.log(this.error);
			});
}
    
    handleRowAction(event) {
        const row = event.detail.row;
        console.log(`in handleRowAction`);
        this.recordId = row.Id;
        this.showRecordModal = true;
        console.log('this.showRecordModal = ', this.showRecordModal);
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
        /*console.log('1');

        console.log('fields raw: ', event.detail.fields);

        const fields = JSON.stringify(event.detail.fields);
        console.log('fields json: ', fields);


        // newly created Id
        this.recordId = event.detail.id;
        console.log(`new record id[${this.recordId}]`);

        processNewReferralRecord({ recordId: this.recordId })
            .then(result => {
                this.closeNewModal();
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
            });*/

    }

    // submit clicked 
    handleEditReferralSubmit = (event) => {
        event.stopPropagation();
        event.preventDefault();

        console.log('in handleEditReferralSubmit() 1');

        this.theSpinner = true;

        console.log(`details on submit[${JSON.stringify(event.detail)}]`);

        //const fields = event.detail.fields;
        //console.log(`fields on submit[${JSON.stringify(fields)}]`);

        const newStat = event.detail.fields.Status__c;
        //const newStat = 'blaaaa';

        console.log(`this.recordId [${this.recordId}], newStat [${newStat}]`);

        // use this.data collected after getAllReferrals() function call earlier 
        console.log(`this.data collected after getAllReferrals(): ${JSON.stringify(this.data)}`);
        for(var i=0; i<this.data.length; i++) {
            if(this.data[i].Id == this.recordId){
                let refId = this.data[i].Referral_ID__c;
                let oldStat = this.data[i].Status__c;
                console.log(`ref_ID[${refId}], oldStat[${oldStat}]`);

                sendStatusToEndpoint({ referralId: refId, newStatus: newStat })
                .then(result => {
                    console.log(`back from sendStatusToEndpoint. result[${result}]`);

                    this.theSpinner = false;

                    this.closeRecordModal();
            
                    // submit form
                    this.template.querySelector('lightning-record-edit-form').submit(event.detail.fields);
        
                    const evt = new ShowToastEvent({
                        title: "Record updated",
                        message: "Record updated",
                        variant: "success"
                    });
                    this.dispatchEvent(evt);
                })
                .catch(error => {
                    console.log(`catch error from sendStatusToEndpoint [${JSON.stringify(error)}]`);

                    this.theSpinner = false;

                    this.closeRecordModal();

                    this.error = error;
                    const evt = new ShowToastEvent({
                        title: "Error updating Record at AB",
                        message: 'Status not changed',
                        variant: "error"
                    });
                    this.dispatchEvent(evt);

                });

                break;
            }
        }
    }

    // save succeeded.    
    handleEditReferralSuccess = (event) => {
        console.log('in handleEditReferralSuccess 1');
        console.log(`success event [${JSON.stringify(event.detail.fields.Status__c)}]`);

        // if we can dynamically display just the changed status, we can avoid reload of whole datatable
        /*for(var i=0; i<this.data.length; i++) {
            if(this.data[i].Id == this.recordId){
                console.log(`in handleEditReferralSuccess loop#${i}`);
                this.data[i].Status__c = event.detail.fields.Status__c.value;
            }
        }
        console.log(`precision status change in datatable [${JSON.stringify(this.data)}]`);
        */

        getAllReferrals()
        .then(result => {
            this.data = result;
            console.log(`back from getAllReferrals. result[${JSON.stringify(result)}]`);
            console.log(`refresh datatable after status update`);
        })
        .catch(error => {
            this.error = error;
            console.log(this.error);
        });
    }

    handleEditReferralError = (event) => {
        console.log('in handleEditReferralError 1');
        console.log(`error event [${JSON.stringify(event)}]`);
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