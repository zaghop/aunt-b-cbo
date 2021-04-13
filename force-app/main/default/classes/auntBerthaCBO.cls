public with sharing class auntBerthaCBO
{
    public auntBerthaCBO() {

    }

    @AuraEnabled
    public static List<Referral__c> getAllReferrals(){
        List<Referral__c> lR = [SELECT Id, Referral_ID__c, Program__c, Status__c, Name, Needs_Follow_Up__c FROM Referral__c];
        return lR;
    }

    @AuraEnabled
    public static Referral__c getSingleReferral(Id rId) {
 
        System.debug('from main record: rId [' + rId + ']');

        return [
            SELECT Id, Referral_ID__c, Program__c, Name, Sender_Username__c, Receiver_First_Name__c, Receiver_Last_Name__c, Receiver_Email__c,
            		Receiver_Phone_Number__c, Status__c, Comment__c, Contact_Preferences__c, Needs_Follow_Up__c
            FROM Referral__c where Id = :rId
        ];
    }

    @AuraEnabled
    public static string sendStatusToEndpoint(String referralId, String newStatus){
        System.debug('in sendStatusToEndpoint');

        System.debug('referralId [' + referralId + '] status [' + newStatus + ']');
         
        /*try {

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }*/

        return 'success';
    }

}