public with sharing class AuntBerthaUtils {
    public AuntBerthaUtils() {}

    @AuraEnabled(cacheable=true)
    public static void updateImportDate(Datetime importTime){
        Map<String, ab_ref_mgr__c> customSettings = ab_ref_mgr__c.getall();

        String settingId = customSettings.get('last_update').Id;
        String settingValue = String.valueOf(importTime);

        update new ab_ref_mgr__c(
            Id = settingId,
            Value__c = settingValue
        );
    }
}
