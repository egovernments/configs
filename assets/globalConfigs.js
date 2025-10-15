var globalConfigs = (function () {
  var stateTenantId = "statea";
  var contextPath = "digit-ui";
  var gmaps_api_key_old = "AIzaSyAQOd09-vjmk1sXFb_ZQYDz2nlfhXq7Wf8";
  var gmaps_api_key = "AIzaSyASqkAr3d494ihZaJeCOg4CJ3xnQ_83e2s";
  var finEnv = "demo";
  var centralInstanceEnabled = false;
  var footerBWLogoURL = "https://s3.ap-south-1.amazonaws.com/egov-uat-assets/digit-footer-bw.png";
  var footerLogoURL = "https://s3.ap-south-1.amazonaws.com/egov-uat-assets/digit-footer.png";
  var digitHomeURL = "https://www.digit.org/";
  var assetS3Bucket = "pg-egov-assets";
  var configModuleName = "commonHCMUiConfig";
  var localeRegion = "IN";
  var localeDefault = "en";
  var xstateWebchatServices = "wss://dev.digit.org/xstate-webchat/";
  var mdmsContext = "mdms-v2";
  var hrmsContext = "egov-hrms";
  var projectContext = "health-project";
  var mdmsFeatures = {
    bulkDownload: false,
    bulkUpload: false,
    JSONEdit: true
  };
  var invalidEmployeeRoles = ["CBO_ADMIN", "ORG_ADMIN", "ORG_STAFF", "SYSTEM"];

  var getConfig = function (key) {
    if (key === "STATE_LEVEL_TENANT_ID") {
      return stateTenantId;
    } else if (key === "GMAPS_API_KEY") {
      return gmaps_api_key;
    } else if (key === "FIN_ENV") {
      return finEnv;
    } else if (key === "ENABLE_SINGLEINSTANCE") {
      return centralInstanceEnabled;
    } else if (key === "DIGIT_FOOTER_BW") {
      return footerBWLogoURL;
    } else if (key === "DIGIT_FOOTER") {
      return footerLogoURL;
    } else if (key === "DIGIT_HOME_URL") {
      return digitHomeURL;
    } else if (key === "S3BUCKET") {
      return assetS3Bucket;
    } else if (key === "JWT_TOKEN") {
      return "ZWdvdi11c2VyLWNsaWVudDo=";
    } else if (key === "CONTEXT_PATH") {
      return contextPath;
    } else if (key === "UICONFIG_MODULENAME") {
      return configModuleName;
    } else if (key === "LOCALE_REGION") {
      return localeRegion;
    } else if (key === "LOCALE_DEFAULT") {
      return localeDefault;
    } else if (key === "xstate-webchat-services") {
      return xstateWebchatServices;
    } else if (key === "ENABLE_JSON_EDIT") {
      return mdmsFeatures?.JSONEdit;
    } else if (key === "ENABLE_MDMS_BULK_UPLOAD") {
      return mdmsFeatures?.bulkUpload;
    } else if (key === "ENABLE_MDMS_BULK_DOWNLOAD") {
      return mdmsFeatures?.bulkDownload;
    } else if (key === "MDMS_CONTEXT_PATH") {
      return mdmsContext;
    } else if (key === "MDMS_V2_CONTEXT_PATH") {
      return mdmsContext;
    } else if (key === "MDMS_V1_CONTEXT_PATH") {
      return mdmsContext;
    } else if (key === "HRMS_CONTEXT_PATH") {
      return hrmsContext;
    } else if (key === "PROJECT_SERVICE_PATH") {
      return projectContext;
    } else if (key === "INVALIDROLES") {
      return invalidEmployeeRoles;
    }
  };

  return {
    getConfig,
  };
})();