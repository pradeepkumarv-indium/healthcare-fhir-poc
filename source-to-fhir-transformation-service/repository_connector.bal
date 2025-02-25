import ballerina/http;
import ballerina/log;
import ballerinax/health.clients.fhir;
import ballerinax/health.fhir.r4;

// http:OAuth2ClientCredentialsGrantConfig ehrSystemAuthConfig = {
//     tokenUrl: tokenUrl,
//     clientId: client_id,
//     clientSecret: client_secret,
//     scopes: scopes,
//     optionalParams: {
//         "resource": "https://ohfhirrepositorypoc-ohfhirrepositorypoc.fhir.azurehealthcareapis.com"
//     }
// };

http:ClientSecureSocket secureSocketConfig = {
    enable: false
};

fhir:FHIRConnectorConfig ehrSystemConfig = {
    baseURL: fhirServerUrl,
    mimeType: fhir:FHIR_JSON,
    secureSocket: secureSocketConfig
    // authConfig: ehrSystemAuthConfig
};

isolated fhir:FHIRConnector fhirConnectorObj = check new (ehrSystemConfig);

public isolated function upsertResource(json payload) returns r4:FHIRError|fhir:FHIRResponse {
    lock {
        fhir:FHIRResponse|fhir:FHIRError fhirResponse = fhirConnectorObj->update(payload.clone(), returnMimeType = (), returnPreference = "OperationOutcome");
        if fhirResponse is fhir:FHIRError {
            log:printError(fhirResponse.toBalString());
            return r4:createFHIRError(fhirResponse.message(), r4:ERROR, r4:INVALID, httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }
        log:printInfo(string `Data stored successfully: ${fhirResponse.toJsonString()}`);
        return fhirResponse.clone();
    }
}


public isolated function deleteResource(json payload) returns r4:FHIRError|fhir:FHIRResponse|error {
    lock {
        string resourceType = check payload.resourceType;
        string id = check payload.id;
        fhir:FHIRResponse|fhir:FHIRError fhirResponse = fhirConnectorObj->delete(resourceType, id);
        if fhirResponse is fhir:FHIRError {
            log:printError(fhirResponse.toBalString());
            return r4:createFHIRError(fhirResponse.message(), r4:ERROR, r4:INVALID, httpStatusCode = http:STATUS_INTERNAL_SERVER_ERROR);
        }
        log:printInfo(string `Data stored successfully: ${fhirResponse.toJsonString()}`);
        return fhirResponse.clone();
    }
}
