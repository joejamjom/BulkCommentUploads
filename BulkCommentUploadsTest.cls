/**
 * @group BulkCommentUploadsTest
 * @description This is a builder class for Bulk comment uploads tool
 */
@isTest private class BulkCommentUploadsTest {
  private
   static final Id HELPDESKCASERTID =
       Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
           .get(Label.Helpdesk_Case_Record_Type_Name)
           .getRecordTypeId();
  private
   static final Id SALESSUPPORTCASERTID =
       Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
           .get(Label.Support_Case_Sales_Record_Type_Name)
           .getRecordTypeId();
  private
   static final string TEST_CLASS_NAME = HelpdeskCaseRdttest.class.getName();
  private
   static final string HELPDESK_TEST_CASE_NAME =
       TEST_CLASS_NAME + 'TEST HELPDESK CASE';
  private
   static final string SALES_SUPPORT_TEST_CASE_NAME =
       TEST_CLASS_NAME + 'TEST SALESSUPPORT CASE';
  private
   static final string TEST_CORP_ENG_PROFILE = 'Corp Eng Base';
  private
   static final string PROD_SUPP_SYSTEMS_USERNAME =
       TEST_CLASS_NAME + '_ProdSuppSystemsUser@google.com.gcv';
  private
   static final string PROD_SUPP_SYSTEMS_JOB_FUNCTION =
       'Prod Support Systems Team';
   static User adminUser = TestUserUtility.getAdminUser();
   /*
    * @description setupData()
    */
   @TestSetup static void setupData() {
     System.runAs(adminUser) {
       List<Case> caseList = new List<Case>();
       Profile corpEngBase =
           TestProfileBuilder.getProfileRecord(TEST_CORP_ENG_PROFILE);
       User prdSuppUser = new TestUserBuilder()
                              .setProfileId(corpEngBase.Id)
                              .setUsername(PROD_SUPP_SYSTEMS_USERNAME)
                              .setJobFunction(PROD_SUPP_SYSTEMS_JOB_FUNCTION)
                              .buildAndSave();
       Case caseObjTechIssue =
           new TestCaseBuilder()
               .setRecordType(HELPDESKCASERTID)
               .setCaseSubject(HELPDESK_TEST_CASE_NAME)
               .setIssueType(Label.Helpdesk_Issue_Type_PS_Technical_Issue)
               .setType(System.Label.Helpdesk_Issue_Type_PS_Technical_Issue)
               .build();
       caseList.add(caseObjTechIssue);
       Case salesSupportCase = new TestCaseBuilder()
                                   .setRecordType(SALESSUPPORTCASERTID)
                                   .setCaseSubject(SALES_SUPPORT_TEST_CASE_NAME)
                                   .build();
       caseList.add(salesSupportCase);
       insert caseList;
     }
   }
   /**
    * @description Method to test inserting a valid post with mention
    */
  private
   @IsTest static void insertCommentNoError() {
     Case testCase = TestCaseUtility.queryCaseBy(HELPDESK_TEST_CASE_NAME);
     User testUser =
         TestUserUtility.getUserByUsername(PROD_SUPP_SYSTEMS_USERNAME);
     ContentVersion contentVersion1 = createcontentVersion(
         'insertCommentNoError',
         'Case Number,Comment,LDAPS' + '\n' + testCase.CaseNumber +
             ',This is a test comment,' + testUser.LDAP__C);
     Id docID = getDocumentID(contentVersion1);
     Test.StartTest();
     BulkCommentUploads.resultClass wc = new BulkCommentUploads.resultClass();
     list<BulkCommentUploads.wrapperClass> successRecords =
         new list<BulkCommentUploads.wrapperClass>();
     list<BulkCommentUploads.wrapperClass> failedRecords =
         new list<BulkCommentUploads.wrapperClass>();
     wc = BulkCommentUploads.processData(docID);
     successRecords = wc.successRecords;
     failedRecords = wc.failedRecords;
     Test.StopTest();
     // clang-format off
     List<feeditem> feedItemList = new List<feeditem>([
       SELECT
         id,
         body
       FROM
         feeditem
       WHERE
         parentid =:testCase.id
       ]);
     // clang-format on
     System.assertEquals(1, feedItemList.size(), 'Comments were not inserted');
   }
   /**
    *  @description Method to test inserting a not valid post with mention
    */
  private
   @IsTest static void insertCommentError() {
     Case testCase = TestCaseUtility.queryCaseBy(HELPDESK_TEST_CASE_NAME);
     User testUser =
         TestUserUtility.getUserByUsername(PROD_SUPP_SYSTEMS_USERNAME);
     ContentVersion contentVersion1 = createcontentVersion(
         'insertCommentError', 'Case Number,Comment,LDAPS' + '\n' +
                '' + ',This is a test comment,' + testUser.LDAP__C);
     Id docID = getDocumentID(contentVersion1);
     Test.StartTest();
     BulkCommentUploads.resultClass wc = new BulkCommentUploads.resultClass();
     list<BulkCommentUploads.wrapperClass> successRecords =
         new list<BulkCommentUploads.wrapperClass>();
     list<BulkCommentUploads.wrapperClass> failedRecords =
         new list<BulkCommentUploads.wrapperClass>();
     wc = BulkCommentUploads.processData(docID);
     successRecords = wc.successRecords;
     failedRecords = wc.failedRecords;
     Test.StopTest();
     System.assertEquals(1, failedRecords.size(), 'Failed list is empty');
   }
   /**
    *  @description Method to test inserting a Sales Support case
    */
  private
   @IsTest static void insertSalesSupportCase() {
     Case testCase = TestCaseUtility.queryCaseBy(SALES_SUPPORT_TEST_CASE_NAME);
     User testUser =
         TestUserUtility.getUserByUsername(PROD_SUPP_SYSTEMS_USERNAME);
     ContentVersion contentVersion1 = createcontentVersion(
         'insertSalesSupportCase',
         'Case Number,Comment,LDAPS' + '\n' + testCase.CaseNumber +
             ',This is a test comment,' + testUser.LDAP__C);
     Id docID = getDocumentID(contentVersion1);
     Test.StartTest();
     BulkCommentUploads.resultClass wc = new BulkCommentUploads.resultClass();
     list<BulkCommentUploads.wrapperClass> successRecords =
         new list<BulkCommentUploads.wrapperClass>();
     list<BulkCommentUploads.wrapperClass> failedRecords =
         new list<BulkCommentUploads.wrapperClass>();
     wc = BulkCommentUploads.processData(docID);
     successRecords = wc.successRecords;
     failedRecords = wc.failedRecords;
     Test.StopTest();
     System.assertEquals(
         'Record type must be Cloud Helpdesk' + '\r\n' +
             'Issue type must be Technical, Access, Data or Other',
         failedRecords[0].status,
         'Sales support case is not supposed to be updated');
   }
   /**
    *  @description Method to return Document ID
    */
  private
   static Id getDocumentID(ContentVersion contVersion) {
     // clang-format off
     Id docID = [
       SELECT
         Id,
         Title,
         ContentDocumentId
       FROM
         ContentVersion
       WHERE
         Id =:contVersion.Id LIMIT 1
       ].ContentDocumentId;
     // clang-format on
     return docID;
   }
   /**
    * @description Method to Create content Version
    * @return contentVersionObj
    */
  private
   static ContentVersion createcontentVersion(String docTitle, String body) {
     ContentVersion contentVersionObj = new ContentVersion(
         Title = docTitle, PathOnClient = docTitle + '.csv',
         VersionData = Blob.valueOf(body), IsMajorVersion = true);
     insert contentVersionObj;
     return contentVersionObj;
   }
 }
