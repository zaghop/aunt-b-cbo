public with sharing class auntBerthaPeriodicReferralImport implements Schedulable{
    public auntBerthaPeriodicReferralImport() {

    }

    public void execute (SchedulableContext ctx) {
        //System.debug('I am running as scheduled');

        try {
            AuntBerthaReferralManager.importReferralRecordsWithABSearch();

            // post message to chatter
            FeedItem post = new FeedItem();
            post.ParentId = userInfo.getUserId();
            post.Body = 'Aunt Bertha referrals daily scheduled import job completed.';
            insert post;
        }
        catch (Exception e) {
            throw e;   
        }
    }
}
