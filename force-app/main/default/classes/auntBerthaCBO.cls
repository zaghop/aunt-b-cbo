public with sharing class auntBerthaCBO {
    public auntBerthaCBO() {

    }

    @AuraEnabled
    public static List<Referral__c> getAllReferrals(){
        List<Referral__c> lR = [SELECT Id, Referral_ID__c, Program__c, Status__c, Name, Needs_Follow_Up__c FROM Referral__c];
        return lR;
    }
}
