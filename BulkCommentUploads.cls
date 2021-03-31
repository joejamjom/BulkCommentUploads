/**
 * @description  an implementation of Bulk post uploads lightning web
 * componenet that handles a list of cases posts uploaded and
 * inserted based on case number
 */
public
with sharing class BulkCommentUploads {
  public
  static String fileData;
  public
  static Map<String, wrapperClass> objectsMap = new Map<String, wrapperClass>();
  public
  static List<String> inputvalues = new List<String>();
  public
  static Map<String, wrapperClass> wrongValues = new Map<String, wrapperClass>();
  public
  static resultClass resultClassObject = new resultClass();
  public
  static wrapperClass wrapperClassObject = new wrapperClass();
  public
  static String errorMessage = '';
  public
  static Map<String, Id> casesNumbers = new Map<String, Id>();
  public
  static Map<String, String> casesComments = new Map<String, String>();
  public
  static Map<String, String> casesLdaps = new Map<String, String>();
  public
  static List<ConnectApi.BatchInput> batchInputs = new List<ConnectApi.BatchInput>();
  /**
   * @description Method that validates and sorts cases in doc
   * @param uploaded document id
   * @return An object of resultClass that contain all cases and posts lists
   */
  @AuraEnabled public static resultClass processData(id idContentDocument) {
    if (idContentDocument == null) {
      exitWithErrorMsg('Document ID not found');
    }
    ContentVersion conDoc;
    try {
      // clang-format off
      conDoc = [
        SELECT
          id,
          versionData
        FROM
          ContentVersion
        WHERE
          ContentDocumentId =:idContentDocument
          AND IsLatest = true
        WITH
          SECURITY_ENFORCED limit 1
          ];
      // clang-format on
    } catch (exception err) {
      exitWithErrorMsg('conDoc select exception ' + err);
    }
    if (conDoc == null) {
      exitWithErrorMsg('File not found');
    }
    fileData = conDoc.VersionData.toString() + '\r\n' + 'end,end,end;end';
    if (fileData != null) {
      List<String> fileLines = new List<String>();
      List<String> fileLdaps = new List<String>();
      fileData = replaceCommasAndNewLinesInComments(fileData, '\n', ':newLine:');
      fileLines = fileData.split('\n');
      if (fileLines.size() < 3) {
        exitWithErrorMsg('File is empty');
      }
      fileLines.remove(0);
      // for content
      for (String fL : fileLines) {
        fL = fL.replaceAll(':quotes:', '"').replaceAll(':newLine:', '\n');
        fL = replaceCommasAndNewLinesInComments(fL, ',', ':comma:');
        inputvalues = fL.split(',');
        wrapperClassObject = createWrapperClassObject(inputvalues[0],
            inputvalues[1].replaceAll(':quotes:', '').replaceAll(':comma:', ','),
            inputvalues.size() > 2
                ? inputvalues[2].replaceAll(':quotes:', '').replaceAll(':comma:', ',')
                : null);
        fileLdaps = wrapperClassObject.ldapsList;
        if (String.isBlank(wrapperClassObject.caseNumber) || wrapperClassObject.caseNumber == null
            || String.isBlank(wrapperClassObject.comment) || wrapperClassObject.comment == null) {
          wrapperClassObject.status = 'Case number and comment cannot be empty';
          wrongValues.put(wrapperClassObject.caseNumber, wrapperClassObject);
        } else if (wrapperClassObject.status != null
            || !String.isBlank(wrapperClassObject.status)) {
          wrongValues.put(wrapperClassObject.caseNumber, wrapperClassObject);
        } else if (inputvalues.size() > 3
            && (inputvalues[2] != null || !String.isBlank(inputvalues[2]))) {
          exitWithErrorMsg('Sheet should only have 3 columns\r\n CaseNumber, Comment, LDAPs');
        } else {
          objectsMap.put(wrapperClassObject.caseNumber, wrapperClassObject);
          casesNumbers.put(wrapperClassObject.caseNumber, null);
          casesComments.put(wrapperClassObject.caseNumber, wrapperClassObject.comment);
          if (fileLdaps != null) {
            for (String ss : fileLdaps) {
              casesLdaps.put(ss, null);
            }
          }
        }
      }
    }
    setCaseIds();
    setUsersIds();
    formComment();
    resultClassObject = createResultClassObject();
    return resultClassObject;
  }
  /**
   * @description Method to validate cases record type and issue type
   * and sets cases ids
   */
  Public static void setCaseIds() {
    List<case> cases = new List<case>();
    if (casesNumbers.size() > 0) {
      // clang-format off
      cases = [
        SELECT
          Id,
          casenumber,
          CreatedById,
          RecordType.name,
          Issue_Type__c
        FROM
          case
        WHERE
          casenumber in:casesNumbers.keySet()
        WITH
          SECURITY_ENFORCED
        ];
      // clang-format on
      for (case cs : cases) {
        if (cs.RecordType.name != System.Label.Cloud_Helpdesk_RecordType
            || (cs.Issue_Type__c != Label.Helpdesk_Issue_Type_PS_Technical_Issue
                && cs.Issue_Type__c != Label.Helpdesk_Issue_Type_PS_Access_Issue
                && cs.Issue_Type__c != Label.Helpdesk_Issue_Type_Data_Issue
                && cs.Issue_Type__c != Label.Helpdesk_Issue_Type_PS_Other)) {
          wrapperClass obj = objectsMap.get(cs.casenumber);
          obj.status = 'Record type must be Cloud Helpdesk' + '\r\n'
              + 'Issue type must be Technical, Access, Data or Other';
          wrongValues.put(cs.casenumber, obj);
          objectsMap.remove(cs.casenumber);
        } else {
          casesNumbers.remove(cs.casenumber);
          casesNumbers.put(cs.casenumber, cs.Id);
          setCommentHeader(cs.casenumber, cs.CreatedById);
        }
      }
    }
  }
  /**
   * @description Method to post header
   * @param String caseNumber
   * @return String case creatorId
   */
  Public static void setCommentHeader(String caseNumber, String creatorId) {
    String header = 'Hello @{' + creatorId + '},\n';
    String comment = header + casesComments.get(caseNumber);
    casesComments.remove(caseNumber);
    casesComments.put(caseNumber, comment);
  }
  /**
   * @description Method to validate users records
   * and sets users ids
   */
  Public static void setUsersIds() {
    List<user> users = new List<user>();
    if (casesLdaps.size() > 0) {
    // clang-format off
      users = [
        SELECT
          Id,
          LDAP__c
        FROM
          user
        WHERE
          LDAP__c in:casesLdaps.keySet()
        WITH
          SECURITY_ENFORCED
        ];
    // clang-format on
      for (user us : users) {
        casesLdaps.remove(us.LDAP__c);
        casesLdaps.put(us.LDAP__c, '@{' + us.Id + '}');
      }
    }
  }
  /**
   * @description Method to form the comment
   */
  Public static void formComment() {
    String caseId;
    String comment;
    String commentLdaps;
    if (objectsMap.size() > 0) {
      for (wrapperClass wc : objectsMap.values()) {
        caseId = casesNumbers.get(wc.caseNumber);
        if (caseId != null || !String.isBlank(caseId)) {
          for (String addLdaps : wc.ldapsList) {
            String userLdap = casesLdaps.get(addLdaps);
            commentLdaps =
                !String.isBlank(commentLdaps) ? CommentLdaps + ', ' + userLdap : userLdap;
          }
          comment = casesComments.get(wc.caseNumber) + '\n'
              + (!String.isBlank(commentLdaps) ? commentLdaps.replace('null','') :'');
          commentLdaps ='';
          wc.status = 'Success';
          ConnectApi.FeedItemInput input = parseChatterPostWithMentions(caseId, comment);
          batchInputs.add(new ConnectApi.BatchInput(input));
        } else {
          objectsMap.remove(wc.caseNumber);
          casesNumbers.remove(wc.caseNumber);
          wc.status = 'Wrong case number' + '\n' + 'or user has no access to case';
          wrongValues.put(wc.caseNumber, wc);
        }
      }
      wrongValues.remove('end');
      callConnectApi();
    }
  }
  /**
   * @description Method to call api to
   * insert posts with mentions
   */
  Public static void callConnectApi() {
    if (batchInputs.size() > 0 && !Test.isRunningTest()) {
      ConnectApi.ChatterFeeds.postFeedElementBatch(null, batchInputs);
    } else if (Test.isRunningTest()) {
      List<FeedItem> postList = new List<FeedItem>();
      for (wrapperClass wc : objectsMap.values()) {
        FeedItem testPost = new FeedItem();
        testPost.ParentId = casesNumbers.get(wc.caseNumber);
        testPost.Body = casesComments.get(wc.caseNumber);
        testPost.Type = 'TextPost';
        postList.add(testPost);
      }
      insert postList;
    }
  }
  /**
   * @description Method to set error message and exit method
   * @param String error message
   * @return resultClass resultClassObject
   */
  Public static resultClass exitWithErrorMsg(String errMsgP) {
    errorMessage = errMsgP;
    resultClassObject = createResultClassObject();
    return (resultClassObject);
  }
  /**
   * @description wrapper class to contain file results
   */
  Public class wrapperClass {
    @AuraEnabled public String caseNumber;
    @AuraEnabled public String comment;
    @AuraEnabled public String ldaps;
    @AuraEnabled public String status;
    @AuraEnabled public List<String> ldapsList;
  }
  /**
   * @description Method to create an object of wrapperClass
   * @return wrapperClass object
   */
  Public static wrapperClass
  createWrapperClassObject(String caseNumber, String comment, String ldaps) {
    wrapperClass wrapperObj = new wrapperClass();
    List<String> commaSep;
    wrapperObj.caseNumber = caseNumber;
    wrapperObj.comment = comment;
    wrapperObj.ldaps = ldaps;
    if (ldaps !='' || ldaps != null) {
      ldaps = ldaps.replace('\r\n', '');
      ldaps = ldaps.replace('\n', '');
      ldaps = ldaps.replace('\r', '');
      wrapperObj.ldapsList = ldaps.split(';');
      commaSep = ldaps.split(',');
      if (commaSep.size() > 1) {
        wrapperObj.status = 'LDAPs must be separated by a semicolon ";"';
      }
    }
    return (wrapperObj);
  }
  /**
   * @description wrapper class to send file results to js
   */
  Public class resultClass {
    @AuraEnabled public List<wrapperClass> successRecords;
    @AuraEnabled public List<wrapperClass> failedRecords;
    @AuraEnabled public String errorMsg = '';
  }
  /**
   * @description Method to create an object of resultClass
   * @return resultClass object
   */
  Public static resultClass
  createResultClassObject() {
    resultClass resultClassObj = new resultClass();
    resultClassObj.successRecords = objectsMap.values();
    resultClassObj.failedRecords = wrongValues.values();
    resultClassObj.errorMsg = errorMessage;
    return (resultClassObj);
  }
  /**
   * @description Method replace \n and commas from text before
   * splitting file data
   * @param String csvLine
   * @param String charToReplace
   * @param String replacement
   * @return String String csvLine
   */
  Public Static String replaceCommasAndNewLinesInComments(
      String csvLine, String charToReplace, String replacement) {
    String prevLine = csvLine;
    Integer startIndex;
    Integer endIndex;
    while (csvLine.indexOf('"') > -1) {
      if (startIndex == null) {
        startIndex = csvLine.indexOf('"');
        csvLine = csvLine.substring(0, startIndex) + ':quotes:'
            + csvLine.substring(startIndex + 1, csvLine.length());
      } else {
        if (endIndex == null) {
          endIndex = csvLine.indexOf('"');
          csvLine = csvLine.substring(0, endIndex) + ':quotes:'
              + csvLine.substring(endIndex + 1, csvLine.length());
        }
      }
      if (startIndex != null && endIndex != null) {
        String sub = csvLine.substring(startIndex, endIndex);
        sub = sub.replaceAll(charToReplace, replacement);
        csvLine =
            csvLine.substring(0, startIndex) + sub + csvLine.substring(endIndex, csvLine.length());
        startIndex = null;
        endIndex = null;
      }
    }
    return csvLine;
  }
  /**
   * @description Method to create ConnectApi.FeedItemInput object
   * with mentions
   * @param String caseId
   * @param String msg
   * @return ConnectApi.FeedItemInput feedItemInput
   */
  public
  Static ConnectApi.FeedItemInput parseChatterPostWithMentions(String caseId, String msg) {
    ConnectApi.FeedItemInput feedItemInput = new ConnectApi.FeedItemInput();
    ConnectApi.MessageBodyInput messageBodyInput = new ConnectApi.MessageBodyInput();
    messageBodyInput.messageSegments = new List<ConnectApi.MessageSegmentInput>();
    Pattern p = Pattern.compile('(\\@\\{([a-zA-Z0-9]){15,18}?\\})');
    String[] textSegments = p.split(msg, -1);
    Matcher pm = p.matcher(msg);
    List<String> mentionedNames = new List<String>{};
    Map<String, ConnectApi.MentionSegmentInput> nameToInputMap =
        new Map<String, ConnectApi.MentionSegmentInput>{};
    if (pm.find()) {
      do {
        String mentionName = pm.group(0);
        mentionName = mentionName.substring(2, mentionName.length() - 1);
        if (!nameToInputMap.containsKey(mentionName)) {
          nameToInputMap.put(mentionName, new ConnectApi.MentionSegmentInput());
        }
        mentionedNames.add(mentionName);
      } while (pm.find());
    }
    ConnectApi.MentionSegmentInput[] mentions = new ConnectApi.MentionSegmentInput[]{};
    for (Id u : mentionedNames) {
      ConnectApi.MentionSegmentInput mentionSegmentInput = new ConnectApi.MentionSegmentInput();
      nameToInputMap.get(u).id = u;
      mentionSegmentInput.id = u;
    }
    for (Integer i = 0; i < textSegments.size(); i++) {
      ConnectApi.TextSegmentInput textSegmentInput = new ConnectApi.TextSegmentInput();
      textSegmentInput.text = textSegments[i];
      messageBodyInput.messageSegments.add(textSegmentInput);
      if (mentionedNames.size() > i) {
        messageBodyInput.messageSegments.add(nameToInputMap.get(mentionedNames[i]));
      }
    }
    feedItemInput.body = messageBodyInput;
    feedItemInput.subjectId = caseId;
    feedItemInput.feedElementType = ConnectApi.FeedElementType.FeedItem;
    return feedItemInput;
  }
}
