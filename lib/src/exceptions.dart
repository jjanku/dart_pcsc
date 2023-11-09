import 'dart:io';

import 'generated/pcsc_lib.dart';

String _errorCodeToString(int error) {
  // copied from pcsclite.h
  switch (error) {
    case SCARD_S_SUCCESS:
      return 'No error was encountered.';
    case SCARD_F_INTERNAL_ERROR:
      return 'An internal consistency check failed.';
    case SCARD_E_CANCELLED:
      return 'The action was cancelled by an SCardCancel request.';
    case SCARD_E_INVALID_HANDLE:
      return 'The supplied handle was invalid.';
    case SCARD_E_INVALID_PARAMETER:
      return 'One or more of the supplied parameters '
          'could not be properly interpreted.';
    case SCARD_E_INVALID_TARGET:
      return 'Registry startup information is missing or invalid.';
    case SCARD_E_NO_MEMORY:
      return 'Not enough memory available to complete this command.';
    case SCARD_F_WAITED_TOO_LONG:
      return 'An internal consistency timer has expired.';
    case SCARD_E_INSUFFICIENT_BUFFER:
      return 'The data buffer to receive returned data '
          'is too small for the returned data.';
    case SCARD_E_UNKNOWN_READER:
      return 'The specified reader name is not recognized.';
    case SCARD_E_TIMEOUT:
      return 'The user-specified timeout value has expired.';
    case SCARD_E_SHARING_VIOLATION:
      return 'The smart card cannot be accessed because of '
          'other connections outstanding.';
    case SCARD_E_NO_SMARTCARD:
      return 'The operation requires a Smart Card, '
          'but no Smart Card is currently in the device.';
    case SCARD_E_UNKNOWN_CARD:
      return 'The specified smart card name is not recognized.';
    case SCARD_E_CANT_DISPOSE:
      return 'The system could not dispose of '
          'the media in the requested manner.';
    case SCARD_E_PROTO_MISMATCH:
      return 'The requested protocols are incompatible with the protocol '
          'currently in use with the smart card.';
    case SCARD_E_NOT_READY:
      return 'The reader or smart card is not ready to accept commands.';
    case SCARD_E_INVALID_VALUE:
      return 'One or more of the supplied parameters values '
          'could not be properly interpreted.';
    case SCARD_E_SYSTEM_CANCELLED:
      return 'The action was cancelled by the system, '
          'presumably to log off or shut down.';
    case SCARD_F_COMM_ERROR:
      return 'An internal communications error has been detected.';
    case SCARD_F_UNKNOWN_ERROR:
      return 'An internal error has been detected, but the source is unknown.';
    case SCARD_E_INVALID_ATR:
      return 'An ATR obtained from the registry is not a valid ATR string.';
    case SCARD_E_NOT_TRANSACTED:
      return 'An attempt was made to end a non-existent transaction.';
    case SCARD_E_READER_UNAVAILABLE:
      return 'The specified reader is not currently available for use.';
    case SCARD_P_SHUTDOWN:
      return 'The operation has been aborted '
          'to allow the server application to exit.';
    case SCARD_E_PCI_TOO_SMALL:
      return 'The PCI Receive buffer was too small.';
    case SCARD_E_READER_UNSUPPORTED:
      return 'The reader driver does not meet '
          'minimal requirements for support.';
    case SCARD_E_DUPLICATE_READER:
      return 'The reader driver did not produce a unique reader name.';
    case SCARD_E_CARD_UNSUPPORTED:
      return 'The smart card does not meet '
          'minimal requirements for support.';
    case SCARD_E_NO_SERVICE:
      return 'The Smart card resource manager is not running.';
    case SCARD_E_SERVICE_STOPPED:
      return 'The Smart card resource manager has shut down.';
    case SCARD_E_UNEXPECTED when Platform.isWindows:
      return 'An unexpected card error has occurred.';
    // a difference between pcsc-lite and WinSCard, see
    // https://pcsclite.apdu.fr/api/group__API.html
    case SCARD_E_UNSUPPORTED_FEATURE when !Platform.isWindows:
    case 0x80100022 when Platform.isWindows:
      return 'This smart card does not support the requested feature.';
    case SCARD_E_ICC_INSTALLATION:
      return 'No primary provider can be found for the smart card.';
    case SCARD_E_ICC_CREATEORDER:
      return 'The requested order of object creation is not supported.';
    case SCARD_E_DIR_NOT_FOUND:
      return 'The identified directory does not exist in the smart card.';
    case SCARD_E_FILE_NOT_FOUND:
      return 'The identified file does not exist in the smart card.';
    case SCARD_E_NO_DIR:
      return 'The supplied path does not represent a smart card directory.';
    case SCARD_E_NO_FILE:
      return 'The supplied path does not represent a smart card file.';
    case SCARD_E_NO_ACCESS:
      return 'Access is denied to this file.';
    case SCARD_E_WRITE_TOO_MANY:
      return 'The smart card does not have enough memory '
          'to store the information.';
    case SCARD_E_BAD_SEEK:
      return 'There was an error trying to set '
          'the smart card file object pointer.';
    case SCARD_E_INVALID_CHV:
      return 'The supplied PIN is incorrect.';
    case SCARD_E_UNKNOWN_RES_MNG:
      return 'An unrecognized error code was returned '
          'from a layered component.';
    case SCARD_E_NO_SUCH_CERTIFICATE:
      return 'The requested certificate does not exist.';
    case SCARD_E_CERTIFICATE_UNAVAILABLE:
      return 'The requested certificate could not be obtained.';
    case SCARD_E_NO_READERS_AVAILABLE:
      return 'Cannot find a smart card reader.';
    case SCARD_E_COMM_DATA_LOST:
      return 'A communications error with the smart card '
          'has been detected. Retry the operation.';
    case SCARD_E_NO_KEY_CONTAINER:
      return 'The requested key container does not exist on the smart card.';
    case SCARD_E_SERVER_TOO_BUSY:
      return 'The Smart Card Resource Manager is too busy '
          'to complete this operation.';

    case SCARD_W_UNSUPPORTED_CARD:
      return 'The reader cannot communicate with the card, '
          'due to ATR string configuration conflicts.';
    case SCARD_W_UNRESPONSIVE_CARD:
      return 'The smart card is not responding to a reset.';
    case SCARD_W_UNPOWERED_CARD:
      return 'Power has been removed from the smart card, '
          'so that further communication is not possible.';
    case SCARD_W_RESET_CARD:
      return 'The smart card has been reset, '
          'so any shared state information is invalid.';
    case SCARD_W_REMOVED_CARD:
      return 'The smart card has been removed, '
          'so further communication is not possible.';

    case SCARD_W_SECURITY_VIOLATION:
      return 'Access was denied because of a security violation.';
    case SCARD_W_WRONG_CHV:
      return 'The card cannot be accessed because the wrong PIN was presented.';
    case SCARD_W_CHV_BLOCKED:
      return 'The card cannot be accessed because '
          'the maximum number of PIN entry attempts has been reached.';
    case SCARD_W_EOF:
      return 'The end of the smart card file has been reached.';
    case SCARD_W_CANCELLED_BY_USER:
      return 'The user pressed "Cancel" on a Smart Card Selection Dialog.';
    case SCARD_W_CARD_NOT_AUTHENTICATED:
      return 'No PIN was presented to the smart card.';

    default:
      return 'Unknown error code $error';
  }
}

/// Base exception class for PC/SC failures.
class CardException implements Exception {
  final int errorCode;

  CardException(this.errorCode);

  @override
  String toString() => _errorCodeToString(errorCode);
}

class TimeoutException extends CardException {
  TimeoutException() : super(SCARD_E_TIMEOUT);
}

class CancelledException extends CardException {
  CancelledException() : super(SCARD_E_CANCELLED);
}

class NoReaderException extends CardException {
  NoReaderException() : super(SCARD_E_NO_READERS_AVAILABLE);
}
