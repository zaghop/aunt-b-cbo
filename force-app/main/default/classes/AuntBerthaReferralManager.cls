public with sharing class AuntBerthaReferralManager {
        public AuntBerthaReferralManager() {}

        @AuraEnabled(cacheable=true)
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
        }
    

        @AuraEnabled(cacheable=true)
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
            return config;
        }

        @future (callout=true)
        public static void updateReferrals(){
            Map<String, String> config = new Map<String, String>();
            Map<String, ab_ref_mgr__c	> customSettings = ab_ref_mgr__c.getall();
            config.put('api_key', customSettings.get('api_key').Value__c);
            config.put('endpoint', customSettings.get('endpoint').Value__c);
            config.put('username', customSettings.get('username').Value__c);
            config.put('password', customSettings.get('password').Value__c);

            String tokenEnpoint = customSettings.get('endpoint').Value__c+'/v3/authenticate';
            String responseXML;

            Map<String, String> tokenData = new Map<String, String>();

            tokenData.put('username', customSettings.get('ab_username').Value__c);
            tokenData.put('password', customSettings.get('ab_password').Value__c);
            tokenData.put('api_key', customSettings.get('api_key').Value__c);

            String jsonBody = JSON.serialize(tokenData);

            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setTimeout(60000);
            req.setHeader('content-type', 'application/json;charset=UTF-8');
            req.setHeader('Content-Length', String.valueOf(jsonBody.length()));
            req.setEndpoint(tokenEnpoint);
            req.setBody(jsonBody);

            //Execute web service call here 
            if(!Test.isRunningTest()){
                Http http = new Http();
                HTTPResponse res = http.send(req);
                responseXML = res.getBody();
                JSONParser parser = JSON.createParser(responseXML);
                while (parser.nextToken() != null) {
                    if(parser.getText() == 'token'){
                        parser.nextToken();
                        queryRefs(parser.getText(), config);
                    }
                }
            }else{
                queryRefs('234234asdfasfasfasfasfasfasf', config);
            }
        }

        public static void queryRefs(String token, Map<String, String> config){
            String pastMonth = String.valueOf(date.today().addDays(-7).month());
            String pastDay = String.valueOf(date.today().addDays(-7).day());
            String pastYear = String.valueOf(date.today().addDays(-7).year());
            String pastDate = pastYear+'-'+pastMonth+'-'+pastDay;

            String month = String.valueOf(date.today().month());
            String day = String.valueOf(date.today().day());
            String year = String.valueOf(date.today().year());
            String todayDate = year+'-'+month+'-'+day;

            String endpoint =  config.get('endpoint')+'/v3/referrals/:search';
            String jsonString = '{"created_date":{"gte":"'+pastDate+'","lte":"'+todayDate+'"}}';
            String responseXML;

            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer '+token);
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(60000);
            req.setEndpoint(endpoint);

            // setting body
            req.setBody(jsonString);

            //Execute web service call here     
            Http http = new Http();

            if(!Test.isRunningTest()){
                HTTPResponse res = http.send(req);
                responseXML = res.getBody();
            }else{
                responseXML = '{"data":{"next_page":"Tm9uZSAxMA==","referrals":[{"status":"got help","needs_follow_up":false,"sender":{"first_name":"API","last_name":"User","id":"6160784024928256","email":"auntbertha-api@bridgeconnector.co"},"contact_preferances":["email","text"],"patient_id":"","application_key":"","program":{"provider_name":"Domestic Violence Program & Sexual Assault Services","id":"5658907303215104","name":"Emergency Shelter"},"receiver":{"phone_number":"6152933605","first_name":"QA","last_name":"Test","id":"5478118944407552","email":"chayes@bridgeconnector.co"},"date_created":"2019-10-30T15:49:57.186595","id":"1","sent":true},{"status":"referred elsewhere","needs_follow_up":false,"sender":{"first_name":"API","last_name":"User","id":"6160784024928256","email":"auntbertha-api@bridgeconnector.co"},"contact_preferances":["email","text"],"patient_id":"","application_key":"","program":{"provider_name":"YWCA of Nashville & Middle Tennessee ","id":"6749168041197568","name":"Weaver Domestic Violence Center"},"receiver":{"phone_number":"6152933605","first_name":"QA","last_name":"Test","id":"2","email":"chayes@bridgeconnector.co"},"date_created":"2019-10-30T15:50:34.777087","id":"2","sent":true},{"status":"referred elsewhere","needs_follow_up":false,"sender":{"first_name":"API","last_name":"User","id":"6160784024928256","email":"auntbertha-api@bridgeconnector.co"},"contact_preferances":["email","text"],"patient_id":"","application_key":"","program":{"provider_name":"YWCA of Nashville & Middle Tennessee ","id":"6749168041197568","name":"Weaver Domestic Violence Center"},"receiver":{"phone_number":"6152933605","first_name":"QA","last_name":"Test","id":"2","email":"chayes@bridgeconnector.co"},"date_created":"2019-10-30T15:50:34.777087","id":"3","sent":true},{"status":"referred elsewhere","needs_follow_up":false,"sender":{"first_name":"API","last_name":"User","id":"6160784024928256","email":"auntbertha-api@bridgeconnector.co"},"contact_preferances":["email","text"],"patient_id":"","application_key":"","program":{"provider_name":"YWCA of Nashville & Middle Tennessee ","id":"6749168041197568","name":"Weaver Domestic Violence Center"},"receiver":{"phone_number":"6152933605","first_name":"QA","last_name":"Test","id":"2","email":"chayes@bridgeconnector.co"},"date_created":"2019-10-30T15:50:34.777087","id":"4","sent":true},{"status":"needs action","needs_follow_up":false,"sender":{"first_name":"API","last_name":"User","id":"6160784024928256","email":"auntbertha-api@bridgeconnector.co"},"contact_preferances":["email","text"],"patient_id":"","application_key":"","program":{"provider_name":"YWCA of Nashville & Middle Tennessee ","id":"6749168041197568","name":"Weaver Domestic Violence Center"},"receiver":{"phone_number":"6152933605","first_name":"QA","last_name":"Test","id":"2","email":"chayes@bridgeconnector.co"},"date_created":"2019-10-30T15:50:34.777087","id":"5","sent":true},{"status":"no longer interested","needs_follow_up":false,"sender":{"first_name":"API","last_name":"User","id":"6160784024928256","email":"auntbertha-api@bridgeconnector.co"},"contact_preferances":["email","text"],"patient_id":"","application_key":"","program":{"provider_name":"YWCA of Nashville & Middle Tennessee ","id":"6749168041197568","name":"Weaver Domestic Violence Center"},"receiver":{"phone_number":"6152933605","first_name":"QA","last_name":"Test","id":"2","email":"chayes@bridgeconnector.co"},"date_created":"2019-10-30T15:50:34.777087","id":"6","sent":true}]},"success":true}';
            }

            Map<String, Object> refMap = (Map<String, Object>) JSON.deserializeUntyped(responseXML);
            Map<String, Object> refs = (Map<String, Object>) refMap.get('data');
            List<Object> refList = (List<Object>)refs.get('referrals');

            List<Map<String, Object>> newRefMaps = new List<Map<String, Object>>();

            for(Object ref:refList){
                newRefMaps.add((Map<String, Object>)ref);
            }

            List<Task> tasksToUpdate = new List<Task>();
            List<Case> casesToUpdate = new List<Case>();
            List<String> refIdList = new List<String>();

            for(Map<String, Object> refData:newRefMaps){
                String refId = String.valueOf(refData.get('id'));
                refIdList.add(refId);
            }

            List<Case> caseList = [SELECT Id, Referral_ID__c, Aunt_Bertha_Status__c, Description from Case Where Status != 'Completed' AND Referral_ID__c in: refIdList];
            List<Task> taskList = [SELECT Id, Referral_ID__c, Aunt_Bertha_Status__c, Description from Task Where Status != 'Closed' AND Referral_ID__c in: refIdList];
            

            Map<String, Case> caseMap = new Map<String, Case>();
            Map<String, Task> taskMap = new Map<String, Task>();

            for(Case singleCase:caseList){
                String refId = singleCase.Referral_ID__c;
                caseMap.put(refId, singleCase);
            }

            for(Task singleTask:taskList){
                String refId = singleTask.Referral_ID__c;
                taskMap.put(refId, singleTask);
            }

            for(Map<String, Object> refData:newRefMaps){
                Boolean isTask = false;
                Boolean isCase = false;
                Boolean hasChanged = false;

                String refId = String.valueOf(refData.get('id'));
                String status = String.valueOf(refData.get('status'));

                Case tmpCase = new Case();
                Task tmpTask = new Task();

                if(caseMap.containsKey(refId)){
                    isCase = true;
                    tmpCase = caseMap.get(refId);
                }

                if(taskMap.containsKey(refId)){
                    isTask = true;
                    tmpTask = taskMap.get(refId);
                }

                if(status == tmpTask.Aunt_Bertha_Status__c || status == tmpCase.Aunt_Bertha_Status__c || status == 'not yet'){
                    continue;
                }

                String taskDescription;
                String caseDescription;

                if(tmpTask.Description == null){
                    taskDescription = '';
                }else{
                    taskDescription = tmpTask.Description+'\r\n';
                }

                if(tmpCase.Description == null){
                    caseDescription = '';
                }else{
                    caseDescription = tmpCase.Description+'\r\n';
                }

                switch on status {
                    when 'couldn\'t get help' {
                        if(isTask){
                            tmpTask.Status = 'Completed';
                            tmpTask.Description = taskDescription+'The client could not receive help using this referral.';
                            tmpTask.Aunt_Bertha_Status__c = status;
                        }

                        if(isCase){
                            tmpCase.Status = 'Closed';
                            tmpCase.Description = caseDescription+'The client could not receive help using this referral.';
                            tmpCase.Aunt_Bertha_Status__c = status;
                        }

                        hasChanged = true;
                    }
                    when 'got help' {
                        if(isTask){
                            tmpTask.Status = 'Completed';
                            tmpTask.Description = taskDescription+'The client has received the required aid.';
                            tmpTask.Aunt_Bertha_Status__c = status;
                        }

                        if(isCase){
                            tmpCase.Status = 'Closed';
                            tmpCase.Description = caseDescription+'The client has received the required aid.';
                            tmpCase.Aunt_Bertha_Status__c = status;
                        }

                        hasChanged = true;
                    }
                    when 'needs action' {
                        if(isTask){
                            tmpTask.Status = 'Waiting on someone else';
                            tmpTask.Description = taskDescription+'Further action is required.';
                            tmpTask.Aunt_Bertha_Status__c = status;
                        }

                        if(isCase){
                            tmpCase.Status = 'Escalated';
                            tmpCase.Description = caseDescription+'Further action is required.';
                            tmpCase.Aunt_Bertha_Status__c = status;
                        }

                        hasChanged = true;
                    }
                    when 'no longer interested' {
                        if(isTask){
                            tmpTask.Status = 'Completed';
                            tmpTask.Description = taskDescription+'The client is no longer interested in this service.';
                            tmpTask.Aunt_Bertha_Status__c = status;
                        }

                        if(isCase){
                            tmpCase.Status = 'Closed';
                            tmpCase.Description = caseDescription+'The client is no longer interested in this service.';
                            tmpCase.Aunt_Bertha_Status__c = status;
                        }

                        hasChanged = true;
                    }
                    when 'referred elsewhere' {
                        if(isTask){
                            tmpTask.Status = 'Completed';
                            tmpTask.Description = taskDescription+'The client has been referred elsewhere.';
                            tmpTask.Aunt_Bertha_Status__c = status;
                        }

                        if(isCase){
                            tmpCase.Status = 'Closed';
                            tmpCase.Description = caseDescription+'The client has been referred elsewhere.';
                            tmpCase.Aunt_Bertha_Status__c = status;
                        }

                        hasChanged = true;
                    }
                    when else{
                        if(isTask){
                            tmpTask.Description = taskDescription+'New Status:'+status+'.';
                            tmpTask.Aunt_Bertha_Status__c = status;
                        }

                        if(isCase){
                            tmpCase.Description = caseDescription+'New Status:'+status+'.';
                            tmpCase.Aunt_Bertha_Status__c = status;
                        }

                        hasChanged = true;
                    }
                }

                if(hasChanged){
                    if(isTask){
                        tasksToUpdate.add(tmpTask);
                    }

                    if(isCase){
                        casesToUpdate.add(tmpCase);
                    }
                }
            }

            if(tasksToUpdate.size() > 0){
                update tasksToUpdate;
            }

            if(casesToUpdate.size() > 0){
                update casesToUpdate;
            }
        }
}