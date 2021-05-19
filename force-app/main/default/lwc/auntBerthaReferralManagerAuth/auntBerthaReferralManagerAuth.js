import { LightningElement, track, wire, api } from 'lwc';
import AB_LOGO from '@salesforce/resourceUrl/AuntBerthaLogo';
import saveCreds from "@salesforce/apex/AuntBerthaReferralManager.saveCreds";
import saveOptions from "@salesforce/apex/AuntBerthaReferralManager.saveOptions";
import getSettings from "@salesforce/apex/AuntBerthaReferralManager.getSettings";
import getImportingSetting from "@salesforce/apex/AuntBerthaReferralManager.getCurrentImportingSetting";
import updateImportingSetting from "@salesforce/apex/AuntBerthaReferralManager.updateCS_importing_referral_records";
import importReferralRecordsWithABSearch from "@salesforce/apex/AuntBerthaReferralManager.importReferralRecordsWithABSearch";
import postToChatter from '@salesforce/apex/AuntBerthaReferralManager.postToChatter';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// for inter-component communication
// Import message service features required for publishing and the message channel
import { publish, MessageContext } from 'lightning/messageService';
import ReferralImportCompleted from '@salesforce/messageChannel/Referral_Import_Completed__c';



export default class AuntBerthaReferralManagerAuth extends LightningElement {
    settings = {};
    @api selectedStep;
    @api theSpinner;
    @api currentlyImportingRefs;

    abLogo = AB_LOGO;

    constructor(){
        super();
        this.selectedStep = 'creds';
      }

    connectedCallback(){
        console.log('here');
        getSettings().then(result => {
            this.intervalValue = result.update_interval;
            this.settings['interval'] = this.intervalValue;

            if( !result.get_closed || result.get_closed.toUpperCase() === 'FALSE'){
                this.importClosed = null;
                this.settings['import_closed'] = 'false';
            }
            else{
                this.importClosed = result.get_closed;
                this.settings['import_closed'] = this.importClosed;
            }

            console.log(`settings. intervalValue[${this.intervalValue}], importClosed[${result.get_closed}][${this.importClosed}]`);
        });
    }

    closeSettings = () => {
        console.log('close settts');
        this.dispatchEvent(new CustomEvent('closesettings'));
    }

    //Progress Indicator
    get stepCreds(){
        if(this.selectedStep == 'creds')
            return true;
        return false;
    }

    get stepImport(){
        if(this.selectedStep == 'import')
            return true;
        return false;
    }

    get stepOptions(){
        if(this.selectedStep == 'options')
            return true;
        return false;
    }

    get stepProgress(){
        if(this.selectedStep == 'progress')
            return true;

        // get current value of custom setting importing_referral_records
        getImportingSetting().then(result => {
            if(result.importing_referral_records){
                this.currentlyImportingRefs = true;
            }
            else{
                this.currentlyImportingRefs = false;
            }
        });

        return false;
    }

    selectSettingsStep = (event) => {
        this.selectedStep = event.target.value;
    }

    //NEXT/PREV BUTTONS
    get showBack(){
        if(this.selectedStep == 'creds')
            return false;
        return true;
    }
    
    get showNext(){
        if(this.selectedStep == 'progress')
            return false;
        return true;
    }

    next = () => {
        if(this.selectedStep == 'creds'){
            this.selectedStep = 'import';
        }else if(this.selectedStep == 'import'){
            this.selectedStep = 'progress';
        }
    }
    
    back = () => {
        if(this.selectedStep == 'progress'){
            this.selectedStep = 'import';
        }else if(this.selectedStep == 'import'){
            this.selectedStep = 'creds';
        }
    }

    //OPTIONS PANE
    intervalValue = '1';

    get intervalOptions(){
        return [
            { label: 'Once a day', value: '1' },
            { label: 'Twice a day', value: '2' },
            { label: 'Three times a day', value: '3' },
            { label: 'Four times a day', value: '4' }
        ];
    }

    //IMPORT PANE
    importValue = [];
    confirmImport = false;

    get importOptions() {
        return [
            { label: 'Retrieve closed referrals', value: 'import_closed' }
        ];
    }

    get selectedImportValues() {
        return this.importValue.join(',');
    }

    get showConfirm() {
        if(this.confirmImport)
            return true;
        return false;
    }

    get showSpinner(){
        return this.theSpinner;
    }

    get currentlyImportingReferralRecords(){
        return this.currentlyImportingRefs;
    }

    @wire(MessageContext)
    messageContext;

    startImport = (e) => {
        console.log('in startImport 1');

        console.log('spin it 1');
        this.theSpinner = true;

        this.currentlyImportingRefs = true;
        updateImportingSetting({ type: 'start' });

        this.confirmImport = false;     // toggle (close) the window

        importReferralRecordsWithABSearch()
        .then( func =>{
            console.log('now post to chatter');
            postToChatter();

            this.currentlyImportingRefs = false;
            updateImportingSetting({ type: 'stop' });

            const evt_e = new ShowToastEvent({
                title: "Success",
                message: 'Import has completed',
                variant: "success"
            });
            this.dispatchEvent(evt_e);
            console.log('show toast: completed');

            // send LMS message to component 'auntBerthaCBO': (to refresh that component's datatable)
            const payload = { myMsg: 'importCompleted' };
            publish(this.messageContext, ReferralImportCompleted, payload);
            console.log('after publish');
        })
        .catch(error => {
            if ( error.body.message) {
                const evt_e = new ShowToastEvent({
                    title: "Error",
                    message: error.body.message,
                    variant: "error"
                });
                this.dispatchEvent(evt_e);
            }
            this.theSpinner = false;
            console.log('spinner stopped after error');
        });

        //console.log('show toast: scheduled');
        /*const evt_e = new ShowToastEvent({
            title: "Success",
            message: 'Import has been scheduled',
            variant: "success"
        });
        this.dispatchEvent(evt_e);*/

        this.theSpinner = false;
        console.log('spinner stopped 1');

        

    }

    toggleImportConfirm(e) {
        console.log('toggle');
        if(this.confirmImport){
            this.confirmImport = false;
        }else{
            this.confirmImport = true;
        }
    }

    handleImportChange(e) {
        this.importValue = e.detail.value;
    }

    //USER INTERACTION
    handleInputChange = (event) => {
        console.log('input');
        let currentSetting = event.target.dataset.name;
        if(currentSetting == 'get_closed'){
            this.settings[currentSetting] = event.target.checked;
        }else{
            this.settings[currentSetting] = event.target.value;
        }
        console.log(this.settings);
    }

    handleIntervalChange(event) {
        console.log('intervalsssss');
        this.settings['interval'] = event.detail.value;
        console.log(this.settings);
    }

    //APEX CALLS
    startSaveCreds = (event) => {
        console.log('save creds');
        this.theSpinner = true;
        const creds = {
            'username': this.settings.username,
            'password': this.settings.password,
            'api_key': this.settings.api_key
        };
        this.postData('https://api.auntberthaqa.com/v3/authenticate', creds )
        .then(data => {
            console.log('success',data); // JSON data parsed by `data.json()` call
            this.theSpinner = false;
            if(data.success){
                saveCreds({
                    settings: creds
                  })
                    .then(result => {
                        console.log('saved',result);
                        const evt = new ShowToastEvent({
                            title: 'Credentials Saved',
                            message: 'Your Aunt Bertha credentials have been confirmed and saved',
                            variant: 'success',
                        });
                        this.dispatchEvent(evt);
                    });
            }else{
                console.log('error');
                const evt = new ShowToastEvent({
                    title: 'Credentials Failed',
                    message: 'Your Aunt Bertha credentials are invalid',
                    variant: 'error',
                });
                this.dispatchEvent(evt);
            }
        });

        return;
        
        
    }

    saveOptions = (event) => {
        console.log('save options', this.settings);
        const options = { 'get_closed' : this.settings.get_closed,
                           'update_interval': this.settings.interval}
        
        saveOptions({
            settings: options
          })
            .then(result => {
                console.log('saved',result);

                getSettings().then(result => {
                    this.intervalValue = result.update_interval;
        
                    if( ! result.get_closed || result.get_closed.toUpperCase() === 'FALSE'){
                        this.importClosed = null;
                    }
                    else{
                        this.importClosed = result.get_closed;
                    }
        
                    console.log(`settings. intervalValue[${this.intervalValue}], importClosed[${result.get_closed}][${this.importClosed}]`);

                    const evt = new ShowToastEvent({
                        title: 'Options Saved',
                        message: 'Your Aunt Bertha import options have been saved',
                        variant: 'success'
                    });
                this.dispatchEvent(evt);
                });
        
            })
            .catch(e => {
                console.log('error saving', e);
            });
    }

    postData = async (url = '', data = {}) => {
        // Default options are marked with *
        const response = await fetch(url, {
            method: 'POST',
            mode: 'cors', // no-cors, *cors, same-origin
            cache: 'no-cache', // *default, no-cache, reload, force-cache, only-if-cached
            headers: {
                'Content-Type': 'application/json'
            },
            redirect: 'follow',
            referrerPolicy: 'no-referrer',
            body: JSON.stringify(data)
        });
        return response.json();
    }

}