# PulseModem A

"PulseModem A" is an APRS client, that reads and reports APRS location and messages.

APRS is a digital communications protocol that can exchanges information among large number of stations both local and global.

## Download PulseModem A at AppStore now

* [PulseModem A at AppStore](https://itunes.apple.com/us/app/pulsemodem-a/id1424005647?mt=8&ign-mpt=uo%3D4)

## What is APRS

APRS stands for: Automatic Packet Reporting System.

APRS is a digital communications protocol that can exchanges information among large number of stations both local and global.

You as a licensed Amateur Radio operators can send and receive APRS location and message in 2 ways:

* Direct to the APRS-IS Network
* Radio Frequency with Amateur Radio at 2 meter band at 144MHz

### APRS-IS network

You can connect directly with the global APRS-IS network by Internet. Messages reaching the gateways will be relayed to the APRS-IS feed.

```
The PulseModem A will display messages from the APRS-IS, 100km around your current location.

```

### Radio Frequency with Amateur Radio at 2 meter band at 144MHz

APRS messages are short in length, in less than 100 bytes.

Messages are encoded in AX.25 protocol with Bell 202 AFSK modulation.

PulseModem A will play the encoded message through the audio port of your iOS device, to your radio.


## Roadmap for PulseModem A

The "A" of "PulseModem A" stands for APRS. Future versions of PulseModem will decode other formats.

PulseModem A aims to be the finest RF telemetry APRS & virtual TNC on iOS. The app will be updated as much as possible.

Below are the current roadmap of PulseModem A.

### 1. BLE Hardware Companion & PTT triggers

Given that the 3.5mm TRRS audio port has been removed from the current line-up of iOS devices, PulseModem A is expected to have a companion hardware in BLE4 for easy interface with commonly available VHF radios.

```
High on the list would be a proper PTT triggers for Baofeng, Kenwood & Yaesu radios.
```

### 2. Updated icons

The original APRS specifications have a limited set of icons.

That has been changed a few years ago, which gave rises to almost 1000+. PulseModem A aims to provide a more comprehensive support.

### 3. Better Messaging Parsing

Given that this is the first release of PulseModem A, there could be a myriad combinations of APRS messages that could trigger errors.

Along with other kinds of malformed messages from network or software errors...

This app will be updated with better message handling.

 [And more...](https://www.pulsemodem.com/pages/roadmap/) 

## Authors

The PulseModem A is developed by **Pulsely** [www.pulsely.com](https://www.pulsely.com/).  
(C) 2018 by Pulsely  
leveraging the hard work from these forward thinkers, developers & designers:

**APRS**  
Bob Bruninga  
APRS is a registered trademark of Bob Bruninga. He is the creator of the APRS system.

**APRS Library**  
multimon - original program to decode radio transmissions  
(C) 1996/1997 by Tom Sailer HB9JNX/AE4WA

**multimon-ng** - great improvment of multimon, for the RF Receive function  
[https://github.com/EliasOenal/multimon-ng](https://github.com/EliasOenal/multimon-ng)  
(C) 2012-2018 by Elias Oenal

**ax25beacon** - AX.25 beacon packet generator for APRS  
[https://github.com/fsphil/ax25beacon](https://github.com/fsphil/ax25beacon)  
Philip Heron phil@sanslogic.co.uk

**libfap** - ARPS parser  
[http://www.pakettiradio.net/libfap/](http://www.pakettiradio.net/libfap/)  
Originally written by Tapio Sokura, OH2KKU and Heikki Hannikainen, OH7LZB and ported to C by Tapio Aaltonen, OH2GVE

### iOS components
**EZAudio** - iOS and macOS audio visualization framework built upon Core Audio  
[https://github.com/syedhali/EZAudio](https://github.com/syedhali/EZAudio)  
by Syed Haris Ali

**TPCircularBuffer** - A simple, fast circular buffer implementation  
[https://github.com/michaeltyson/TPCircularBuffer](https://github.com/michaeltyson/TPCircularBuffer)  
by Michael Tyson

**AFNetworking** - delightful networking framework for iOS, macOS, watchOS, and tvOS  
[https://github.com/AFNetworking/AFNetworking](https://github.com/AFNetworking/AFNetworking)  
AFNetworking is owned and maintained by the Alamofire Software Foundation.  
AFNetworking was originally created by Scott Raymond and Mattt Thompson in the development of Gowalla for iPhone.

**DZNEmptyDataSet** - drop-in UITableView/UICollectionView superclass category for showing empty datasets  
[https://github.com/dzenbot/DZNEmptyDataSet](https://github.com/dzenbot/DZNEmptyDataSet)  
Copyright (c) 2016 Ignacio Romero Zurbuchen iromero@dzen.cl

**UICKeyChainStore** - simple wrapper for Keychain on iOS, watchOS, tvOS and macOS
[https://github.com/kishikawakatsumi/UICKeyChainStore](https://github.com/kishikawakatsumi/UICKeyChainStore) 
By kishikawa katsumi, kishikawakatsumi@mac.com

**RMessage** - crisp in-app notification/message banner built in ObjC\
https://github.com/donileo/RMessage\
Copyright (c) 2016 TouchSix, Inc. Adonis Peralta

**Onboard** - easily create a beautiful and engaging onboarding experience\
https://github.com/mamaral/Onboard
Copyright (c) 2014 Michael Amaral

**Chameleon** - lightweight, yet powerful, color framework for iOS\
https://github.com/viccalexander/Chameleon
by Vicc Alexander

**CocoaAsyncSocket** - Asynchronous socket networking library for Mac and iOS\
https://github.com/robbiehanson/CocoaAsyncSocket
Copyright (c) 2017, Deusty, LLC

### Graphics
**aprs-symbols**\
aprs.fi APRS symbol set, high-resolution, vector  
https://github.com/hessu/aprs-symbols  
by Heikki Hannikainen

**App icon:**\
Icon by By Oksana Latysheva, UA  
https://thenounproject.com/search/?q=chat&i=799081

**Transmit icon:**\ 
Power by AlfredoCreates.com/icons & Flaticondesign.com from the Noun Project  
https://thenounproject.com/search/?q=power&i=328033

**Map icon:**\
Map by Adrien Coquet from the Noun Project  
https://thenounproject.com/search/?q=map&i=1854989

**List icon:**\
List by Iconstock from the Noun Project https://thenounproject.com/search/?q=list&i=1286740

**Info icon:**\
about by Hector from the Noun Project  \
https://thenounproject.com/search/?q=about&i=559928

**Cloud icon:**\
servers by Jony from the Noun Project\
https://thenounproject.com/search/?q=server&i=1866281

**Sleeping cat:**\
Sleeping Cat by parkjisun from the Noun Project\
https://thenounproject.com/term/sleeping-cat/196644/

**Apple Icon:**\
Apple by Milinda Courey from the Noun Project\
https://thenounproject.com/search/?q=apple&i=231811


## Missing Acknowledgements?

We try not to missing anyone, but if you know someone is missing, please contact PulseModem A via its github repo.

## License

This project is licensed under the GPL License - see the [LICENSE](LICENSE) file for details

