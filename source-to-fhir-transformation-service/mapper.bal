import ballerina/log;
import ballerina/http;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.uscore501;
import ballerinax/health.fhir.r4.validator;
import ballerina/time;
// import ballerina/io;
// import ballerina/data.jsondata;


# Mapper function to map health data to FHIR resources
#
# + cdcEvent - CdcEvent
# + return - mapped HealthDataEvent or error

public isolated function mapCdcToHealthData(CdcEvent cdcEvent) returns HealthDataEvent|error {
    
    json payload = cdcEvent?.payload.toJson();
    HealthDataEvent event = {
        eventId: "",
        timestamp: (<int> check payload.'source.ts_ms).toString(),
        dataType: <string> check payload.'source.'table,
        payload: <json> check payload.after
    };
    return event;
}

# Mapper function to map kafka event to CDC Record
#
# + eventId - event Identifier
# + consumerRecordJson - Kafka event message
# + return - mapped HealthDataEvent or error

public isolated function mapConsumerRecordToCdcEvent(string eventId, json consumerRecordJson) returns CdcEvent|error {
        
    string operation = <string> check consumerRecordJson.payload.op;
    anydata payload = (operation == "d") ? check consumerRecordJson.payload.before: check consumerRecordJson.payload.after;

    CdcEvent cdcEvent = {
        eventId: eventId,
        timestamp: (<int> check consumerRecordJson.payload.'source.ts_ms).toString(),
        schema: check consumerRecordJson.schema,
        dataType: <string> check consumerRecordJson.payload.'source.'table,
        operation: operation,
        payload: payload
    };
    return cdcEvent;    
}



# Mapper function to map health data to FHIR resources
#
# + dataType - health data type
# + payload - payload to be mapped
# + return - mapped FHIR resource or error
public isolated function mapToFhir(string dataType, anydata payload) returns anydata|r4:FHIRError {
    match dataType {
        "patients" => {
            Patient|error patientData = payload.cloneWithType();
            if patientData is error {
                return r4:createFHIRError("Error occurred while cloning the payload", r4:ERROR, r4:INVALID);
            }
            uscore501:USCorePatientProfile fhirPayload = mapPatient(patientData);
            log:printInfo(string `fhir before validation: ${fhirPayload.toJsonString()}`, fhirPayload = fhirPayload);
            r4:FHIRValidationError? validate = validator:validate(fhirPayload, uscore501:USCorePatientProfile);
            if validate is r4:FHIRValidationError {
                return r4:createFHIRError(validate.message(), r4:ERROR, r4:INVALID, cause = validate.cause(), errorType = r4:VALIDATION_ERROR, httpStatusCode = http:STATUS_BAD_REQUEST);
            }
            return fhirPayload;
        }
        _ => {
            return r4:createFHIRError("Invalid data type '" + dataType + "'", r4:ERROR, r4:INVALID);
        }
    }
}

# Dedicated function to map patient data to US Core Patient Profile
#
# + payload - patient data in custom format
# + return - US Core Patient Profile
public isolated function mapPatient(Patient payload) returns uscore501:USCorePatientProfile => {
    id: payload.SUBJECT_ID,
    meta: {
        profile: [uscore501:PROFILE_BASE_USCOREPATIENTPROFILE]
    },
    extension: [
            {
                url: "http://hl7.org/fhir/us/core/StructureDefinition/us-core-race",
                extension: [
                    {
                        url: "ombCategory",
                        valueCoding: {
                            system: "urn:oid:2.16.840.1.113883.6.238",
                            code: payload.RACE_CD,
                            display: payload.RACE_NAME
                        }
                    },
                    {
                        "url": "text",
                        "valueString": payload.RACE_NAME
                    }
                ]
            },
            {
                url: "http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity",
                extension: [
                    {
                        url: "ombCategory",
                        valueCoding: {
                            system: "urn:oid:2.16.840.1.113883.6.238",
                            code: payload.ETH_CD,
                            display: payload.ETH_NAME
                        }
                    },
                    {
                        "url": "text",
                        "valueString": payload.ETH_NAME
                    }

                ]
            },
            {
                url: "http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex",
                valueCode: payload.GENDER
            }
        ],
    identifier: [
        {
            id: payload.SUBJECT_ID,
            use: uscore501:CODE_USE_OFFICIAL,
            'type: {
                coding: [
                        {
                            system: "http://terminology.hl7.org/CodeSystem/v2-0203",
                            code: "MR",
                            display: "Medical Record Number"
                    }
                ]
            },
            system: "http://hospital.testhospital.org",
            value: payload.SUBJECT_ID
        }
    ],
    active: payload.DOD == null? true: false,
    name: [
        {
            use: uscore501:CODE_USE_OFFICIAL,
            given: [payload.GIVEN],
            family: payload.FAMILY
        }
    ],
    telecom: <uscore501:USCorePatientProfileTelecom[]>[
        {
            system: uscore501:CODE_SYSTEM_EMAIL,
            value: payload.EMAIL,
            use: uscore501:CODE_USE_HOME
        },
        {
            system: uscore501:CODE_SYSTEM_PHONE,
            value: payload.PHONE,
            use: uscore501:CODE_USE_MOBILE
        }
    ],
    gender: mapGender(payload.GENDER),
    birthDate: formatDate(payload.DOB),
    deceasedBoolean: payload.DOD is ()? false: true,
    deceasedDateTime: formatDate(payload.DOD),
    address: <uscore501:USCorePatientProfileAddress[]>[
        {
            use: uscore501:CODE_USE_HOME,
            'type: uscore501:CODE_TYPE_BOTH,
            line: [payload.LINE],
            city: payload.CITY,
            state: payload.STATE,
            postalCode: payload.POSTALCODE,
            country: payload.COUNTRY
        }
    ],
    communication: <uscore501:USCorePatientProfileCommunication[]>[
        {
            language: {
                coding: [
                            {
                                system: "urn:ietf:bcp:47",
                                code: mapLanguage(payload.LANG)
                            }
                        ]
            },
            preferred: true
        }
    ]
};

isolated function mapGender(string inputGender) returns uscore501:USCorePatientProfileGender {
    uscore501:USCorePatientProfileGender gender;
    match inputGender {
        "M"=> {
            gender = uscore501:CODE_GENDER_MALE;
        }
        "F"=> {
            gender = uscore501:CODE_GENDER_FEMALE;
        }
        "O"=> {
            gender = uscore501:CODE_GENDER_OTHER;
        }
        _ => {
            gender = uscore501:CODE_GENDER_UNKNOWN;
        }
    }
    return gender;
}

isolated function formatDate(int? inputDate) returns string|() {
    string|() returnDate = ();
    if(inputDate !is ()) {
        //time:Utc dateVal = check time:utcFromString(inputDate + ".00Z");
        time:Utc|error utcEpoch = time:utcFromString("1970-01-01T00:00:00.00Z");
        if(utcEpoch !is error) {
            time:Utc inputDateUtc = time:utcAddSeconds(utcEpoch, <time:Seconds>(inputDate/<int>1000));
            returnDate = time:utcToString(inputDateUtc).substring(0,10);
        }
        //return inputDate.substring(0,10);
    }
    return returnDate;
}

isolated function mapLanguage(string inputLanguage) returns string|() {
    string|() language;
    match inputLanguage {
        "ITA"=> {
            language = "it";
        }
        "SPA"=> {
            language = "es";
        }
        "FRA"=> {
            language = "fr";
        }
        "GER"=> {
            language = "de";
        }
        "ENG"=> {
            language = "en";
        }
        _ => {
            language = ();
        }
    }
    return language;
}

public function main() returns ()|error {
    Patient2 payload2 = {
        rowId: "9467",
        subjectId: "10006",
        gender: "F",
        dob: "1976-02-01 00:00:00",
        dod: "2009-09-12 00:00:00",
        dodHosp: "2165-08-12 00:00:00",	
        dodSsn: "2165-08-12 00:00:00",
        expireFlag: "1",
        raceCd: "2076-8", 
        raceName: "Native Hawaiian or Other Pacific Islander",
        ethCd: "2135-2",
        ethName: "Hispanic or Latino",
        family:	"Davis",
        given: "Mary",
        phone: "+1-623-242-3581",
        email: "mary.davis@outlook.com",
        line: "8577 Baker St",
        city: "San Diego",	
        state: "California",
        postalCode: "92101",
        country: "US",	
        lang: "ITA"
    };

    Patient payload = {
        ROW_ID: 9467,
        SUBJECT_ID: "10006",
        GENDER: "F",
        DOB: 897091200000,
        DOD: null,
        DOD_HOSP: 6351868800000,	
        DOD_SSN: null,
        EXPIRE_FLAG: 1,
        RACE_CD: "2076-8", 
        RACE_NAME: "Native Hawaiian or Other Pacific Islander",
        ETH_CD: "2135-2",
        ETH_NAME: "Hispanic or Latino",
        FAMILY:	"Davis",
        GIVEN: "Mary",
        PHONE: "+1-623-242-3581",
        EMAIL: "mary.davis@outlook.com",
        LINE: "8577 Baker St",
        CITY: "San Diego",	
        STATE: "California",
        POSTALCODE: "92101",
        COUNTRY: "US",	
        LANG: "ITA"
    };

    // io:println(mapPatient(payload));

    // string sourceJson = check io:fileReadString("sourcedata.json");
    // io:println("sourceJson", " ", sourceJson);
    // CdcEvent cdcEvent = check jsondata:parseString(sourceJson);
    // io:println("cdcEvent", " ", cdcEvent);
    // HealthDataEvent healthDataEvent = check mapCdcToHealthData(cdcEvent);
    // io:println("healthDataEvent", " ", healthDataEvent);
    // Patient patient = check jsondata:parseAsType(healthDataEvent?.payload.toJson());
    // io:println("patient", " ", patient);

    // io:println("FHIR", " ", mapPatient(patient));
    
}

