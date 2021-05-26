public with sharing class AuntBerthaReferralManager {

        public final static String ABEndpointURL = 'https://api.auntberthaqa.com';     // have to change this when deploying to prod

        public AuntBerthaReferralManager() {}

        @AuraEnabled
        public static Map<String, String> getSettings(){
            Map<String, String> config = new Map<String, String>();

            Map<String, ab_ref_mgr__c> customSettings = ab_ref_mgr__c.getall();

            if(customSettings.size() > 0)
            {
                if(customSettings.get('api_key') != null){
                    config.put('api_key', customSettings.get('api_key').Value__c);
                    config.put('endpoint', customSettings.get('endpoint').Value__c);
                    config.put('username', customSettings.get('username').Value__c);
                    config.put('password', customSettings.get('password').Value__c);
                    config.put('importing_referral_records', customSettings.get('importing_referral_records').Value__c);
                }
                else {
                    // we are not likely to encounter this situation
                    system.debug('Custom settings has some values, but api_key was undefined. Why is this unlikely scenario happening?');
                    config.put('api_key', 'undefined');
                    config.put('endpoint', ABEndpointURL);
                    config.put('username', 'undefined');
                    config.put('password', 'undefined');
                    config.put('importing_referral_records', '');
                }

                // these could still be undefined, even when api_key and usernames have already been entered.
                if(customSettings.get('update_interval') != null){
                    config.put('update_interval', customSettings.get('update_interval').Value__c);
                    config.put('get_closed', customSettings.get('get_closed').Value__c);
                }
                else{
                    config.put('update_interval', '1');
                    config.put('get_closed', 'false');
                }
            }
            else {
                system.debug('First time, settings are undefined. size [' + customSettings.size() + ']');
                config.put('api_key', 'undefined');
                config.put('endpoint', ABEndpointURL);
                config.put('username', 'undefined');
                config.put('password', 'undefined');
                config.put('update_interval', '1');
                config.put('get_closed', 'false');
                config.put('importing_referral_records', '');
            }

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

            if(obj != null && obj.value__c != null)
            {
                config.put('importing_referral_records', obj.value__c);

                system.debug('got new config [' + obj.value__c + ']');
            }
            else {
                config.put('importing_referral_records', '');
            }

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
                lstSettings.add(new ab_ref_mgr__c (Name='api_key'));
                lstSettings.add(new ab_ref_mgr__c (Name='endpoint', Value__c = ABEndpointURL));
                lstSettings.add(new ab_ref_mgr__c (Name='importing_referral_records'));     // timestamp or null
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
            config.put('username', newSettings.get('username').Value__c);
            config.put('password', newSettings.get('password').Value__c);
            config.put('api_key', newSettings.get('api_key').Value__c);
            config.put('endpoint', newSettings.get('endpoint').Value__c);
            config.put('importing_referral_records', newSettings.get('importing_referral_records').Value__c);
            return config;  
        }

        @AuraEnabled
        public static Map<String, String> saveOptions(Map<String,String> settings){

            Map<String, ab_ref_mgr__c> customSettings = ab_ref_mgr__c.getall();

            system.debug('CUSTOM SETTING'+customSettings);

            List<ab_ref_mgr__c> lstSettings = new List<ab_ref_mgr__c>();

            if(customSettings.get('get_closed') == null || Test.isRunningTest()){
                lstSettings.add(new ab_ref_mgr__c (Name='get_closed', value__c = 'false'));
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
                system.debug('update. ' + customSettings.get(name) + ': [' + settingValue + ']');
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

                String endpoint =  ABtoken.get('endpoint')+'/v3/referrals/';
    
                String responseJSN;

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
                    jsonString = JSON.Serialize(parmsObj);                                        

                    HttpRequest req = new HttpRequest();
                    req.setHeader('Authorization', 'Bearer '+ABtoken.get('token'));
                    req.setHeader('Content-Type', 'application/json');
                    req.setTimeout(60000);
                    if(String.isBlank(str_nextPage)){
        
                        req.setMethod('POST');
                        req.setEndpoint(endpoint+':search');

                        req.setBody(jsonString);
                        system.debug('call jsonString ['+jsonString+']');
                    }
                    else{
                        req.setMethod('GET');
                        req.setEndpoint(endpoint+'?next_page='+str_nextPage);
                        system.debug('next_page request ['+req+']');
                    }


                    if(!Test.isRunningTest()){
                        try{

                            Http http = new Http();
                            HTTPResponse res = http.send(req);

                            //sleep(20 * 1000);   // seconds

                            responseJSN = res.getBody();
                            //system.debug('response from endpoint ['+responseJSN+']');

                            Map<String, Object> ABresponseMap = (Map<String, Object>) JSON.deserializeUntyped(responseJSN);

                            if((Boolean)ABresponseMap.get('success') == true){
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
                                    realRef.Program_ID__c = (String)ABresp_program.get('id');
                                    realRef.Program_Name__c = (String)ABresp_program.get('name');
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
                            else {
                                String m = (String)ABresponseMap.get('error');
                                system.debug('Endpoint response was unexpected: ' + m);

                                if(System.isScheduled()){
                                    system.debug('throw new CalloutException for scheduled job');
                                    
                                    CalloutException e = new CalloutException(m);
                                    e.setMessage(m);
                                    throw e;
                                }
                                else {
                                    system.debug('throw new aurahandledException for UI');

                                    AuraHandledException e = new AuraHandledException(m);
                                    e.setMessage(m);
                                    throw e;
                                }
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

                system.debug('call function to upsert and delete');
                upsertThenDeleteOldRecords(realRefList);
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

                //Integer pageLimit = 50;
                //Integer runningOffset = 0;

                do{
                    // during QA, it was discovered that limit and offset parameters as described in API document,
                    // didn't have any significance for API response.
                    //String endpoint =  ABtoken.get('endpoint')+'/v3/referrals?limit='+pageLimit;
                    String endpoint =  ABtoken.get('endpoint')+'/v3/referrals';
                    HttpRequest req = new HttpRequest();
                    req.setMethod('GET');
                    req.setHeader('Authorization', 'Bearer '+ABtoken.get('token'));
                    req.setHeader('Content-Type', 'application/json');
                    req.setTimeout(60000);      // default 10 seconds wasn't enough

                    if(String.isBlank(ABnextPage)){
                        req.setEndpoint(endpoint);
                    }
                    else{
                        req.setEndpoint(endpoint + '?next_page='+ABnextPage);
                    }

                    system.debug('Full endpoint ['+endpoint+']');

                    if(!Test.isRunningTest()){
                        try{

                            Http http = new Http();
                            HttpRequest empty_req = new HttpRequest();

                            system.debug('making callout now');
                            HTTPResponse res = http.send(req);
                            responseJSN = res.getBody();
                            system.debug('response from endpoint ['+responseJSN+']');

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
                                realRef.Program_ID__c = (String)ABresp_program.get('id');
                                realRef.Program_Name__c = (String)ABresp_program.get('name');
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
                                //runningOffset += pageLimit;
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

                if(realRefList.size() > 0){
                    system.debug('call function to upsert and delete');
                    upsertThenDeleteOldRecords(realRefList);
                }
            }
            System.debug('End of function');
        }

        public static void upsertThenDeleteOldRecords(List<Referral__c> newRefList){
            system.debug('upserting ['+newRefList.size()+'] records');

            Integer newRecordsCount = 0;
            Integer updateRecordsCount = 0;
            Integer failedRecordsCount = 0;

            try{
                Database.UpsertResult[] results = Database.upsert(newRefList, Referral__c.Referral_ID__c);
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
                System.debug('New records added ['+ newRecordsCount +']');
                System.debug('Existing records updated ['+ updateRecordsCount +']');
                System.debug('Failed to process ['+ failedRecordsCount +']');

                // delete local copies of records that aren't in AB anymore
                delete [ SELECT Id FROM Referral__c WHERE Id not in :newReflist ];
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