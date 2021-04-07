import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import REFERRAL_OBJECT from '@salesforce/schema/Referral__c';
import NAME_FIELD from '@salesforce/schema/Referral__c.Name';
import STATUS_FIELD from '@salesforce/schema/Referral__c.Status__c';

export default class ViewReferral extends LightningElement {
    objectApiName = REFERRAL_OBJECT;
    fields = [NAME_FIELD, STATUS_FIELD];
    handleSuccess(event) {
        const toastEvent = new ShowToastEvent({
            title: "Account created",
            message: "Record ID: " + event.detail.id,
            variant: "success"
        });
        this.dispatchEvent(toastEvent);
    }
}