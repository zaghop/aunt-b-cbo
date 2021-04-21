@isTest
public with sharing class auntBerthaCBO_Test {
    public auntBerthaCBO_Test() {

        //Id singleRecordId = [SELECT DurableId FROM EntityDefinition WHERE QualifiedApiName = 'Referral__c'];
    }

    @TestSetup
    static void makeData(){
        List<Referral__c> listR = new List<Referral__c>();

        for(Integer i=0; i<10;i++){
            Referral__c nr= new Referral__c();
            nr.name='test ref'+i;
            nr.Status__c='not yet helped';
            listR.add(nr);
        }

        insert listR;


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

    @isTest
    static void testGetAllReferrals(){
        Test.startTest();
        List<Referral__c> refL = auntBerthaCBO.getAllReferrals();
        Test.stopTest();

        System.assertEquals(10, refL.size(), 'Should match count of referrals created in testSetup');
            
    }

    @isTest static void testGetSingleReferral(){
        Referral__c getOneFirst = [select Id, Name, Status__c from Referral__c limit 1];

        Test.startTest();
        Referral__c getAgain = auntBerthaCBO.getSingleReferral(getOneFirst.Id);
        Test.stopTest();

        System.assertEquals(getOneFirst.Id, getAgain.Id, 'Record Id are not matching');
    }

    @isTest
    static void testSendStatusToEndpoint(){
        Referral__c getOneRecord = [select Id, Name, Status__c from Referral__c limit 1];
        getOneRecord.Status__c = 'no longer interested';

        Test.startTest();
        String retMsg = auntBerthaCBO.sendStatusToEndpoint(getOneRecord.Id, getOneRecord.Status__c);
        Test.stopTest();

        System.assertEquals('success', retMsg, 'Unexpected message received');
    }

}
