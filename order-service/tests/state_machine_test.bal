import ballerina/test;

@test:Config {}
function happyPath() {
    test:assertTrue(canTransition(CREATED, CONFIRMED));
    test:assertTrue(canTransition(CONFIRMED, PREPARING));
    test:assertTrue(canTransition(PREPARING, READY));
    test:assertTrue(canTransition(READY, OUT_FOR_DELIVERY));
    test:assertTrue(canTransition(OUT_FOR_DELIVERY, DELIVERED));
}

@test:Config {}
function illegalTransitions() {
    test:assertFalse(canTransition(CREATED, DELIVERED));
    test:assertFalse(canTransition(READY, CANCELLED));
    test:assertFalse(canTransition(DELIVERED, CANCELLED));
    test:assertFalse(canTransition(CANCELLED, CONFIRMED));
}

@test:Config {}
function cancellationWindow() {
    test:assertTrue(canTransition(CREATED, CANCELLED));
    test:assertTrue(canTransition(CONFIRMED, CANCELLED));
    test:assertTrue(canTransition(PREPARING, CANCELLED));
}
