import 'generated/pcsc_lib.dart';

class PcscError {
  static const int success = SCARD_S_SUCCESS;

  static const int internalError = SCARD_F_INTERNAL_ERROR;
  static const int cancelled = SCARD_E_CANCELLED;
  static const int invalidHandle = SCARD_E_INVALID_HANDLE;
  static const int invalidParameter = SCARD_E_INVALID_PARAMETER;
  static const int invalidTarget = SCARD_E_INVALID_TARGET;
  static const int noMemory = SCARD_E_NO_MEMORY;
  static const int waitedTooLong = SCARD_F_WAITED_TOO_LONG;
  static const int insufficientBuffer = SCARD_E_INSUFFICIENT_BUFFER;
  static const int unknownReader = SCARD_E_UNKNOWN_READER;
  static const int timeout = SCARD_E_TIMEOUT;
  static const int sharingViolation = SCARD_E_SHARING_VIOLATION;
  static const int noSmartcard = SCARD_E_NO_SMARTCARD;
  static const int unknownCard = SCARD_E_UNKNOWN_CARD;
  static const int cantDispose = SCARD_E_CANT_DISPOSE;
  static const int protoMismatch = SCARD_E_PROTO_MISMATCH;
  static const int notReady = SCARD_E_NOT_READY;
  static const int invalidValue = SCARD_E_INVALID_VALUE;
  static const int systemCancelled = SCARD_E_SYSTEM_CANCELLED;
  static const int commError = SCARD_F_COMM_ERROR;
  static const int unknownError = SCARD_F_UNKNOWN_ERROR;
  static const int invalidAtr = SCARD_E_INVALID_ATR;
  static const int notTransacted = SCARD_E_NOT_TRANSACTED;
  static const int readerUnavailable = SCARD_E_READER_UNAVAILABLE;
  static const int shutdown = SCARD_P_SHUTDOWN;
  static const int pciTooSmall = SCARD_E_PCI_TOO_SMALL;
  static const int readerUnsupported = SCARD_E_READER_UNSUPPORTED;
  static const int duplicateReader = SCARD_E_DUPLICATE_READER;
  static const int cardUnsupported = SCARD_E_CARD_UNSUPPORTED;
  static const int noService = SCARD_E_NO_SERVICE;
  static const int serviceStopped = SCARD_E_SERVICE_STOPPED;
  static const int unexpected = SCARD_E_UNEXPECTED;
  static const int unsupportedFeature = SCARD_E_UNSUPPORTED_FEATURE;
  static const int iccInstallation = SCARD_E_ICC_INSTALLATION;
  static const int iccCreateorder = SCARD_E_ICC_CREATEORDER;
  static const int dirNotFound = SCARD_E_DIR_NOT_FOUND;
  static const int fileNotFound = SCARD_E_FILE_NOT_FOUND;
  static const int noDir = SCARD_E_NO_DIR;
  static const int noFile = SCARD_E_NO_FILE;
  static const int noAccess = SCARD_E_NO_ACCESS;
  static const int writeTooMany = SCARD_E_WRITE_TOO_MANY;
  static const int badSeek = SCARD_E_BAD_SEEK;
  static const int invalidChv = SCARD_E_INVALID_CHV;
  static const int unknownResMng = SCARD_E_UNKNOWN_RES_MNG;
  static const int noSuchCertificate = SCARD_E_NO_SUCH_CERTIFICATE;
  static const int certificateUnavailable = SCARD_E_CERTIFICATE_UNAVAILABLE;
  static const int noReadersAvailable = SCARD_E_NO_READERS_AVAILABLE;
  static const int commDataLost = SCARD_E_COMM_DATA_LOST;
  static const int noKeyContainer = SCARD_E_NO_KEY_CONTAINER;
  static const int serverTooBusy = SCARD_E_SERVER_TOO_BUSY;

  static const int unsupportedCard = SCARD_W_UNSUPPORTED_CARD;
  static const int unresponsiveCard = SCARD_W_UNRESPONSIVE_CARD;
  static const int unpoweredCard = SCARD_W_UNPOWERED_CARD;
  static const int resetCard = SCARD_W_RESET_CARD;
  static const int removedCard = SCARD_W_REMOVED_CARD;
  static const int securityViolation = SCARD_W_SECURITY_VIOLATION;
  static const int wrongChv = SCARD_W_WRONG_CHV;
  static const int chvBlocked = SCARD_W_CHV_BLOCKED;
  static const int eof = SCARD_W_EOF;
  static const int cancelledByUser = SCARD_W_CANCELLED_BY_USER;
  static const int cardNotAuthenticated = SCARD_W_CARD_NOT_AUTHENTICATED;
}

class PcscScope {
  static const int user = SCARD_SCOPE_USER;
  static const int terminal = SCARD_SCOPE_TERMINAL;
  static const int system = SCARD_SCOPE_SYSTEM;
  static const int global = SCARD_SCOPE_GLOBAL;
}

class PcscProtocol {
  static const int t0 = SCARD_PROTOCOL_T0;
  static const int t1 = SCARD_PROTOCOL_T1;
  static const int raw = SCARD_PROTOCOL_RAW;
  static const int t15 = SCARD_PROTOCOL_T15;
  static const int any = SCARD_PROTOCOL_ANY;
}

class PcscShareMode {
  static const int exclusive = SCARD_SHARE_EXCLUSIVE;
  static const int shared = SCARD_SHARE_SHARED;
  static const int direct = SCARD_SHARE_DIRECT;
}

class PcscDisposition {
  static const int leaveCard = SCARD_LEAVE_CARD;
  static const int resetCard = SCARD_RESET_CARD;
  static const int unpowerCard = SCARD_UNPOWER_CARD;
  static const int ejectCard = SCARD_EJECT_CARD;
}
