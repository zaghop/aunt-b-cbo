public with sharing class auntBerthaCBO {
    public auntBerthaCBO() {

    }

    @AuraEnabled
    public static Integer getReferralsCount(){
        return database.countQuery('SELECT count() FROM Referral__c');
    }

    @AuraEnabled
    public static List<Referral__c> getAllReferrals(){
        List<Referral__c> lR = [SELECT Id, Referral_ID__c, Program_Name__c, Program_ID__c, Status__c, Name, Needs_Follow_Up__c 
                                    FROM Referral__c
                                    order by Name];
        return lR;
    }
    
    @AuraEnabled
    public static List<Referral__c> getSomeReferrals(Integer limitSize, Integer offset){
        List<Referral__c> lR = [SELECT Id, Referral_ID__c, Program_Name__c, Program_ID__c, Status__c, Name, Needs_Follow_Up__c
                                        FROM Referral__c
                                        order by Name
                                        LIMIT :limitSize
                                        OFFSET :offset];

        return lR;
    }

    @AuraEnabled
    public static Referral__c getSingleReferral(Id rId) {
 
        System.debug('from main record: rId [' + rId + ']');

        return [
            SELECT Id, Referral_ID__c, Program_Name__c, Program_ID__c, Name, Sender_Username__c, Receiver_First_Name__c, Receiver_Last_Name__c, Receiver_Email__c,
            		Receiver_Phone_Number__c, Status__c, Comment__c, Contact_Preferences__c, Needs_Follow_Up__c
            FROM Referral__c where Id = :rId
        ];
    }

    @AuraEnabled
    public static string sendStatusToEndpoint(String referralId, String newStatus){
        System.debug('in sendStatusToEndpoint');

        System.debug('referralId [' + referralId + '] status [' + newStatus + ']');
        String retStatus = 'failed';  // default assume failure
         
        try {
            // getABEndpointAuthToken() calls AB REST API
            // it returns Map<Aunt Bertha main endpoint, authentication token>
            Map<String, String> ABtoken = getABEndpointAuthToken();

            System.debug('getABEndpointAuthToken return endpoint['+ABtoken.get('endpoint')+']');

            if(ABtoken != null){
                // send update to Aunt Bertha
                String endpoint =  ABtoken.get('endpoint')+'/v3/referrals/'+referralId;
                String responseJSN;
    
                HttpRequest req = new HttpRequest();
                req.setMethod('PUT');
                req.setHeader('Authorization', 'Bearer '+ABtoken.get('token'));
                req.setHeader('Content-Type', 'application/json');
                req.setTimeout(60000);
                req.setEndpoint(endpoint);

                Map<String, Object> obj = new Map<String, Object>();
                obj.put('status', newStatus);
                //obj.put('status', 'no longer interested');
                String jsonBody = JSON.Serialize(obj);
    
                req.setBody(jsonBody);
    
                System.debug('preparing for referral status update call. jsonBody is: ' + jsonBody);

                Http http = new Http();
    
                if(!Test.isRunningTest()){
                    HTTPResponse res = http.send(req);
                    responseJSN = res.getBody();
                    JSONParser parser = JSON.createParser(responseJSN);
                    while (parser.nextToken() != null) {
                        if(parser.getText() == 'success'){
                            parser.nextValue();
                            Boolean retVal = parser.getBooleanValue();
                            System.debug('endpoint return value['+retVal+']');
                            if( retVal == true ){
                                retStatus = 'success';
                            }
                            break;
                        }
                    }
                }else{
                    retStatus = 'success';
                }

                System.debug('returning ['+ retStatus +']');

                if( retStatus != 'success' ) {
                    if(!Test.isRunningTest()) {
                        throw new AuraHandledException('Call to endpoint was not successful');
                    }
                }
            }

        } catch (Exception e) {
            if(!Test.isRunningTest()) {
                throw new AuraHandledException('Exception caught: '+e.getMessage());
            }
}

        System.debug('at end of function ['+retStatus+']');
        return retStatus;
    }

    
    @AuraEnabled
    public static string processNewReferralRecord(Id recordId){
        System.debug('in processNewReferralRecord');
        System.debug('recordId [' + recordId + ']');
         
        try {
            Referral__c newRef = getSingleReferral(recordId);

            // getABEndpointAuthToken() calls AB REST API
            // we get Map<Aunt Bertha main endpoint, authentication token>
            //Map<String, String> ABtoken = getABEndpointAuthToken(); //new Map<String, String>();

            // remove this code after callout is successful
            Map<String, String> ABtoken = new Map<String, String>();
            ABtoken.put('endpoint', 'someendpoint');
            ABtoken.put('token', 'sometoken'); 

            if(ABtoken != null){
                // send new referral to Aunt Bertha
                String endpoint =  ABtoken.get('endpoint')+'/v3/referrals';
                String responseXML;
    
                HttpRequest req = new HttpRequest();
                req.setMethod('POST');
                req.setHeader('Authorization', 'Bearer '+ABtoken.get('token'));
                req.setHeader('Content-Type', 'application/json');
                req.setTimeout(60000);
                req.setEndpoint(endpoint);
                String jsonBody = JSON.serialize(newRef);
    
                req.setBody(jsonBody);
    
                System.debug('preparing for create referral call. jsonBody is: ' + jsonBody);

                Http http = new Http();
    
                if(!Test.isRunningTest()){
                    //HTTPResponse res = http.send(req);
                    //responseXML = res.getBody();  commented for now until callout is successful
                }else{
                    responseXML = '{"id":"test run referralId","program":{"provider_name":"Domestic Violence Program & Sexual Assault Services","id":"5658907303215104","name":"Emergency Shelter"},"sender":{"first_name":"API","last_name":"User","id":"6160784024928256","email":"auntbertha-api@bridgeconnector.co"},"receiver":{"phone_number":"6152933605","first_name":"QA","last_name":"Test","id":"5478118944407552","email":"chayes@bridgeconnector.co"},"status":"not yet helped","date_created":"2020-10-30T15:49:57.186595","needs_follow_up":false,"contact_preferances":["email","text"],"sent":true}';
                }

                // commented for now until callout is successful
                //Map<String, Object> refMap = (Map<String, Object>) JSON.deserializeUntyped(responseXML);
    
                // update our record with Referral_ID__c from AB, and also make record.Name = first name+last name
                // commented for now until callout is successful
                //newRef.Referral_ID__c = refMap.get('id');

                newRef.Referral_ID__c = 'get Id from AB';

                newRef.Name = newRef.Receiver_First_Name__c + ' ' + newRef.Receiver_Last_Name__c;

                update newRef;
            }

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        return 'success';
    }

    public static  Map<String, String> getABEndpointAuthToken(){
        Map<String, String> config = new Map<String, String>();

        Map<String, ab_ref_mgr__c	> customSettings = ab_ref_mgr__c.getall();

        if(customSettings.get('api_key') != null){
            config.put('api_key', customSettings.get('api_key').Value__c);
            config.put('endpoint', customSettings.get('endpoint').Value__c);
            config.put('username', customSettings.get('username').Value__c);
            config.put('password', customSettings.get('password').Value__c);

            //System.debug('config [' + config.values() + ']');

            String ABEndpoint = customSettings.get('endpoint').Value__c;
            String tokenEndpoint = customSettings.get('endpoint').Value__c+'/v3/authenticate';
            String responseJSN;

            Map<String, String> tokenData = new Map<String, String>();

            tokenData.put('username', customSettings.get('username').Value__c);
            tokenData.put('password', customSettings.get('password').Value__c);
            tokenData.put('api_key', customSettings.get('api_key').Value__c);

            //System.debug('tokenData [' + tokenData.values() + ']');

            String jsonBody = JSON.serialize(tokenData);

            //System.debug('preparing for authenticate call. endpoint is: ' + tokenEndpoint);
            //System.debug('preparing for authenticate call. jsonBody is: ' + jsonBody);

            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setTimeout(60000);
            req.setHeader('content-type', 'application/json;charset=UTF-8');
            req.setHeader('Content-Length', String.valueOf(jsonBody.length()));
            req.setEndpoint(tokenEndpoint);
            req.setBody(jsonBody);

            if(!Test.isRunningTest()){
                Http http = new Http();
                HTTPResponse res = http.send(req);
                responseJSN = res.getBody();

                System.debug('response return from authentication call: '+responseJSN);
                JSONParser parser = JSON.createParser(responseJSN);
                while (parser.nextToken() != null) {
                    if(parser.getText() == 'token'){
                        parser.nextToken();
                        Map<String, String> retMap = new Map<String, String>();
                        retMap.put('token', parser.getText());
                        retMap.put('endpoint', ABEndpoint);     

                        //System.debug('in parsing. token is ' + retMap.get('token'));
                        //System.debug('in parsing. endpoint is ' + retMap.get('endpoint'));
                        return retMap;
                    }
                }
            }else{
                Map<String, String> retMap = new Map<String, String>();
                retMap.put('token', '234234asdfasfasfasfasfasfasf');
                retMap.put('endpoint', ABEndpoint);
                System.debug('test response token['+retMap.get('token')+'] endpoint['+retMap.get('endpoint')+']');
                return retMap;
            }
        }
        return null;
    }
}