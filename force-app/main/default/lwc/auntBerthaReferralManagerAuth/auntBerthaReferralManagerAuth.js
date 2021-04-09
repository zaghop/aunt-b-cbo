import { LightningElement, track, wire, api } from 'lwc';
import AB_LOGO from '@salesforce/resourceUrl/AuntBerthaLogo';
import saveCreds from "@salesforce/apex/AuntBerthaReferralManager.saveCreds";
import getSettings from "@salesforce/apex/AuntBerthaReferralManager.getSettings";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AuntBerthaReferralManagerAuth extends LightningElement {
    settings = {};
    @api selectedStep;

    abLogo = AB_LOGO;

    constructor(){
        super();
        this.selectedStep = 'creds';
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

    startImport(e) {
        console.log('start');
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
        const creds = {
            'username': this.settings.username,
            'password': this.settings.password,
            'api_key': this.settings.api_key
        };
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
    }

    saveOptions = (event) => {
        console.log('save options');
        const evt = new ShowToastEvent({
            title: 'Options Saved',
            message: 'Your Aunt Bertha import options have been saved',
            variant: 'success',
        });
        this.dispatchEvent(evt);
    }
    

}