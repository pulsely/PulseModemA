//
//  CtyDat.m
//  PulseCQ
//
//  Created by Pulsely on 11/30/16.
//  Copyright © 2016 Pulsely. All rights reserved.
//

#import "CtyDat.h"

@implementation CtyDat
@synthesize fields, dxcc;

+ (id)sharedManager {
    static CtyDat *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (id)init {
    if (self = [super init]) {
        self.fields = @[@"name", @"cq", @"itu", @"cont", @"lat", @"lon", @"utcoff", @"prefix"];
        
    }
    return self;
}

- (void)loadDXCC {
    self.countryareaFlagDict = [NSMutableDictionary dictionary];
    
    [self.countryareaFlagDict setObject: @"AF" forKey: @"Afghanistan"];
    [self.countryareaFlagDict setObject: @"IT" forKey: @"African Italy"];
    [self.countryareaFlagDict setObject: @"MU" forKey: @"Agalega & St. Brandon"];
    [self.countryareaFlagDict setObject: @"AX" forKey: @"Aland Islands"];
    [self.countryareaFlagDict setObject: @"US" forKey: @"Alaska"];
    [self.countryareaFlagDict setObject: @"AL" forKey: @"Albania"];
    [self.countryareaFlagDict setObject: @"DZ" forKey: @"Algeria"];
    [self.countryareaFlagDict setObject: @"AS" forKey: @"American Samoa"];
    [self.countryareaFlagDict setObject: @"TF" forKey: @"Amsterdam & St. Paul Is."];
    [self.countryareaFlagDict setObject: @"IN" forKey: @"Andaman & Nicobar Is."];
    [self.countryareaFlagDict setObject: @"AD" forKey: @"Andorra"];
    [self.countryareaFlagDict setObject: @"AO" forKey: @"Angola"];
    [self.countryareaFlagDict setObject: @"AI" forKey: @"Anguilla"];
    [self.countryareaFlagDict setObject: @"GQ" forKey: @"Annobon Island"];
    [self.countryareaFlagDict setObject: @"AQ" forKey: @"Antarctica"];
    [self.countryareaFlagDict setObject: @"AG" forKey: @"Antigua & Barbuda"];
    [self.countryareaFlagDict setObject: @"AR" forKey: @"Argentina"];
    [self.countryareaFlagDict setObject: @"AM" forKey: @"Armenia"];
    [self.countryareaFlagDict setObject: @"AW" forKey: @"Aruba"];
    [self.countryareaFlagDict setObject: @"AC" forKey: @"Ascension Island"];
    [self.countryareaFlagDict setObject: @"RU" forKey: @"Asiatic Russia"];
    [self.countryareaFlagDict setObject: @"TR" forKey: @"Asiatic Turkey"];
    [self.countryareaFlagDict setObject: @"PF" forKey: @"Austral Islands"];
    [self.countryareaFlagDict setObject: @"AU" forKey: @"Australia"];
    [self.countryareaFlagDict setObject: @"AT" forKey: @"Austria"];
    [self.countryareaFlagDict setObject: @"VE" forKey: @"Aves Island"];
    [self.countryareaFlagDict setObject: @"AZ" forKey: @"Azerbaijan"];
    [self.countryareaFlagDict setObject: @"PT-20" forKey: @"Azores"];
    [self.countryareaFlagDict setObject: @"BS" forKey: @"Bahamas"];
    [self.countryareaFlagDict setObject: @"BH" forKey: @"Bahrain"];
    [self.countryareaFlagDict setObject: @"US" forKey: @"Baker & Howland Islands"];
    [self.countryareaFlagDict setObject: @"IB" forKey: @"Balearic Islands"];
    [self.countryareaFlagDict setObject: @"KI" forKey: @"Banaba Island"];
    [self.countryareaFlagDict setObject: @"BD" forKey: @"Bangladesh"];
    [self.countryareaFlagDict setObject: @"BB" forKey: @"Barbados"];
    [self.countryareaFlagDict setObject: @"NO" forKey: @"Bear Island"];
    [self.countryareaFlagDict setObject: @"BY" forKey: @"Belarus"];
    [self.countryareaFlagDict setObject: @"BE" forKey: @"Belgium"];
    [self.countryareaFlagDict setObject: @"BZ" forKey: @"Belize"];
    [self.countryareaFlagDict setObject: @"BJ" forKey: @"Benin"];
    [self.countryareaFlagDict setObject: @"BM" forKey: @"Bermuda"];
    [self.countryareaFlagDict setObject: @"BT" forKey: @"Bhutan"];
    [self.countryareaFlagDict setObject: @"BO" forKey: @"Bolivia"];
    [self.countryareaFlagDict setObject: @"BQ-BO" forKey: @"Bonaire"];
    [self.countryareaFlagDict setObject: @"BA" forKey: @"Bosnia-Herzegovina"];
    [self.countryareaFlagDict setObject: @"BW" forKey: @"Botswana"];
    [self.countryareaFlagDict setObject: @"BV" forKey: @"Bouvet"];
    [self.countryareaFlagDict setObject: @"BR" forKey: @"Brazil"];
    [self.countryareaFlagDict setObject: @"VG" forKey: @"British Virgin Islands"];
    [self.countryareaFlagDict setObject: @"BN" forKey: @"Brunei Darussalam"];
    [self.countryareaFlagDict setObject: @"BG" forKey: @"Bulgaria"];
    [self.countryareaFlagDict setObject: @"BF" forKey: @"Burkina Faso"];
    [self.countryareaFlagDict setObject: @"BI" forKey: @"Burundi"];
    [self.countryareaFlagDict setObject: @"KH" forKey: @"Cambodia"];
    [self.countryareaFlagDict setObject: @"CM" forKey: @"Cameroon"];
    [self.countryareaFlagDict setObject: @"CA" forKey: @"Canada"];
    [self.countryareaFlagDict setObject: @"ES-CN" forKey: @"Canary Islands"];
    [self.countryareaFlagDict setObject: @"CV" forKey: @"Cape Verde"];
    [self.countryareaFlagDict setObject: @"KY" forKey: @"Cayman Islands"];
    [self.countryareaFlagDict setObject: @"CF" forKey: @"Central African Republic"];
    [self.countryareaFlagDict setObject: @"KI" forKey: @"Central Kiribati"];
    [self.countryareaFlagDict setObject: @"ES" forKey: @"Ceuta & Melilla"];
    [self.countryareaFlagDict setObject: @"TD" forKey: @"Chad"];
    [self.countryareaFlagDict setObject: @"MU" forKey: @"Chagos Islands"];
    [self.countryareaFlagDict setObject: @"NZ" forKey: @"Chatham Islands"];
    [self.countryareaFlagDict setObject: @"FR" forKey: @"Chesterfield Islands"];
    [self.countryareaFlagDict setObject: @"CL" forKey: @"Chile"];
    [self.countryareaFlagDict setObject: @"CN" forKey: @"China"];
    [self.countryareaFlagDict setObject: @"CX" forKey: @"Christmas Island"];
    [self.countryareaFlagDict setObject: @"FR" forKey: @"Clipperton Island"];
    [self.countryareaFlagDict setObject: @"CC" forKey: @"Cocos (Keeling) Islands"];
    [self.countryareaFlagDict setObject: @"CR" forKey: @"Cocos Island"];
    [self.countryareaFlagDict setObject: @"CO" forKey: @"Colombia"];
    [self.countryareaFlagDict setObject: @"KM" forKey: @"Comoros"];
    [self.countryareaFlagDict setObject: @"FJ" forKey: @"Conway Reef"];
    [self.countryareaFlagDict setObject: @"FR" forKey: @"Corsica"];
    [self.countryareaFlagDict setObject: @"CR" forKey: @"Costa Rica"];
    [self.countryareaFlagDict setObject: @"CI" forKey: @"Cote d'Ivoire"];
    [self.countryareaFlagDict setObject: @"GR" forKey: @"Crete"];
    [self.countryareaFlagDict setObject: @"HR" forKey: @"Croatia"];
    [self.countryareaFlagDict setObject: @"FR" forKey: @"Crozet Island"];
    [self.countryareaFlagDict setObject: @"CU" forKey: @"Cuba"];
    [self.countryareaFlagDict setObject: @"CW" forKey: @"Curacao"];
    [self.countryareaFlagDict setObject: @"CY" forKey: @"Cyprus"];
    [self.countryareaFlagDict setObject: @"CZ" forKey: @"Czech Republic"];
    [self.countryareaFlagDict setObject: @"KP" forKey: @"DPR of Korea"];
    [self.countryareaFlagDict setObject: @"CD" forKey: @"Dem. Rep. of the Congo"];
    [self.countryareaFlagDict setObject: @"DK" forKey: @"Denmark"];
    [self.countryareaFlagDict setObject: @"PR" forKey: @"Desecheo Island"];
    [self.countryareaFlagDict setObject: @"DJ" forKey: @"Djibouti"];
    [self.countryareaFlagDict setObject: @"GR" forKey: @"Dodecanese"];
    [self.countryareaFlagDict setObject: @"DM" forKey: @"Dominica"];
    [self.countryareaFlagDict setObject: @"DO" forKey: @"Dominican Republic"];
    [self.countryareaFlagDict setObject: @"GB" forKey: @"Ducie Island"];
    [self.countryareaFlagDict setObject: @"MY" forKey: @"East Malaysia"];
    [self.countryareaFlagDict setObject: @"CL" forKey: @"Easter Island"];
    [self.countryareaFlagDict setObject: @"KI" forKey: @"Eastern Kiribati"];
    [self.countryareaFlagDict setObject: @"EC" forKey: @"Ecuador"];
    [self.countryareaFlagDict setObject: @"EG" forKey: @"Egypt"];
    [self.countryareaFlagDict setObject: @"SV" forKey: @"El Salvador"];
    [self.countryareaFlagDict setObject: @"GB" forKey: @"England"];
    [self.countryareaFlagDict setObject: @"GQ" forKey: @"Equatorial Guinea"];
    [self.countryareaFlagDict setObject: @"ER" forKey: @"Eritrea"];
    [self.countryareaFlagDict setObject: @"EE" forKey: @"Estonia"];
    [self.countryareaFlagDict setObject: @"ET" forKey: @"Ethiopia"];
    [self.countryareaFlagDict setObject: @"RU" forKey: @"European Russia"];
    [self.countryareaFlagDict setObject: @"TR" forKey: @"European Turkey"];
    [self.countryareaFlagDict setObject: @"GB" forKey: @"Falkland Islands"];
    [self.countryareaFlagDict setObject: @"FO" forKey: @"Faroe Islands"];
    [self.countryareaFlagDict setObject: @"DE" forKey: @"Fed. Rep. of Germany"];
    [self.countryareaFlagDict setObject: @"BR" forKey: @"Fernando de Noronha"];
    [self.countryareaFlagDict setObject: @"FJ" forKey: @"Fiji"];
    [self.countryareaFlagDict setObject: @"FI" forKey: @"Finland"];
    [self.countryareaFlagDict setObject: @"FR" forKey: @"France"];
    [self.countryareaFlagDict setObject: @"RU" forKey: @"Franz Josef Land"];
    [self.countryareaFlagDict setObject: @"GF" forKey: @"French Guiana"];
    [self.countryareaFlagDict setObject: @"PF" forKey: @"French Polynesia"];
    [self.countryareaFlagDict setObject: @"GA" forKey: @"Gabon"];
    [self.countryareaFlagDict setObject: @"EC" forKey: @"Galapagos Islands"];
    [self.countryareaFlagDict setObject: @"GE" forKey: @"Georgia"];
    [self.countryareaFlagDict setObject: @"GH" forKey: @"Ghana"];
    [self.countryareaFlagDict setObject: @"GI" forKey: @"Gibraltar"];
    [self.countryareaFlagDict setObject: @"TF" forKey: @"Glorioso Islands"];
    [self.countryareaFlagDict setObject: @"GR" forKey: @"Greece"];
    [self.countryareaFlagDict setObject: @"GL" forKey: @"Greenland"];
    [self.countryareaFlagDict setObject: @"GD" forKey: @"Grenada"];
    [self.countryareaFlagDict setObject: @"GP" forKey: @"Guadeloupe"];
    [self.countryareaFlagDict setObject: @"GU" forKey: @"Guam"];
    [self.countryareaFlagDict setObject: @"US" forKey: @"Guantanamo Bay"];
    [self.countryareaFlagDict setObject: @"GT" forKey: @"Guatemala"];
    [self.countryareaFlagDict setObject: @"GG" forKey: @"Guernsey"];
    [self.countryareaFlagDict setObject: @"GN" forKey: @"Guinea"];
    [self.countryareaFlagDict setObject: @"GW" forKey: @"Guinea-Bissau"];
    [self.countryareaFlagDict setObject: @"GY" forKey: @"Guyana"];
    [self.countryareaFlagDict setObject: @"HT" forKey: @"Haiti"];
    [self.countryareaFlagDict setObject: @"US-HI" forKey: @"Hawaii"];
    [self.countryareaFlagDict setObject: @"AU" forKey: @"Heard Island"];
    [self.countryareaFlagDict setObject: @"HN" forKey: @"Honduras"];
    [self.countryareaFlagDict setObject: @"HK" forKey: @"Hong Kong"];
    [self.countryareaFlagDict setObject: @"HU" forKey: @"Hungary"];
    [self.countryareaFlagDict setObject: @"UN" forKey: @"ITU HQ"];
    [self.countryareaFlagDict setObject: @"IS" forKey: @"Iceland"];
    [self.countryareaFlagDict setObject: @"IN" forKey: @"India"];
    [self.countryareaFlagDict setObject: @"ID" forKey: @"Indonesia"];
    [self.countryareaFlagDict setObject: @"IR" forKey: @"Iran"];
    [self.countryareaFlagDict setObject: @"IQ" forKey: @"Iraq"];
    [self.countryareaFlagDict setObject: @"IE" forKey: @"Ireland"];
    [self.countryareaFlagDict setObject: @"IM" forKey: @"Isle of Man"];
    [self.countryareaFlagDict setObject: @"IL" forKey: @"Israel"];
    [self.countryareaFlagDict setObject: @"IT" forKey: @"Italy"];
    [self.countryareaFlagDict setObject: @"JM" forKey: @"Jamaica"];
    [self.countryareaFlagDict setObject: @"NO" forKey: @"Jan Mayen"];
    [self.countryareaFlagDict setObject: @"JP" forKey: @"Japan"];
    [self.countryareaFlagDict setObject: @"JE" forKey: @"Jersey"];
    [self.countryareaFlagDict setObject: @"US" forKey: @"Johnston Island"];
    [self.countryareaFlagDict setObject: @"JO" forKey: @"Jordan"];
    [self.countryareaFlagDict setObject: @"CL" forKey: @"Juan Fernandez Islands"];
    [self.countryareaFlagDict setObject: @"TF" forKey: @"Juan de Nova, Europa"];
    [self.countryareaFlagDict setObject: @"RU" forKey: @"Kaliningrad"];
    [self.countryareaFlagDict setObject: @"KZ" forKey: @"Kazakhstan"];
    [self.countryareaFlagDict setObject: @"KE" forKey: @"Kenya"];
    [self.countryareaFlagDict setObject: @"TF" forKey: @"Kerguelen Islands"];
    [self.countryareaFlagDict setObject: @"NZ" forKey: @"Kermadec Islands"];
    [self.countryareaFlagDict setObject: @"XK" forKey: @"Kosovo"];
    [self.countryareaFlagDict setObject: @"US" forKey: @"Kure Island"];
    [self.countryareaFlagDict setObject: @"KW" forKey: @"Kuwait"];
    [self.countryareaFlagDict setObject: @"KG" forKey: @"Kyrgyzstan"];
    [self.countryareaFlagDict setObject: @"IN" forKey: @"Lakshadweep Islands"];
    [self.countryareaFlagDict setObject: @"LA" forKey: @"Laos"];
    [self.countryareaFlagDict setObject: @"LV" forKey: @"Latvia"];
    [self.countryareaFlagDict setObject: @"LB" forKey: @"Lebanon"];
    [self.countryareaFlagDict setObject: @"LS" forKey: @"Lesotho"];
    [self.countryareaFlagDict setObject: @"LR" forKey: @"Liberia"];
    [self.countryareaFlagDict setObject: @"LY" forKey: @"Libya"];
    [self.countryareaFlagDict setObject: @"LI" forKey: @"Liechtenstein"];
    [self.countryareaFlagDict setObject: @"LT" forKey: @"Lithuania"];
    [self.countryareaFlagDict setObject: @"AU" forKey: @"Lord Howe Island"];
    [self.countryareaFlagDict setObject: @"LU" forKey: @"Luxembourg"];
    [self.countryareaFlagDict setObject: @"MO" forKey: @"Macao"];
    [self.countryareaFlagDict setObject: @"MK" forKey: @"Macedonia"];
    [self.countryareaFlagDict setObject: @"AU" forKey: @"Macquarie Island"];
    [self.countryareaFlagDict setObject: @"MG" forKey: @"Madagascar"];
    [self.countryareaFlagDict setObject: @"PT-30" forKey: @"Madeira Islands"];
    [self.countryareaFlagDict setObject: @"MW" forKey: @"Malawi"];
    [self.countryareaFlagDict setObject: @"MV" forKey: @"Maldives"];
    [self.countryareaFlagDict setObject: @"ML" forKey: @"Mali"];
    [self.countryareaFlagDict setObject: @"CO" forKey: @"Malpelo Island"];
    [self.countryareaFlagDict setObject: @"MT" forKey: @"Malta"];
    [self.countryareaFlagDict setObject: @"US" forKey: @"Mariana Islands"];
    [self.countryareaFlagDict setObject: @"PF" forKey: @"Marquesas Islands"];
    [self.countryareaFlagDict setObject: @"MH" forKey: @"Marshall Islands"];
    [self.countryareaFlagDict setObject: @"MQ" forKey: @"Martinique"];
    [self.countryareaFlagDict setObject: @"MR" forKey: @"Mauritania"];
    [self.countryareaFlagDict setObject: @"MU" forKey: @"Mauritius"];
    [self.countryareaFlagDict setObject: @"YT" forKey: @"Mayotte"];
    [self.countryareaFlagDict setObject: @"AU" forKey: @"Mellish Reef"];
    [self.countryareaFlagDict setObject: @"MX" forKey: @"Mexico"];
    [self.countryareaFlagDict setObject: @"FM" forKey: @"Micronesia"];
    [self.countryareaFlagDict setObject: @"US" forKey: @"Midway Island"];
    [self.countryareaFlagDict setObject: @"JP" forKey: @"Minami Torishima"];
    [self.countryareaFlagDict setObject: @"MD" forKey: @"Moldova"];
    [self.countryareaFlagDict setObject: @"MC" forKey: @"Monaco"];
    [self.countryareaFlagDict setObject: @"MN" forKey: @"Mongolia"];
    [self.countryareaFlagDict setObject: @"ME" forKey: @"Montenegro"];
    [self.countryareaFlagDict setObject: @"MS" forKey: @"Montserrat"];
    [self.countryareaFlagDict setObject: @"MA" forKey: @"Morocco"];
    [self.countryareaFlagDict setObject: @"GR" forKey: @"Mount Athos"];
    [self.countryareaFlagDict setObject: @"MZ" forKey: @"Mozambique"];
    [self.countryareaFlagDict setObject: @"MM" forKey: @"Myanmar"];
    [self.countryareaFlagDict setObject: @"NZ" forKey: @"N.Z. Subantarctic Is."];
    [self.countryareaFlagDict setObject: @"NA" forKey: @"Namibia"];
    [self.countryareaFlagDict setObject: @"NR" forKey: @"Nauru"];
    [self.countryareaFlagDict setObject: @"BQ" forKey: @"Navassa Island"];
    [self.countryareaFlagDict setObject: @"NP" forKey: @"Nepal"];
    [self.countryareaFlagDict setObject: @"NL" forKey: @"Netherlands"];
    [self.countryareaFlagDict setObject: @"NC" forKey: @"New Caledonia"];
    [self.countryareaFlagDict setObject: @"NZ" forKey: @"New Zealand"];
    [self.countryareaFlagDict setObject: @"NI" forKey: @"Nicaragua"];
    [self.countryareaFlagDict setObject: @"NE" forKey: @"Niger"];
    [self.countryareaFlagDict setObject: @"NG" forKey: @"Nigeria"];
    [self.countryareaFlagDict setObject: @"NU" forKey: @"Niue"];
    [self.countryareaFlagDict setObject: @"NF" forKey: @"Norfolk Island"];
    [self.countryareaFlagDict setObject: @"CK" forKey: @"North Cook Islands"];
    [self.countryareaFlagDict setObject: @"GB-NIR" forKey: @"Northern Ireland"];
    [self.countryareaFlagDict setObject: @"NO" forKey: @"Norway"];
    [self.countryareaFlagDict setObject: @"JP" forKey: @"Ogasawara"];
    [self.countryareaFlagDict setObject: @"OM" forKey: @"Oman"];
    [self.countryareaFlagDict setObject: @"PK" forKey: @"Pakistan"];
    [self.countryareaFlagDict setObject: @"PW" forKey: @"Palau"];
    [self.countryareaFlagDict setObject: @"PS" forKey: @"Palestine"];
    [self.countryareaFlagDict setObject: @"US" forKey: @"Palmyra & Jarvis Islands"];
    [self.countryareaFlagDict setObject: @"PA" forKey: @"Panama"];
    [self.countryareaFlagDict setObject: @"PG" forKey: @"Papua New Guinea"];
    [self.countryareaFlagDict setObject: @"PY" forKey: @"Paraguay"];
    [self.countryareaFlagDict setObject: @"PE" forKey: @"Peru"];
    [self.countryareaFlagDict setObject: @"NO" forKey: @"Peter 1 Island"];
    [self.countryareaFlagDict setObject: @"PH" forKey: @"Philippines"];
    [self.countryareaFlagDict setObject: @"PN" forKey: @"Pitcairn Island"];
    [self.countryareaFlagDict setObject: @"PL" forKey: @"Poland"];
    [self.countryareaFlagDict setObject: @"PT" forKey: @"Portugal"];
    [self.countryareaFlagDict setObject: @"ZA" forKey: @"Pr. Edward & Marion Is."];
    [self.countryareaFlagDict setObject: @"TW" forKey: @"Pratas Island"];
    [self.countryareaFlagDict setObject: @"PR" forKey: @"Puerto Rico"];
    [self.countryareaFlagDict setObject: @"QA" forKey: @"Qatar"];
    [self.countryareaFlagDict setObject: @"KR" forKey: @"Republic of Korea"];
    [self.countryareaFlagDict setObject: @"SS" forKey: @"Republic of South Sudan"];
    [self.countryareaFlagDict setObject: @"CG" forKey: @"Republic of the Congo"];
    [self.countryareaFlagDict setObject: @"RE" forKey: @"Reunion Island"];
    [self.countryareaFlagDict setObject: @"MX" forKey: @"Revillagigedo"];
    [self.countryareaFlagDict setObject: @"MU" forKey: @"Rodriguez Island"];
    [self.countryareaFlagDict setObject: @"RO" forKey: @"Romania"];
    [self.countryareaFlagDict setObject: @"FJ" forKey: @"Rotuma Island"];
    [self.countryareaFlagDict setObject: @"RW" forKey: @"Rwanda"];
    [self.countryareaFlagDict setObject: @"BQ-SE" forKey: @"Saba & St. Eustatius"];
    [self.countryareaFlagDict setObject: @"CA" forKey: @"Sable Island"];
    [self.countryareaFlagDict setObject: @"WS" forKey: @"Samoa"];
    [self.countryareaFlagDict setObject: @"CO-SAP" forKey: @"San Andres & Providencia"];
    [self.countryareaFlagDict setObject: @"CL" forKey: @"San Felix & San Ambrosio"];
    [self.countryareaFlagDict setObject: @"SM" forKey: @"San Marino"];
    [self.countryareaFlagDict setObject: @"ST" forKey: @"Sao Tome & Principe"];
    [self.countryareaFlagDict setObject: @"IT-88" forKey: @"Sardinia"];
    [self.countryareaFlagDict setObject: @"SA" forKey: @"Saudi Arabia"];
    [self.countryareaFlagDict setObject: @"UN" forKey: @"Scarborough Reef"];
    [self.countryareaFlagDict setObject: @"GB-SCT" forKey: @"Scotland"];
    [self.countryareaFlagDict setObject: @"SN" forKey: @"Senegal"];
    [self.countryareaFlagDict setObject: @"RS" forKey: @"Serbia"];
    [self.countryareaFlagDict setObject: @"SC" forKey: @"Seychelles"];
    [self.countryareaFlagDict setObject: @"GB-ZET" forKey: @"Shetland Islands"];
    [self.countryareaFlagDict setObject: @"IT-82" forKey: @"Sicily"];
    [self.countryareaFlagDict setObject: @"SL" forKey: @"Sierra Leone"];
    [self.countryareaFlagDict setObject: @"SG" forKey: @"Singapore"];
    [self.countryareaFlagDict setObject: @"SX" forKey: @"Sint Maarten"];
    [self.countryareaFlagDict setObject: @"SK" forKey: @"Slovak Republic"];
    [self.countryareaFlagDict setObject: @"SI" forKey: @"Slovenia"];
    [self.countryareaFlagDict setObject: @"SB" forKey: @"Solomon Islands"];
    [self.countryareaFlagDict setObject: @"SO" forKey: @"Somalia"];
    [self.countryareaFlagDict setObject: @"ZA" forKey: @"South Africa"];
    [self.countryareaFlagDict setObject: @"CK" forKey: @"South Cook Islands"];
    [self.countryareaFlagDict setObject: @"GS" forKey: @"South Georgia Island"];
    [self.countryareaFlagDict setObject: @"AQ" forKey: @"South Orkney Islands"];
    [self.countryareaFlagDict setObject: @"GS" forKey: @"South Sandwich Islands"];
    [self.countryareaFlagDict setObject: @"AQ" forKey: @"South Shetland Islands"];
    [self.countryareaFlagDict setObject: @"MT" forKey: @"Sov Mil Order of Malta"];
    [self.countryareaFlagDict setObject: @"ES" forKey: @"Spain"];
    [self.countryareaFlagDict setObject: @"UN" forKey: @"Spratly Islands"];
    [self.countryareaFlagDict setObject: @"LK" forKey: @"Sri Lanka"];
    [self.countryareaFlagDict setObject: @"BL" forKey: @"St. Barthelemy"];
    [self.countryareaFlagDict setObject: @"SH" forKey: @"St. Helena"];
    [self.countryareaFlagDict setObject: @"KN" forKey: @"St. Kitts & Nevis"];
    [self.countryareaFlagDict setObject: @"LC" forKey: @"St. Lucia"];
    [self.countryareaFlagDict setObject: @"FR" forKey: @"St. Martin"];
    [self.countryareaFlagDict setObject: @"US" forKey: @"St. Paul Island"];
    [self.countryareaFlagDict setObject: @"BR" forKey: @"St. Peter & St. Paul"];
    [self.countryareaFlagDict setObject: @"FR" forKey: @"St. Pierre & Miquelon"];
    [self.countryareaFlagDict setObject: @"VC" forKey: @"St. Vincent"];
    [self.countryareaFlagDict setObject: @"SD" forKey: @"Sudan"];
    [self.countryareaFlagDict setObject: @"SR" forKey: @"Suriname"];
    [self.countryareaFlagDict setObject: @"NO" forKey: @"Svalbard"];
    [self.countryareaFlagDict setObject: @"AS" forKey: @"Swains Island"];
    [self.countryareaFlagDict setObject: @"SZ" forKey: @"Swaziland"];
    [self.countryareaFlagDict setObject: @"SE" forKey: @"Sweden"];
    [self.countryareaFlagDict setObject: @"CH" forKey: @"Switzerland"];
    [self.countryareaFlagDict setObject: @"SY" forKey: @"Syria"];
    [self.countryareaFlagDict setObject: @"TW" forKey: @"Taiwan"];
    [self.countryareaFlagDict setObject: @"TJ" forKey: @"Tajikistan"];
    [self.countryareaFlagDict setObject: @"TZ" forKey: @"Tanzania"];
    [self.countryareaFlagDict setObject: @"SB" forKey: @"Temotu Province"];
    [self.countryareaFlagDict setObject: @"TH" forKey: @"Thailand"];
    [self.countryareaFlagDict setObject: @"GM" forKey: @"The Gambia"];
    [self.countryareaFlagDict setObject: @"TL" forKey: @"Timor - Leste"];
    [self.countryareaFlagDict setObject: @"TG" forKey: @"Togo"];
    [self.countryareaFlagDict setObject: @"TK" forKey: @"Tokelau Islands"];
    [self.countryareaFlagDict setObject: @"TO" forKey: @"Tonga"];
    [self.countryareaFlagDict setObject: @"BR" forKey: @"Trindade & Martim Vaz"];
    [self.countryareaFlagDict setObject: @"TT" forKey: @"Trinidad & Tobago"];
    [self.countryareaFlagDict setObject: @"SH-TA" forKey: @"Tristan da Cunha & Gough"];
    [self.countryareaFlagDict setObject: @"TF" forKey: @"Tromelin Island"];
    [self.countryareaFlagDict setObject: @"TN" forKey: @"Tunisia"];
    [self.countryareaFlagDict setObject: @"TM" forKey: @"Turkmenistan"];
    [self.countryareaFlagDict setObject: @"TC" forKey: @"Turks & Caicos Islands"];
    [self.countryareaFlagDict setObject: @"TV" forKey: @"Tuvalu"];
    [self.countryareaFlagDict setObject: @"GB" forKey: @"UK Base Areas on Cyprus"];
    [self.countryareaFlagDict setObject: @"US" forKey: @"US Virgin Islands"];
    [self.countryareaFlagDict setObject: @"UG" forKey: @"Uganda"];
    [self.countryareaFlagDict setObject: @"UA" forKey: @"Ukraine"];
    [self.countryareaFlagDict setObject: @"AE" forKey: @"United Arab Emirates"];
    [self.countryareaFlagDict setObject: @"UN" forKey: @"United Nations HQ"];
    [self.countryareaFlagDict setObject: @"US" forKey: @"United States"];
    [self.countryareaFlagDict setObject: @"UY" forKey: @"Uruguay"];
    [self.countryareaFlagDict setObject: @"UZ" forKey: @"Uzbekistan"];
    [self.countryareaFlagDict setObject: @"VU" forKey: @"Vanuatu"];
    [self.countryareaFlagDict setObject: @"VA" forKey: @"Vatican City"];
    [self.countryareaFlagDict setObject: @"VE" forKey: @"Venezuela"];
    [self.countryareaFlagDict setObject: @"UN" forKey: @"Vienna Intl Ctr"];
    [self.countryareaFlagDict setObject: @"VN" forKey: @"Vietnam"];
    [self.countryareaFlagDict setObject: @"US" forKey: @"Wake Island"];
    [self.countryareaFlagDict setObject: @"GB-WLS" forKey: @"Wales"];
    [self.countryareaFlagDict setObject: @"TF" forKey: @"Wallis & Futuna Islands"];
    [self.countryareaFlagDict setObject: @"MY" forKey: @"West Malaysia"];
    [self.countryareaFlagDict setObject: @"KI" forKey: @"Western Kiribati"];
    [self.countryareaFlagDict setObject: @"EH" forKey: @"Western Sahara"];
    [self.countryareaFlagDict setObject: @"AU" forKey: @"Willis Island"];
    [self.countryareaFlagDict setObject: @"YE" forKey: @"Yemen"];
    [self.countryareaFlagDict setObject: @"ZM" forKey: @"Zambia"];
    [self.countryareaFlagDict setObject: @"ZW" forKey: @"Zimbabwe"];

    
    self.dxcc = [NSMutableDictionary dictionary];
    self.country_array = [NSMutableArray array];
    
    NSString *cty_dat_filepath = [[NSBundle mainBundle] pathForResource: @"cty" ofType:@"dat"];
    
    NSError *error;
    NSString *fileContents = [NSString stringWithContentsOfFile: cty_dat_filepath
                                                       encoding: NSUTF8StringEncoding
                                                          error: &error];
    if (error) {
        //LOG_GENERAL( 0, @"Error reading file: %@", error.localizedDescription);
    } else {
        // maybe for debugging...
        //LOG_GENERAL( 0, @"contents: %@", fileContents);

        NSArray *lines = [fileContents componentsSeparatedByString:@"\n"];
        
        int line_count = 0;
        
        NSString *main_prefix = nil;
        NSString *main_country = nil;
        
        for (NSString *line in lines) {
            if (![line hasPrefix: @" "]) {
                //LOG_GENERAL( 0, @"%@", line);
                
                NSArray *line_of_fields = [line componentsSeparatedByString: @":"];
                //LOG_GENERAL( 0, @"%@", line_of_fields);

                if ( ([line_of_fields count] -1) == [self.fields count]) {
                    NSMutableDictionary *d = [NSMutableDictionary dictionary];
                    
                    int count = 0;
                    for (NSString *key in self.fields) {
                        
                        
                        
                        [d setObject: [[line_of_fields objectAtIndex: count] stringByTrimmingCharactersInSet:  [NSCharacterSet whitespaceAndNewlineCharacterSet]]
                              forKey: key];
                        count++;
                    }
                    //LOG_GENERAL( 0, @"d %@", [d objectForKey: @"prefix"]);
                    
                    main_prefix = [[d objectForKey: @"prefix"] stringByTrimmingCharactersInSet:  [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    main_country = [[d objectForKey: @"name"] stringByTrimmingCharactersInSet:  [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    
                    [self.dxcc setObject: d forKey: main_prefix];
                    [self.country_array addObject: main_prefix];
                } else {
                    //LOG_GENERAL( 0, @"len not matched for %@", line);
                }
            } else {
                
                // rstrip , and ;
                NSString *trimmed_line = [line stringByTrimmingCharactersInSet:
                                                                    [NSCharacterSet whitespaceAndNewlineCharacterSet]];

                
                if ([line hasSuffix: @";"]) {
                    trimmed_line = [trimmed_line substringWithRange:NSMakeRange(0, [line length] - 1)];
                }
                if ([line hasSuffix: @","]) {
                    trimmed_line = [trimmed_line substringWithRange:NSMakeRange(0, [line length] - 1)];
                }
                if ([line hasSuffix: @";"]) {
                    trimmed_line = [trimmed_line substringWithRange:NSMakeRange(0, [line length] - 1)];
                }

                NSArray *minor_dxcc_array = [trimmed_line componentsSeparatedByString: @","];
                
                for (NSString *minor_dxcc in minor_dxcc_array) {
                    NSDictionary *d = @{ @"name" : main_country };
                    
                    NSMutableDictionary *dd = [NSMutableDictionary dictionaryWithDictionary: d];
                    
                    NSString *minor_dxcc_trimmed = [minor_dxcc stringByTrimmingCharactersInSet:  [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    
                    if ([minor_dxcc_trimmed length] > 0) {
                        [self.dxcc setObject: dd forKey: minor_dxcc_trimmed];
                        
                        if (![main_prefix isEqualToString: minor_dxcc_trimmed]) {
                            [self.country_array addObject: minor_dxcc_trimmed];
                        }
                    }
                    
                }
                
                //LOG_GENERAL( 0, @"%@", minor_dxcc_array);
            }
            line_count++;
        }
        //LOG_GENERAL(  0, @"Total line count: %d", line_count);
    }
}

- (NSString *)countryareaOfCallSign:(NSString *)callsign {
    //bool hasprefix = NO;
    
    NSString *match = nil;
    
    for (int i = 0; i < [self.country_array count]; i++) {
        NSString *match = [self.country_array objectAtIndex: i];
        //LOG_GENERAL( 0, @"match: %@", match);

        if ([callsign hasPrefix: match]) {
            match = [[self.dxcc objectForKey: match] objectForKey: @"name"];
            return match;
        }
    }
    
    // overwrite error with Taiwan BX prefix
    if ([callsign hasPrefix: @"BX"]) {
        return @"Taiwan";
    }
    
    return match;
}

- (NSString *)countryareaCodeOfCallSign:(NSString *)callsign {
    if ([self countryareaOfCallSign: callsign] != nil) {
        return [self.countryareaFlagDict objectForKey: [self countryareaOfCallSign: callsign]];
    } else {
        return nil;
    }
}

@end
