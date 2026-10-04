public type OperatingHoursPayload record {|
    string openingTime;
    string closingTime;
    boolean isOpen;
|};

public type MenuItem record {|
    string itemId;
    string name;
    decimal price;
    string description;
    boolean isAvailable;
    int stockQuantity;
|};

public type Restaurant record {|
    string _id;
    string name;
    string cuisineType;
    boolean isOpen;
    string openingTime;
    string closingTime;
    MenuItem[] menu = [];
|};
