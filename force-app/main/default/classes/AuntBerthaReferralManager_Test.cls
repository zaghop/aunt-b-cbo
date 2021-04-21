@isTest
public with sharing class AuntBerthaReferralManager_Test {
    public AuntBerthaReferralManager_Test() {

    }

    @TestSetup
    static void makeData(){

        List<ab_ref_mgr__c> settingsL = new List<ab_ref_mgr__c>();

        ab_ref_mgr__c s = new ab_ref_mgr__c();
        s.Name = 'api_key';
        s.Value__c = 'this is a non existent api key for testing';
        settingsL.add(s);

        s = new ab_ref_mgr__c();
        s.Name = 'endpoint';
        s.Value__c = 'https://this.doesnt.exist.com';
        settingsL.add(s);

        s = new ab_ref_mgr__c();
        s.Name = 'username';
        s.Value__c = 'unknown_user_name';
        settingsL.add(s);

        s = new ab_ref_mgr__c();
        s.Name = 'password';
        s.Value__c = 'thisisnotapassword';
        settingsL.add(s);

        insert settingsL;
        
    }


    /*@isTest
    static void testGetAccount(){
        //getAccount(String contactId)
    }*/

    @isTest
    static void testGetSettings(){
        //getSettings();
    }
        
    @isTest
    static void testSaveCreds(){
    //saveCreds(Map<String,String> settings)
    }
            
    @isTest
    static void testSaveOptions(){
        //saveOptions(Map<String,String> settings)
    }
                
    @isTest
    static void testUpdateReferralRecordsFromAB(){
            //updateReferralRecordsFromAB(String nextPage)
    }
}
