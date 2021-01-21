import { LightningElement, track, wire, api } from 'lwc';
import AB_LOGO from '@salesforce/resourceUrl/AuntBerthaLogo';

export default class AuntBerthaReferralManagerAuth extends LightningElement {
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
        if(this.selectedStep == 'options')
            return false;
        return true;
    }

    next = () => {
        if(this.selectedStep == 'creds'){
            this.selectedStep = 'import';
        }else if(this.selectedStep == 'import') this.selectedStep = 'options';
    }
    
    back = () => {
        if(this.selectedStep == 'options'){
            this.selectedStep = 'import';
        } else if(this.selectedStep == 'import') this.selectedStep = 'creds';
    }

    //OPTIONS PANE
    optionsValue = [];

    get optionOptions() {
        return [
            { label: 'Allow manual input', value: 'allow_manual' },
            { label: 'Refresh referral statuses on app load', value: 'refresh_load' }
        ];
    }

    get selectedOptionsValues() {
        return this.optionsValue.join(',');
    }

    handleOptionsChange(e) {
        this.optionsValue = e.detail.value;
    }

    intervalValue = '1';

    get intervalOptions() {
        return [
            { label: 'Once a day', value: '1' },
            { label: 'Twice a day', value: '2' },
            { label: 'Three times a day', value: '3' },
            { label: 'Four times a day', value: '4' }
        ];
    }

    handleIntervalChange(event) {
        this.intervalValue = event.detail.value;
    }

    //IMPORT PANE
    importValue = [];

    get importOptions() {
        return [
            { label: 'Retrieve all referrals on install', value: 'allow_manual' },
            { label: 'Retrieve closed referrals', value: 'import_closed' }
        ];
    }

    get selectedImportValues() {
        return this.importValue.join(',');
    }

    handleImportChange(e) {
        this.importValue = e.detail.value;
    }
}