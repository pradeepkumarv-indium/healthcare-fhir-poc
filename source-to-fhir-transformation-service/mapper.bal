import ballerina/http;
import ballerinax/health.fhir.r4;
import ballerinax/health.fhir.r4.uscore501;
import ballerinax/health.fhir.r4.validator;
//import ballerina/time;
import ballerina/io;

# Mapper function to map health data to FHIR resources
#
# + dataType - health data type
# + payload - payload to be mapped
# + return - mapped FHIR resource or error
public isolated function mapToFhir(string dataType, anydata payload) returns anydata|r4:FHIRError {
    match dataType {
        "patient_data" => {
            Patient|error patientData = payload.cloneWithType();
            if patientData is error {
                return r4:createFHIRError("Error occurred while cloning the payload", r4:ERROR, r4:INVALID);
            }
            uscore501:USCorePatientProfile fhirPayload = mapPatient(patientData);
            r4:FHIRValidationError? validate = validator:validate(fhirPayload, uscore501:USCorePatientProfile);
            if validate is r4:FHIRValidationError {
                return r4:createFHIRError(validate.message(), r4:ERROR, r4:INVALID, cause = validate.cause(), errorType = r4:VALIDATION_ERROR, httpStatusCode = http:STATUS_BAD_REQUEST);
            }
            return fhirPayload;
        }
        _ => {
            return r4:createFHIRError("Invalid data type", r4:ERROR, r4:INVALID);
        }
    }
}

# Dedicated function to map patient data to US Core Patient Profile
#
# + payload - patient data in custom format
# + return - US Core Patient Profile
public isolated function mapPatient(Patient payload) returns uscore501:USCorePatientProfile => {
    id: payload.subjectId,
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
                            code: payload.raceCd,
                            display: payload.raceName
                        }
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
                            code: payload.ethCd,
                            display: payload.ethName
                        }
                    }
                ]
            },
            {
                url: "http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity",
                valueCode: payload.gender
            }
        ],
    identifier: [
        {
            id: payload.subjectId,
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
            value: payload.subjectId
        }
    ],
    active: payload.dod == ""? true: false,
    name: [
        {
            use: uscore501:CODE_USE_OFFICIAL,
            given: [payload.given],
            family: payload.family
        }
    ],
    telecom: <uscore501:USCorePatientProfileTelecom[]>[
        {
            system: uscore501:CODE_SYSTEM_EMAIL,
            value: payload.email,
            use: uscore501:CODE_USE_HOME
        },
        {
            system: uscore501:CODE_SYSTEM_PHONE,
            value: payload.phone,
            use: uscore501:CODE_USE_MOBILE
        }
    ],
    gender: mapGender(payload.gender),
    birthDate: formatDate(payload.dob),
    deceasedBoolean: payload.dod == ""? false: true,
    deceasedDateTime: formatDate(payload.dod),
    address: <uscore501:USCorePatientProfileAddress[]>[
        {
            use: uscore501:CODE_USE_HOME,
            'type: uscore501:CODE_TYPE_BOTH,
            line: [payload.line],
            city: payload.city,
            state: payload.state,
            postalCode: payload.postalCode,
            country: payload.country
        }
    ],
    communication: <uscore501:USCorePatientProfileCommunication[]>[
        {
            language: {
                coding: [
                            {
                                system: "urn:ietf:bcp:47",
                                code: payload.lang
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

isolated function formatDate(string inputDate) returns string {
    //time:Utc dateVal = check time:utcFromString(inputDate + ".00Z");
    return inputDate.substring(0,10);
}

public function main() {
    Patient payload = {
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
    io:println(mapPatient(payload));

}