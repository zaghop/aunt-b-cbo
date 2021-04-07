public class ReferralController
{
    @AuraEnabled(cacheable=true)
    public static List<Referral__c> findReferrals(String searchKey) {
        String key = '%' + searchKey + '%';
        return [
            SELECT Id, Program_Id__c, Sender_Username__c
            FROM Referral__c
            WHERE Program_Id__c LIKE :key AND Sender_Username__c != NULL
            WITH SECURITY_ENFORCED
            LIMIT 10
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Referral__c getSingleReferral() {
        return [
            SELECT Id, Program_Id__c, Sender_Username__c, Receiver_First_Name__c, Receiver_Last_Name__c, Receiver_Email__c,
            		Receiver_Phone_Number__c, Status__c
            FROM Referral__c
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
    }

}