public with sharing class ReferralController
{
    @AuraEnabled(cacheable=true)
    public static List<Referral__c> findReferrals(String searchKey) {
        String key = '%' + searchKey + '%';
        return [
            SELECT Id, Name, Sender_Username__c
            FROM Referral__c
            WHERE Name LIKE :key
            WITH SECURITY_ENFORCED
            LIMIT 10
        ];
    }

    @AuraEnabled
    public static Referral__c getSingleReferral(Id rId) {
 
        System.debug('from main record: rId [' + rId + ']');

        return [
            SELECT Id, Name, Sender_Username__c, Receiver_First_Name__c, Receiver_Last_Name__c, Receiver_Email__c,
            		Receiver_Phone_Number__c, Status__c, Comment__c, Contact_Preferences__c
            FROM Referral__c where Id = :rId
        ];
    }

}