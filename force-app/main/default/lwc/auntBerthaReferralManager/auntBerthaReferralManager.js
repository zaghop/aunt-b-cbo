import { LightningElement, api } from 'lwc';

export default class AuntBerthaReferralManager extends LightningElement {
    @api showSettings;

    openSettings = () => {
        this.showSettings = true;
    }

    closeSettings = () => {
        this.showSettings = false;
    }
}