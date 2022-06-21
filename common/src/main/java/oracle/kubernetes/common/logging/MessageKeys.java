// Copyright (c) 2017, 2022, Oracle and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

package oracle.kubernetes.common.logging;

/**
 * Message keys used to look up log messages from the resource bundle. The use of message keys makes
 * the code more readable.
 */
public class MessageKeys {
  public static final String OPERATOR_STARTED = "WLSKO-0000";
  public static final String CREATING_API_CLIENT = "WLSKO-0001";
  public static final String K8S_MASTER_URL = "WLSKO-0002";
  public static final String ENABLED_FEATURES = "WLSKO-0003";
  public static final String OPERATOR_SHUTTING_DOWN = "WLSKO-0005";
  public static final String EXCEPTION = "WLSKO-0006";
  public static final String NO_FORMATTING = "WLSKO-0007";
  public static final String CREATING_CRD = "WLSKO-0012";
  public static final String SECRET_NOT_FOUND = "WLSKO-0018";
  public static final String RETRIEVING_SECRET = "WLSKO-0019";
  public static final String SECRET_DATA_NOT_FOUND = "WLSKO-0020";
  public static final String WLS_CONFIGURATION_READ = "WLSKO-0021";
  public static final String JSON_PARSING_FAILED = "WLSKO-0026";
  public static final String NO_WLS_SERVER_IN_CLUSTER = "WLSKO-0028";
  public static final String VERIFY_ACCESS_START = "WLSKO-0029";
  public static final String VERIFY_ACCESS_DENIED = "WLSKO-0030";
  public static final String STARTING_LIVENESS_THREAD = "WLSKO-0034";
  public static final String COULD_NOT_CREATE_LIVENESS_FILE = "WLSKO-0035";
  public static final String REST_AUTHENTICATION_MISSING_ACCESS_TOKEN = "WLSKO-0037";
  public static final String PROCESSING_DOMAIN = "WLSKO-0038";
  public static final String WATCH_DOMAIN = "WLSKO-0039";
  public static final String WATCH_DOMAIN_DELETED = "WLSKO-0040";
  public static final String ADMIN_POD_CREATED = "WLSKO-0041";
  public static final String ADMIN_POD_REPLACED = "WLSKO-0042";
  public static final String ADMIN_POD_EXISTS = "WLSKO-0043";
  public static final String ADMIN_SERVICE_CREATED = "WLSKO-0044";
  public static final String ADMIN_SERVICE_REPLACED = "WLSKO-0045";
  public static final String ADMIN_SERVICE_EXISTS = "WLSKO-0046";
  public static final String MANAGED_POD_CREATED = "WLSKO-0047";
  public static final String MANAGED_POD_REPLACED = "WLSKO-0048";
  public static final String MANAGED_POD_EXISTS = "WLSKO-0049";
  public static final String MANAGED_SERVICE_CREATED = "WLSKO-0050";
  public static final String MANAGED_SERVICE_REPLACED = "WLSKO-0051";
  public static final String MANAGED_SERVICE_EXISTS = "WLSKO-0052";
  public static final String CLUSTER_SERVICE_CREATED = "WLSKO-0053";
  public static final String CLUSTER_SERVICE_REPLACED = "WLSKO-0054";
  public static final String CLUSTER_SERVICE_EXISTS = "WLSKO-0055";
  public static final String CM_CREATED = "WLSKO-0056";
  public static final String CM_REPLACED = "WLSKO-0057";
  public static final String CM_EXISTS = "WLSKO-0058";
  public static final String CANNOT_CREATE_TOKEN_REVIEW = "WLSKO-0059";
  public static final String APIEXCEPTION_FROM_TOKEN_REVIEW = "WLSKO-0068";
  public static final String APIEXCEPTION_FROM_SUBJECT_ACCESS_REVIEW = "WLSKO-0069";
  public static final String REPLICA_MORE_THAN_WLS_SERVERS = "WLSKO-0071";
  public static final String K8S_VERSION_TOO_LOW = "WLSKO-0073";
  public static final String VERIFY_K8S_MIN_VERSION = "WLSKO-0074";
  public static final String DOMAIN_UID_UNIQUENESS_FAILED = "WLSKO-0076";
  public static final String PV_NOT_FOUND_FOR_DOMAIN_UID = "WLSKO-0077";
  public static final String PV_ACCESS_MODE_FAILED = "WLSKO-0078";
  public static final String K8S_VERSION_CHECK = "WLSKO-0079";
  public static final String K8S_VERSION_CHECK_FAILURE = "WLSKO-0080";
  public static final String HTTP_METHOD_FAILED = "WLSKO-0081";
  public static final String NOT_STARTING_DOMAINUID_THREAD = "WLSKO-0082";
  public static final String OP_CONFIG_NAMESPACE = "WLSKO-0083";
  public static final String OP_CONFIG_DOMAIN_NAMESPACES = "WLSKO-0084";
  public static final String OP_CONFIG_SERVICE_ACCOUNT = "WLSKO-0085";
  public static final String WAITING_FOR_POD_READY = "WLSKO-0087";
  public static final String POD_IS_READY = "WLSKO-0088";
  public static final String POD_IS_FAILED = "WLSKO-0089";
  public static final String ASYNC_REQUEST = "WLSKO-0094";
  public static final String ASYNC_FAILURE = "WLSKO-0095";
  public static final String ASYNC_SUCCESS = "WLSKO-0096";
  public static final String ASYNC_NO_RETRY = "WLSKO-0097";
  public static final String ASYNC_RETRY = "WLSKO-0098";
  public static final String ASYNC_TIMEOUT = "WLSKO-0099";
  public static final String WATCH_EVENT = "WLSKO-0101";
  public static final String DOMAIN_STATUS = "WLSKO-0102";
  public static final String INVALID_MANAGE_SERVER_COUNT = "WLSKO-0103";
  public static final String SCALE_COUNT_GREATER_THAN_CONFIGURED = "WLSKO-0104";
  public static final String MATCHING_DOMAIN_NOT_FOUND = "WLSKO-0106";
  public static final String INVALID_DOMAIN_UID = "WLSKO-0107";
  public static final String NULL_DOMAIN_UID = "WLSKO-0108";
  public static final String NULL_TOKEN_REVIEW_STATUS = "WLSKO-0109";
  public static final String NULL_USER_INFO = "WLSKO-0110";
  public static final String RESOURCE_BUNDLE_NOT_FOUND = "WLSKO-0111";
  public static final String CURRENT_STEPS = "WLSKO-0112";
  public static final String CYCLING_SERVERS = "WLSKO-0118";
  public static final String ROLLING_SERVERS = "WLSKO-0119";
  public static final String ADMIN_POD_PATCHED = "WLSKO-0120";
  public static final String MANAGED_POD_PATCHED = "WLSKO-0121";
  public static final String POD_DELETED = "WLSKO-0122";
  public static final String TUNING_PARAMETERS = "WLSKO-0126";
  public static final String WLS_HEALTH_READ_FAILED = "WLSKO-0127";
  public static final String WLS_SERVER_TEMPLATE_NOT_FOUND = "WLSKO-0133";
  public static final String SCRIPT_LOADED = "WLSKO-0134";
  public static final String JOB_IS_FAILED = "WLSKO-0136";
  public static final String JOB_DELETED = "WLSKO-0137";
  public static final String WAITING_FOR_JOB_READY = "WLSKO-0138";
  public static final String JOB_CREATED = "WLSKO-0139";
  public static final String JOB_IS_COMPLETE = "WLSKO-0140";
  public static final String CANNOT_PARSE_TOPOLOGY = "WLSKO-0141";
  public static final String CANNOT_PARSE_INTROSPECTOR_RESULT = "WLSKO-0142";
  public static final String CANNOT_PARSE_INTROSPECTOR_FILE = "WLSKO-0143";
  public static final String CANNOT_START_DOMAIN_AFTER_MAX_RETRIES = "WLSKO-0144";
  public static final String CYCLING_POD = "WLSKO-0145";
  public static final String REPLICAS_EXCEEDS_TOTAL_CLUSTER_SERVER_COUNT = "WLSKO-0146";
  public static final String POD_DUMP = "WLSKO-0148";
  public static final String EXTERNAL_CHANNEL_SERVICE_CREATED = "WLSKO-0150";
  public static final String EXTERNAL_CHANNEL_SERVICE_REPLACED = "WLSKO-0151";
  public static final String EXTERNAL_CHANNEL_SERVICE_EXISTS = "WLSKO-0152";
  public static final String WLS_HEALTH_READ_FAILED_NO_HTTPCLIENT = "WLSKO-0153";
  public static final String JOB_DEADLINE_EXCEEDED_MESSAGE = "WLSKO-0154";
  public static final String VERIFY_ACCESS_DENIED_WITH_NS = "WLSKO-0156";
  public static final String DOMAIN_VALIDATION_FAILED = "WLSKO-0157";
  public static final String NO_INTERNAL_CERTIFICATE = "WLSKO-162";
  public static final String NO_EXTERNAL_CERTIFICATE = "WLSKO-163";
  public static final String REPLICAS_LESS_THAN_TOTAL_CLUSTER_SERVER_COUNT = "WLSKO-0164";
  public static final String REQUEST_PARAMS_IN_NS = "WLSKO-0165";
  public static final String REQUEST_PARAMS_FOR_NAME = "WLSKO-0166";
  public static final String REQUEST_PARAMS_WITH = "WLSKO-0167";
  public static final String CALL_FAILED = "WLSKO-0168";
  public static final String JOB_CREATION_TIMESTAMP_MESSAGE = "WLSKO-0169";
  public static final String HTTP_REQUEST_TIMED_OUT = "WLSKO-0170";
  public static final String NAMESPACE_IS_MISSING = "WLSKO-0171";
  public static final String CM_PATCHED = "WLSKO-0172";
  public static final String REPLACE_CRD_FAILED = "WLSKO-0173";
  public static final String CREATE_CRD_FAILED = "WLSKO-0174";
  public static final String INTROSPECTOR_JOB_FAILED = "WLSKO-0175";
  public static final String INTROSPECTOR_JOB_FAILED_DETAIL = "WLSKO-0176";
  public static final String INTROSPECTOR_POD_FAILED = "WLSKO-0177";
  public static final String CRD_NOT_INSTALLED = "WLSKO-0178";
  public static final String POD_FORCE_DELETED = "WLSKO-0179";
  public static final String CREATING_EVENT = "WLSKO-0180";
  public static final String REPLACING_EVENT = "WLSKO-0181";
  public static final String CREATING_EVENT_FORBIDDEN = "WLSKO-0182";
  public static final String CLUSTER_PDB_CREATED = "WLSKO-0183";
  public static final String CLUSTER_PDB_EXISTS = "WLSKO-0184";
  public static final String CLUSTER_PDB_PATCHED = "WLSKO-0185";
  public static final String BEGIN_MANAGING_NAMESPACE = "WLSKO-0186";
  public static final String END_MANAGING_NAMESPACE = "WLSKO-0187";
  public static final String HTTP_REQUEST_GOT_THROWABLE = "WLSKO-0189";
  public static final String DOMAIN_ROLL_START = "WLSKO-0190";
  public static final String EXECUTE_MAKE_RIGHT_DOMAIN = "WLSKO-0192";
  public static final String LOG_WAITING_COUNT = "WLSKO-0193";
  public static final String INTERNAL_IDENTITY_INITIALIZATION_FAILED = "WLSKO-0194";
  public static final String DOMAIN_FATAL_ERROR = "WLSKO-0195";
  public static final String INTROSPECTOR_MAX_ERRORS_EXCEEDED = "WLSKO-0196";
  public static final String NON_FATAL_INTROSPECTOR_ERROR = "WLSKO-0197";
  public static final String DUMP_BREADCRUMBS = "WLSKO-0198";
  public static final String BEGIN_SERVER_SHUTDOWN_REST = "WLSKO-0199";
  public static final String SERVER_SHUTDOWN_REST_SUCCESS = "WLSKO-0200";
  public static final String SERVER_SHUTDOWN_REST_FAILURE = "WLSKO-0201";
  public static final String SERVER_SHUTDOWN_REST_TIMEOUT = "WLSKO-0202";
  public static final String SERVER_SHUTDOWN_REST_THROWABLE = "WLSKO-0203";
  public static final String SERVER_SHUTDOWN_REST_RETRY = "WLSKO-0204";
  public static final String INPUT_FILE_NON_EXISTENT = "WLSKO-0213";
  public static final String OUTPUT_FILE_NON_EXISTENT = "WLSKO-0214";
  public static final String OUTPUT_FILE_EXISTS = "WLSKO-0215";
  public static final String PRINT_HELP = "WLSKO-0216";
  public static final String OUTPUT_DIRECTORY = "WLSKO-0217";
  public static final String OUTPUT_FILE_NAME = "WLSKO-0218";
  public static final String OVERWRITE_EXISTING_OUTPUT_FILE = "WLSKO-0219";
  public static final String DOMAIN_UPGRADE_SUCCESS = "WLSKO-0220";
  public static final String INTROSPECTOR_FLUENTD_CONTAINER_TERMINATED = "WLSKO-0222";
  public static final String MISSING_ELASTIC_SEARCH_SECRET = "WLSKO-0223";
  public static final String FLUENTD_CONFIGMAP_CREATED = "WLSKO-0224";
  public static final String FLUENTD_CONFIGMAP_REPLACED = "WLSKO-0225";
  public static final String POD_EVICTED = "WLSKO-0226";
  public static final String POD_EVICTED_NO_RESTART = "WLSKO-0227";
  public static final String WATCH_CLUSTER = "WLSKO-0228";
  public static final String WATCH_CLUSTER_DELETED = "WLSKO-0229";

  // domain status messages
  public static final String DUPLICATE_SERVER_NAME_FOUND = "WLSDO-0001";
  public static final String DUPLICATE_CLUSTER_NAME_FOUND = "WLSDO-0002";
  public static final String LOG_HOME_NOT_MOUNTED = "WLSDO-0003";
  public static final String BAD_VOLUME_MOUNT_PATH = "WLSDO-0004";
  public static final String RESERVED_ENVIRONMENT_VARIABLES = "WLSDO-0005";
  public static final String ILLEGAL_SECRET_NAMESPACE = "WLSDO-0006";
  public static final String ILLEGAL_SIT_CONFIG_MII = "WLSDO-0007";
  public static final String MODEL_CONFIGMAP_NOT_FOUND = "WLSDO-0008";
  public static final String SECRET_NOT_SPECIFIED = "WLSDO-0009";
  public static final String OPSS_SECRET_NOT_SPECIFIED = "WLSDO-0010";
  public static final String NO_CLUSTER_IN_DOMAIN = "WLSDO-0011";
  public static final String NO_MANAGED_SERVER_IN_DOMAIN = "WLSDO-0012";
  public static final String CANNOT_EXPOSE_DEFAULT_CHANNEL_ISTIO = "WLSDO-0013";
  public static final String INTROSPECT_JOB_FAILED = "WLSDO-0014";
  public static final String ILLEGAL_INTROSPECTOR_JOB_NAME_LENGTH = "WLSDO-0016";
  public static final String ILLEGAL_CLUSTER_SERVICE_NAME_LENGTH = "WLSDO-0017";
  public static final String ILLEGAL_SERVER_SERVICE_NAME_LENGTH = "WLSDO-0018";
  public static final String ILLEGAL_EXTERNAL_SERVICE_NAME_LENGTH = "WLSDO-0019";
  public static final String MII_DOMAIN_UPDATED_POD_RESTART_REQUIRED = "WLSDO-0020";
  public static final String NO_AVAILABLE_PORT_TO_USE_FOR_REST = "WLSDO-0021";
  public static final String MONITORING_EXPORTER_CONFLICT_SERVER = "WLSDO-0027";
  public static final String MONITORING_EXPORTER_CONFLICT_DYNAMIC_CLUSTER = "WLSDO-0028";
  public static final String INVALID_LIVENESS_PROBE_SUCCESS_THRESHOLD_VALUE = "WLSDO-0029";
  public static final String RESERVED_CONTAINER_NAME = "WLSDO-0030";
  public static final String ILLEGAL_CONTAINER_PORT_NAME_LENGTH = "WLSDO-0031";
  public static final String ILLEGAL_NETWORK_CHANNEL_NAME_LENGTH = "WLSDO-0032";
  public static final String K8S_REQUEST_FAILURE = "WLSDO-0033";
  public static final String SERVER_POD_FAILURE = "WLSDO-0034";
  public static final String TOO_MANY_REPLICAS_FAILURE = "WLSDO-0035";
  public static final String MOUNT_PATH_FOR_AUXILIARY_IMAGE_ALREADY_IN_USE = "WLSDO-0036";
  public static final String MORE_THAN_ONE_AUXILIARY_IMAGE_CONFIGURED_WDT_INSTALL_HOME = "WLSDO-0037";
  public static final String INVALID_WDT_INSTALL_HOME = "WLSDO-0038";
  public static final String INVALID_MODEL_HOME = "WLSDO-0039";
  public static final String PODS_FAILED = "WLSDO-0040";
  public static final String PODS_NOT_READY = "WLSDO-0041";
  public static final String CYCLING_POD_EVICTED = "WLSDO-0042";
  public static final String CYCLING_POD_SPEC_CHANGED = "WLSDO-0043";

  // domain event messages
  public static final String DOMAIN_AVAILABLE_EVENT_PATTERN = "WLSEO-0001";
  public static final String DOMAIN_CREATED_EVENT_PATTERN = "WLSEO-0002";
  public static final String DOMAIN_CHANGED_EVENT_PATTERN = "WLSEO-0003";
  public static final String DOMAIN_COMPLETED_EVENT_PATTERN = "WLSEO-0004";
  public static final String DOMAIN_DELETED_EVENT_PATTERN = "WLSEO-0005";
  public static final String DOMAIN_FAILED_EVENT_PATTERN = "WLSEO-0006";
  public static final String DOMAIN_UNAVAILABLE_EVENT_PATTERN = "WLSEO-0007";
  public static final String DOMAIN_INCOMPLETE_EVENT_PATTERN = "WLSEO-0008";
  public static final String DOMAIN_FAILURE_RESOLVED_EVENT_PATTERN = "WLSEO-0009";
  public static final String POD_CYCLE_STARTING_EVENT_PATTERN = "WLSEO-0010";
  public static final String START_MANAGING_NAMESPACE_EVENT_PATTERN = "WLSEO-0011";
  public static final String STOP_MANAGING_NAMESPACE_EVENT_PATTERN = "WLSEO-0012";
  public static final String NAMESPACE_WATCHING_STARTED_EVENT_PATTERN = "WLSEO-0013";
  public static final String NAMESPACE_WATCHING_STOPPED_EVENT_PATTERN = "WLSEO-0014";
  public static final String START_MANAGING_NAMESPACE_FAILED_EVENT_PATTERN = "WLSEO-0015";
  public static final String DOMAIN_ROLL_STARTING_EVENT_PATTERN = "WLSEO-0016";
  public static final String DOMAIN_ROLL_COMPLETED_EVENT_PATTERN = "WLSEO-0017";
  public static final String DOMAIN_INVALID_EVENT_ERROR = "WLSEO-0018";
  public static final String TOPOLOGY_MISMATCH_EVENT_ERROR = "WLSEO-0019";
  public static final String INTROSPECTION_EVENT_ERROR = "WLSEO-0020";
  public static final String KUBERNETES_EVENT_ERROR = "WLSEO-0021";
  public static final String SERVER_POD_EVENT_ERROR = "WLSEO-0022";
  public static final String REPLICAS_TOO_HIGH_EVENT_ERROR = "WLSEO-0023";
  public static final String INTERNAL_EVENT_ERROR = "WLSEO-0024";
  public static final String ABORTED_EVENT_ERROR = "WLSEO-0025";
  public static final String WILL_RETRY_EVENT_SUGGESTION = "WLSEO-0026";
  public static final String ABORTED_ERROR_EVENT_SUGGESTION = "WLSEO-0027";
  public static final String DOMAIN_INVALID_ERROR_EVENT_SUGGESTION = "WLSEO-0028";
  public static final String TOPOLOGY_MISMATCH_ERROR_EVENT_SUGGESTION = "WLSEO-0029";
  public static final String REPLICAS_TOO_HIGH_ERROR_EVENT_SUGGESTION = "WLSEO-0030";

  // Webhook messages
  public static final String WEBHOOK_STARTED = "WLSWH-0001";
  public static final String NO_WEBHOOK_CERTIFICATE = "WLSWH-0002";
  public static final String WEBHOOK_CONFIG_NAMESPACE = "WLSWH-0003";
  public static final String WAIT_FOR_CRD_INSTALLATION = "WLSWH-0004";
  public static final String WEBHOOK_SHUTTING_DOWN = "WLSWH-0005";
  public static final String STARTING_WEBHOOK_LIVENESS_THREAD = "WLSWH-0006";
  public static final String WEBHOOK_IDENTITY_INITIALIZATION_FAILED = "WLSWH-0007";
  public static final String DOMAIN_CONVERSION_FAILED = "WLSWH-0008";
  public static final String VALIDATING_WEBHOOK_CONFIGURATION_CREATED = "WLSWH-0009";
  public static final String CREATE_VALIDATING_WEBHOOK_CONFIGURATION_FAILED = "WLSWH-0010";
  public static final String VALIDATION_FAILED = "WLSWH-0011";
  public static final String VALIDATING_WEBHOOK_CONFIGURATION_REPLACED = "WLSWH-0012";
  public static final String REPLACE_VALIDATING_WEBHOOK_CONFIGURATION_FAILED = "WLSWH-0013";
  public static final String READ_VALIDATING_WEBHOOK_CONFIGURATION_FAILED = "WLSWH-0014";
  public static final String CLUSTER_REPLICAS_CANNOT_BE_HONORED = "WLSWH-0015";
  public static final String CLUSTER_REPLICAS_TOO_HIGH = "WLSWH-0016";
  public static final String DOMAIN_INTROSPECTION_TRIGGER_CHANGED = "WLSWH-0017";
  public static final String WEBHOOK_STARTUP_FAILED = "WLSWH-0018";

  private MessageKeys() {
  }
}
