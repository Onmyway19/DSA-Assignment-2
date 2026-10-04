public type Address record {|
    string addressId?;
    string streetAddress;
    string city;
    string postalCode;
    boolean isPrimary?;
|};

public type Customer record {|
    string id?;
    string name;
    string email;
    string phone;
    Address[] addresses?;
    string createdAt?;
|};

public type CustomerCreatePayload record {|
    string name;
    string email;
    string phone;
    Address[] addresses?;
|};
