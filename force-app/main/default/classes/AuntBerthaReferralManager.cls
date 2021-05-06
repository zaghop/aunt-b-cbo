public with sharing class AuntBerthaReferralManager {
        public AuntBerthaReferralManager() {}

        /*@AuraEnabled(cacheable=true)
        public static Account getAccount(String contactId){
            Account account = new Account();
            if(Schema.sObjectType.Account.fields.Name.isAccessible() &&
                Schema.sObjectType.Account.fields.Id.isAccessible() &&
                Schema.sObjectType.Contact.fields.Email.isAccessible() &&
                Schema.sObjectType.Account.fields.Phone.isAccessible() &&
                Schema.sObjectType.Account.fields.BillingPostalCode.isAccessible()){
                    account = [SELECT Id, Name, Phone, BillingPostalCode, (Select Email from Contacts LIMIT 1) FROM Account WHERE Id =: contactId LIMIT 1];
            }
            return account;
        }*/
    

        @AuraEnabled
        public static Map<String, String> getSettings(){
            Map<String, String> config = new Map<String, String>();

            Map<String, ab_ref_mgr__c> customSettings = ab_ref_mgr__c.getall();

            config.put('api_key', customSettings.get('api_key').Value__c);
            config.put('endpoint', customSettings.get('endpoint').Value__c);
            config.put('username', customSettings.get('username').Value__c);
            config.put('password', customSettings.get('password').Value__c);
            config.put('get_closed', customSettings.get('get_closed').Value__c);
            config.put('update_interval', customSettings.get('update_interval').Value__c);
            Id id1 = UserInfo.getProfileId();

            List<Profile> profile = [Select Name from Profile where Id =: id1 LIMIT 1];

            if(profile[0].Name == 'System Administrator'){
                config.put('profile', 'admin');
            }else{
                config.put('profile', 'user');
            }

            return config;  
        }


        @AuraEnabled        //(cacheable=true) don't want cacheable for this one
        public static Map<String, String> getCurrentImportingSetting(){
            Map<String, String> config = new Map<String, String>();
            ab_ref_mgr__c obj = ab_ref_mgr__c.getvalues('importing_referral_records');

            config.put('importing_referral_records', obj.value__c);

            system.debug('got new config [' + obj.value__c + ']');

            return config;  
        }

        @AuraEnabled
        public static Map<String, String> saveCreds(Map<String,String> settings){

            system.debug('SAVE CREDS');

            Map<String, ab_ref_mgr__c> customSettings = ab_ref_mgr__c.getall();

            List<ab_ref_mgr__c> lstSettings = new List<ab_ref_mgr__c>();

            if(customSettings.size() == 0 || Test.isRunningTest()){
                lstSettings.add(new ab_ref_mgr__c (Name='username'));
                lstSettings.add(new ab_ref_mgr__c (Name='password'));
                lstSettings.add(new ab_ref_mgr__c (Name='endpoint'));
                lstSettings.add(new ab_ref_mgr__c (Name='api_key'));
                insert lstSettings;
                customSettings = ab_ref_mgr__c.getAll();
            }

            for (String name : settings.keySet()) {
                String settingId = customSettings.get(name).Id;
                String settingValue = settings.get(name);

                update new ab_ref_mgr__c(
                    Id = settingId,
                    Value__c = settingValue
                );
            }

            Map<String, String> config = new Map<String, String>();
            Map<String, ab_ref_mgr__c> newSettings = ab_ref_mgr__c.getall();
            config.put('api_key', newSettings.get('api_key').Value__c);
            config.put('endpoint', newSettings.get('endpoint').Value__c);
            config.put('username', newSettings.get('username').Value__c);
            config.put('password', newSettings.get('password').Value__c);
            return config;  
        }

        @AuraEnabled
        public static Map<String, String> saveOptions(Map<String,String> settings){

            Map<String, ab_ref_mgr__c> customSettings = ab_ref_mgr__c.getall();

            system.debug('CUSTOM SETTING'+customSettings);

            List<ab_ref_mgr__c> lstSettings = new List<ab_ref_mgr__c>();

            if(customSettings.size() == 0 || Test.isRunningTest()){
                lstSettings.add(new ab_ref_mgr__c (Name='get_closed'));
                lstSettings.add(new ab_ref_mgr__c (Name='update_interval'));
                insert lstSettings;
                customSettings = ab_ref_mgr__c.getAll();
            }

            for (String name : settings.keySet()) {
                String settingId = customSettings.get(name).Id;
                String settingValue = settings.get(name);

                update new ab_ref_mgr__c(
                    Id = settingId,
                    Value__c = settingValue
                );
            }

            Map<String, String> config = new Map<String, String>();
            Map<String, ab_ref_mgr__c> newSettings = ab_ref_mgr__c.getall();
            config.put('get_closed', newSettings.get('get_closed').Value__c);
            config.put('update_interval', newSettings.get('update_interval').Value__c);

            // remove any old values from CronTrigger.
            String jobName = 'AuntBertha Referral Import';
            List<CronTrigger> oldCT_list  = [select Id, CronJobDetail.Name from CronTrigger where CronJobDetail.Name = :jobName];
            for(CronTrigger ct : oldCT_list){
                System.abortjob(ct.Id);
                system.debug('will abort job with id['+ ct.Id +']');
            }

            // insert new records
            Integer dailyUpdateCount = Integer.valueOf(config.get('update_interval'));
            system.debug('new dailyUpdateCount is ['+ dailyUpdateCount +']');
            if(dailyUpdateCount == 1){
                // 4am
                System.schedule(jobName, '0 0 4 * * ?', new auntBerthaPeriodicReferralImport());
            }
            else if(dailyUpdateCount == 2){
                // 4am, 12pm
                System.schedule(jobName, '0 0 4,12 * * ?', new auntBerthaPeriodicReferralImport());
            }
            else if(dailyUpdateCount == 3){
                // 4am, 12pm, 3pm
                System.schedule(jobName, '0 0 4,12,15 * * ?', new auntBerthaPeriodicReferralImport());
            }
            else if(dailyUpdateCount == 4){
                // 4am, 12pm, 3pm, 6pm
                System.schedule(jobName, '0 0 4,12,15,18 * * ?', new auntBerthaPeriodicReferralImport());
            }
            else{
                // default at least once at 4am
                System.schedule(jobName, '0 0 4 * * ?', new auntBerthaPeriodicReferralImport());
            }

            return config;
        }

        @AuraEnabled
        @future (callout=true)
        public static void importReferralRecordsWithABSearch(){

            Map<String, String> ABtoken = auntBerthaCBO.getABEndpointAuthToken();

            if(ABtoken != null){

                String endpoint =  ABtoken.get('endpoint')+'/v3/referrals/:search';
    
                String responseJSN;

                HttpRequest req = new HttpRequest();
                req.setMethod('POST');
                req.setHeader('Authorization', 'Bearer '+ABtoken.get('token'));
                req.setHeader('Content-Type', 'application/json');
                req.setTimeout(60000);
                req.setEndpoint(endpoint);

                /*Integer xDaysAgo = -17;     // negative for past days
                String pastMonth = String.valueOf(date.today().addDays(xDaysAgo).month());
                String pastDay = String.valueOf(date.today().addDays(xDaysAgo).day());
                String pastYear = String.valueOf(date.today().addDays(xDaysAgo).year());
                String pastDate = pastYear+'-'+pastMonth+'-'+pastDay;
    
                String tomorrowMonth = String.valueOf(date.today().addDays(1).month());
                String tomorrowDay = String.valueOf(date.today().addDays(1).day());
                String tomorrowYear = String.valueOf(date.today().addDays(1).year());
                String tomorrowDate = tomorrowYear+'-'+tomorrowMonth+'-'+tomorrowDay;
                // notice api call needs updated_date, but returned object has date_updated
                String jsonString = '{"updated_date":{"gte":"'+pastDate+'","lte":"'+tomorrowDate+'"}';*/  // incomplete

                ab_ref_mgr__c ref_mgr_obj = ab_ref_mgr__c.getvalues('get_closed');
                Boolean getClosed = false;
                if(ref_mgr_obj.value__c.equalsIgnoreCase('true')){
                    getClosed = true;
                }

                String jsonString = '';
                String str_nextPage = '';

                List<Referral__c> realRefList = new List<Referral__c>();

                do{
                    Map<String, Object> parmsObj = new Map<String, Object>();

                    if(getClosed){
                        parmsObj.put('needs_follow_up', false);
                        // add more parameters here if needed
                    }
                    if(!String.isBlank(str_nextPage)){
                        parmsObj.put('next_page', str_nextPage);
                    }

                    jsonString = JSON.Serialize(parmsObj);
                                        
                    req.setBody(jsonString);

                    system.debug('call jsonString ['+jsonString+']');

                    if(!Test.isRunningTest()){
                        try{

                            Http http = new Http();
                            HTTPResponse res = http.send(req);

                            //sleep(20 * 1000);   // seconds

                            responseJSN = res.getBody();
                            //system.debug('response from endpoint ['+responseJSN+']');

                            Map<String, Object> ABresponseMap = (Map<String, Object>) JSON.deserializeUntyped(responseJSN);

                            Map<String, Object> ABresponseData = (Map<String, Object>) ABresponseMap.get('data');

                            List<Object> ABrefObjList = (List<Object>)ABresponseData.get('referrals');
                            system.debug('['+ABrefObjList.size()+'] referrals were received from endpoint');

                            for(Object ABrefObj: ABrefObjList){
                                Map<String, Object> ABref = (Map<String, Object>)ABrefObj;
                                system.debug('Id is ['+ABref.get('id')+']');

                                Map<String, Object> ABresp_program = (Map<String, Object>)ABref.get('program');
                                Map<String, Object> ABresp_receiver = (Map<String, Object>)ABref.get('receiver');

                                Referral__c realRef = new Referral__c();
                                realRef.Referral_ID__c = (String)ABref.get('id');
                                realRef.Program__c = (String)ABresp_program.get('id');
                                //realRef.Sender_Username__c = (String)ABref.get('sender_username');
                                realRef.Receiver_Email__c = (String)ABresp_receiver.get('email');
                                realRef.Receiver_First_Name__c = (String)ABresp_receiver.get('first_name');
                                realRef.Receiver_Last_Name__c = (String)ABresp_receiver.get('last_name');
                                realRef.Receiver_Phone_Number__c = (String)ABresp_receiver.get('phone_number');
                                realRef.Status__c = (String)ABref.get('status');
                                realRef.Comment__c = (String)ABref.get('comment');

                                List<Object> cp_values = (List<Object>)ABref.get('contact_preferences');
                                if(cp_values != null){
                                    realRef.Contact_Preferences__c = String.join(cp_values, ';');
                                }
                                else{
                                    realRef.Contact_Preferences__c = '';
                                }

                                realRef.Name = (String)ABresp_receiver.get('first_name') + ' ' + (String)ABresp_receiver.get('last_name');
                                realRef.Needs_Follow_Up__c = (Boolean)ABref.get('needs_follow_up');
                                realRefList.add(realRef);

                                system.debug('added referral__c to list ['+realRef+']');
                            }

                            str_nextPage = (String) ABresponseData.get('next_page');
                            if(!String.isBlank(str_nextPage)){
                                system.debug('will call for next_page ['+str_nextPage+']');
                            }
                        }
                        catch (Exception e) {
                            if(System.isScheduled()){
                                system.debug(LoggingLevel.ERROR, 'Exception: ['+e.getMessage()+']');
                                throw e;
                            }
                            else {
                                throw new AuraHandledException(e.getMessage());
                            }
                        }
                    }
                    else{
                    System.debug('Do something for test');
                    }
                }
                while(! String.isBlank(str_nextPage));

                Integer newRecordsCount = 0;
                Integer updateRecordsCount = 0;
                Integer failedRecordsCount = 0;

                if(realRefList.size() > 0){
                    system.debug('upserting ['+realRefList.size()+'] records');
                    
                    Database.UpsertResult[] results = Database.upsert(realRefList, Referral__c.Referral_ID__c);
                    for(Integer i = 0; i < results.size(); i++) {
                        if(results[i].isSuccess()) {
                            if(results[i].isCreated()) {
                                newRecordsCount++;
                            } else {
                                updateRecordsCount++;
                            }
                        } else {
                            failedRecordsCount++;
                        }
                    }
                }
                System.debug('New records added ['+ newRecordsCount +']');
                System.debug('Existing records updated ['+ updateRecordsCount +']');
                System.debug('Failed to process ['+ failedRecordsCount +']');
            }
        }


        // used for testing. Don't use in production
        /*private static void sleep(integer milliseconds) 
        {
            Long timeDiff = 0;
            DateTime firstTime = System.now();
            do
            {
                timeDiff = System.now().getTime() - firstTime.getTime();
            }
            while(timeDiff <= milliseconds);      
        }*/

        @AuraEnabled
        public static void updateCS_importing_referral_records(String type){
            // need this routine in a seperate method because can't do DML before @future method in importAllRefsFromAB()

            system.debug('in method updateCS_importing_referral_records. [' + type + ']');

            // put current timestamp in custom setting importing_referral_records
            ab_ref_mgr__c ref_mgr_obj = ab_ref_mgr__c.getvalues('importing_referral_records');

            if(type.equals('start') && String.isBlank(ref_mgr_obj.value__c)){
                ref_mgr_obj.value__c = Datetime.now().format('yyyy-MM-dd HH:mm:ss');
                system.debug('upserting this timestamp [' + ref_mgr_obj.value__c + ']');
                upsert ref_mgr_obj;
            }
            else if(type.equals('stop') && ! String.isBlank(ref_mgr_obj.value__c)){
                ref_mgr_obj.value__c = null;
                system.debug('setting importing_referral_records to null');
                upsert ref_mgr_obj;
            }
            else if(type.equals('stop')){
                throw new AuraHandledException('Stop not allowed. Previous timestamp ' + ref_mgr_obj.value__c);
            }
            else if(type.equals('start')){
                throw new AuraHandledException('Import currently running. Started timestamp ' + ref_mgr_obj.value__c);
            }
            else {
                throw new AuraHandledException('Unknown parameter encountered [' + type + ']. Timestamp ' + ref_mgr_obj.value__c);
            }
        }


        @AuraEnabled
        @future (callout=true)
        public static void getAllRefsFromAB(){

            Map<String, String> ABtoken = auntBerthaCBO.getABEndpointAuthToken();

            if(ABtoken != null){

                List<Referral__c> realRefList = new List<Referral__c>();
    
                String responseJSN;
                String ABnextPage = '';

                Integer pageLimit = 5000;
                Integer runningOffset = 0;

                do{
                    String endpoint =  ABtoken.get('endpoint')+'/v3/referrals?limit='+pageLimit;
                    HttpRequest req = new HttpRequest();
                    req.setMethod('GET');
                    req.setHeader('Authorization', 'Bearer '+ABtoken.get('token'));
                    req.setHeader('Content-Type', 'application/json');
                    req.setTimeout(60000);
                    req.setEndpoint(endpoint);

                    if(! String.isBlank(ABnextPage)){
                        endpoint += '&offset='+runningOffset;
                    }

                    system.debug('Full endpoint ['+endpoint+']');

                    if(!Test.isRunningTest()){
                        try{

                            Http http = new Http();
                            HttpRequest empty_req = new HttpRequest();

                            HTTPResponse res = http.send(req);
                            responseJSN = res.getBody();
                            system.debug('response from endpoint ['+responseJSN+']');

                            //if(responseJSN)
                            Map<String, Object> ABresponseMap = (Map<String, Object>) JSON.deserializeUntyped(responseJSN);

                            Map<String, Object> ABresponseData = (Map<String, Object>) ABresponseMap.get('data');

                            List<Object> ABrefObjList = (List<Object>)ABresponseData.get('referrals');
                            system.debug('['+ABrefObjList.size()+'] referrals were received from endpoint');

                
                            for(Object ABrefObj: ABrefObjList){
                                Map<String, Object> ABref = (Map<String, Object>)ABrefObj;
                                system.debug('Id is ['+ABref.get('id')+']');

                                Map<String, Object> ABresp_program = (Map<String, Object>)ABref.get('program');
                                Map<String, Object> ABresp_receiver = (Map<String, Object>)ABref.get('receiver');

                                Referral__c realRef = new Referral__c();
                                realRef.Referral_ID__c = (String)ABref.get('id');
                                realRef.Program__c = (String)ABresp_program.get('id');
                                //realRef.Sender_Username__c = (String)ABref.get('sender_username');
                                realRef.Receiver_Email__c = (String)ABresp_receiver.get('email');
                                realRef.Receiver_First_Name__c = (String)ABresp_receiver.get('first_name');
                                realRef.Receiver_Last_Name__c = (String)ABresp_receiver.get('last_name');
                                realRef.Receiver_Phone_Number__c = (String)ABresp_receiver.get('phone_number');
                                realRef.Status__c = (String)ABref.get('status');
                                realRef.Comment__c = (String)ABref.get('comment');

                                List<Object> cp_values = (List<Object>)ABref.get('contact_preferences');
                                if(cp_values != null){
                                    realRef.Contact_Preferences__c = String.join(cp_values, ';');
                                }
                                else{
                                    realRef.Contact_Preferences__c = '';
                                }

                                realRef.Name = (String)ABresp_receiver.get('first_name') + ' ' + (String)ABresp_receiver.get('last_name');
                                realRef.Needs_Follow_Up__c = (Boolean)ABref.get('needs_follow_up');
                                realRefList.add(realRef);

                                system.debug('added referral__c to list ['+realRef+']');
                            }

                            ABnextPage = (String) ABresponseData.get('next_page');
                            if(! String.isBlank(ABnextPage)){
                                runningOffset += pageLimit;
                                system.debug('will call for next_page ['+ABnextPage+']');
                            }

                        }
                        catch (Exception e) {
                            if(System.isScheduled()){
                                system.debug(LoggingLevel.ERROR, 'Exception: ['+e.getMessage()+']');
                                throw e;
                            }
                            else {
                                throw new AuraHandledException(e.getMessage());
                            }
                        }
                    }else{
                        System.debug('Do something for test');
                    }
                }
                while(! String.isBlank(ABnextPage));

                Integer newRecordsCount = 0;
                Integer updateRecordsCount = 0;
                Integer failedRecordsCount = 0;

                if(realRefList.size() > 0){
                    system.debug('upserting ['+realRefList.size()+'] records');

                    Database.UpsertResult[] results = Database.upsert(realRefList, Referral__c.Referral_ID__c);
                    for(Integer i = 0; i < results.size(); i++) {
                        if(results[i].isSuccess()) {
                            if(results[i].isCreated()) {
                                newRecordsCount++;
                            } else {
                                updateRecordsCount++;
                            }
                        } else {
                            failedRecordsCount++;
                        }
                    }
                }
                System.debug('New records added ['+ newRecordsCount +']');
                System.debug('Existing records updated ['+ updateRecordsCount +']');
                System.debug('Failed to process ['+ failedRecordsCount +']');

            }
            System.debug('End of function');
        }
        
        @AuraEnabled
        public static void postToChatter(){
            try {

                // post message to chatter
                FeedItem post = new FeedItem();
                post.ParentId = userInfo.getUserId();
                post.Body = 'Aunt Bertha referrals import completed.';
                /*\nNew records added: '+ newRecordsCount +
                                '\nExisting records updated: '+ updateRecordsCount +
                                '\nFailed to process: '+ failedRecordsCount +'\n\n';*/
                insert post;
                
                System.debug('Posted to chatter');
            } catch (Exception e) {
                if(System.isScheduled()){
                    system.debug(LoggingLevel.ERROR, 'Exception: ['+e.getMessage()+']');
                }
                else {
                    throw new AuraHandledException(e.getMessage());
                }
            }
        }
}