import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getSingleReferral from '@salesforce/apex/ReferralController.getSingleReferral';

export default class AuntBerthaReferralManagerEditReferral extends NavigationMixin(LightningElement) {
    referral;
    error;
    message;
    @api recordId;

    connectedCallback() {
		this.loadReferral();
	}
	loadReferral() {
		getSingleReferral({ rId: this.recordId } )
			.then(result => {
                this.referral = result;
                this.error = undefined;
			})
			.catch(error => {
				this.error = 'Unknown error';
                if (Array.isArray(error.body)) {
                    this.error = error.body.map(e => e.message).join(', ');
                } else if (typeof error.body.message === 'string') {
                    this.error = error.body.message;
                }
                this.referral = undefined;
			});
    } 
}
