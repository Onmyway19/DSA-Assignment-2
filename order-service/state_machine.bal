
final map<OrderStatus[]> TRANSITIONS = {
    "CREATED": [CONFIRMED, CANCELLED],
    "CONFIRMED": [PREPARING, CANCELLED],
    "PREPARING": [READY, CANCELLED],
    "READY": [OUT_FOR_DELIVERY],
    "OUT_FOR_DELIVERY": [DELIVERED],
    "DELIVERED": [],
    "CANCELLED": []
};

public function isTerminal(OrderStatus s) returns boolean {
    return s == DELIVERED || s == CANCELLED;
}

public function canTransition(OrderStatus current, OrderStatus next) returns boolean {
    OrderStatus[]? allowed = TRANSITIONS[current];
    if allowed is () {
        return false;
    }
    return allowed.indexOf(next) !is ();
}


public function actorAllowed(string actor, OrderStatus target) returns boolean {
    if actor == "ADMIN" {
        return true;
    }
    if target == CONFIRMED {
        return actor == "PAYMENT";
    }
    if target == PREPARING || target == READY {
        return actor == "RESTAURANT";
    }
    if target == OUT_FOR_DELIVERY || target == DELIVERED {
        return actor == "DELIVERY";
    }
    return true;
}
