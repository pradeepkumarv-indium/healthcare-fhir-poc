
public type HealthDataEvent record {
    string eventId;
    string timestamp;
    string dataType?;
    string origin?;
    anydata payload?;
};

public type Patient record {
    string rowId;
    string subjectId;
    string gender;
    string dob;
    string dod;
    string dodHosp;
    string dodSsn;
    string expireFlag;
    string raceCd;
    string raceName;
    string ethCd;
    string ethName;
    string family;
    string given;
    string phone;
    string email;
    string line;
    string city;
    string state;
    string postalCode;
    string country;
    string lang;
};

public type Identifier record {
    IdType id_type;
    string id_value;
};

public type IdType record {
    Code[] codes;
};

public type Code record {
    string system_source;
    string identifier_code;
};

public type Description record {
    string status;
    string details?;
};

public type LocatoionDetail record {
    string nation?;
    string town?;
    string region?;
    string zipCode?;
    string identifier?;
    string province?;
};

public type ResponseResource record{
    string resourceId;
    string version;
};

