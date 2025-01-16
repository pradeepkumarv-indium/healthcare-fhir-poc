// Copyright (c) 2023, WSO2 LLC. (http://www.wso2.com). All Rights Reserved.
// This software is the property of WSO2 LLC. and its suppliers, if any.
// Dissemination of any information or reproduction of any material contained
// herein is strictly forbidden, unless permitted by WSO2 in accordance with
// the WSO2 Software License available at: https://wso2.com/licenses/eula/3.2
// For specific language governing the permissions and limitations under
// this license, please see the license as well as any agreement you’ve
// entered into with WSO2 governing the purchase of this software and any
// associated services.
//
//
// AUTO-GENERATED FILE.
//
// This file is auto-generated by Ballerina.
// Developers are allowed to modify this file as per the requirement.
import ballerina/log;
import ballerinax/health.clients.fhir;
import ballerinax/health.fhir.r4;
import ballerinax/kafka;
import ballerina/http;

# Kafka configurations
configurable string groupId = ?;
configurable string topic = ?;
configurable decimal pollingInterval = 1;
configurable string kafkaEndpoint = ?;
configurable string cacert = ?;
configurable string keyPath = ?;
configurable string certPath = ?;

# FHIR server configurations
configurable string fhirServerUrl = ?;
// configurable string tokenUrl = ?;
// configurable string[] scopes = ?;
// configurable string client_id = ?;
// configurable string client_secret = ?;

configurable string statusServiceUrl = "http://status-api-1938288175:9090";
string:RegExp regExpSplitWithComma = re `\s*,\s*`;

final kafka:ConsumerConfiguration consumerConfigs = {
    groupId: groupId,
    topics: regExpSplitWithComma.split(topic),
    offsetReset: kafka:OFFSET_RESET_EARLIEST,
    sessionTimeout: 45,
    pollingInterval: pollingInterval,
    securityProtocol: kafka:PROTOCOL_PLAINTEXT
    //secureSocket: {protocol: {name: kafka:PROTOCOL_PLAINTEXT}, cert: cacert, 'key: {certFile: certPath, keyFile: keyPath}}
};

// call status service
final http:Client statusClient = check new(statusServiceUrl);

service on new kafka:Listener(kafkaEndpoint, consumerConfigs) {

    function init() returns error? {
        log:printInfo("Health data consumer service started");
    }

    remote function onConsumerRecord(CdcEvent[] cdcEvents) returns error? {
            log:printInfo("Events Received ...");
        from CdcEvent cdcEvent in cdcEvents
        where cdcEvent?.payload !is ()
        do {
            log:printInfo(string `CDC event received: ${cdcEvent.toJsonString()}`, cdcEvent = cdcEvent);
            json cdcPayload = cdcEvent?.payload.toJson();
            string? healthDataType = check cdcPayload.'source.'table;
            anydata healthDataPayload = check cdcPayload.after;
            string operation = check cdcPayload.op; 

            // HealthDataEvent healthDataEvent = check mapCdcToHealthData(cdcEvent);
            // log:printInfo(string `Health data event received: ${healthDataEvent?.payload.toJsonString()}`, healthDataEvent = healthDataEvent);
            // string? dataType = healthDataEvent?.dataType;
            if healthDataType is string {
                anydata|r4:FHIRError mappedData = mapToFhir(healthDataType, healthDataPayload);
                if mappedData is r4:FHIRError {
                    log:printError("Error occurred while mapping the data: ", mappedData);
                } else {
                    log:printInfo(string `FHIR resource mapped: ${mappedData.toJsonString()}`, mappedData = mappedData);
                    //r4:FHIRError|fhir:FHIRResponse response = <fhir:FHIRResponse>{"resource": null, "httpStatusCode": 200, "serverResponseHeaders": {}};//createResource(mappedData.toJson());
                    r4:FHIRError|fhir:FHIRResponse response = createResource(mappedData.toJson());
                    if response is fhir:FHIRResponse {
                        json|xml resourceResult = response.'resource;
                        if resourceResult is json {
                            json|error resourceId = resourceResult.resourceId;
                            if resourceId is json {
                                log:printInfo(string `FHIR resource created: ${response.toJsonString()}`, createdResourceId = check (<json>response.'resource).resourceId);
                            }
                            http:Response|http:ClientError statusApiResponse = statusClient->post("/resource-data", response.toJson());
                        }
                    }
                }
            } else {
                log:printError("Invalid data type: ", healthDataType);
            }
        };
    }
}

