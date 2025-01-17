
public type HealthDataEvent record {
    string eventId;
    string timestamp;
    string dataType?;
    string origin?;
    anydata payload?;
};

public type CdcEvent record {
    string eventId;
    string timestamp;
    anydata schema?;
    anydata payload;
    string operation;
    string dataType;
};

public type Patient2 record {
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

public type Patient record {
    int ROW_ID;
    string SUBJECT_ID;
    string GENDER;
    int DOB;
    int? DOD;
    int? DOD_HOSP;
    int? DOD_SSN;
    int EXPIRE_FLAG;
    string RACE_CD;
    string RACE_NAME;
    string ETH_CD;
    string ETH_NAME;
    string FAMILY;
    string GIVEN;
    string PHONE;
    string EMAIL;
    string LINE;
    string CITY;
    string STATE;
    string POSTALCODE;
    string COUNTRY;
    string LANG;
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

