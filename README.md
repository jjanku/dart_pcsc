High(er)-level Dart wrapper around the PC/SC C API for communication with
smart cards.

## Features

* send/receive APDUs to/from smart cards
* wait for cards & readers
* works on Linux, Windows

## Getting started

On Linux, install [pcsc-lite](https://pcsclite.apdu.fr/).
On Windows, no additional setup should be needed.

## Usage

See [example/dart_pcsc_example.dart](example/dart_pcsc_example.dart).

## Additional information

At the moment, not all functions provided by the C API are covered.
Pull requests are welcome.

MacOS support is missing, but it should be easy to add. Help wanted.
