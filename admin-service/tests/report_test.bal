import ballerina/test;

@test:Config {}
function filtersEventsByUtcRange() {
    test:assertTrue(isWithinRange(
        "2026-10-01T10:00:00Z",
        "2026-10-01T09:00:00Z",
        "2026-10-01T11:00:00Z"
    ));
    test:assertFalse(isWithinRange(
        "2026-10-01T12:00:00Z",
        "2026-10-01T09:00:00Z",
        "2026-10-01T11:00:00Z"
    ));
}

@test:Config {}
function rejectsReversedReportRange() {
    error? rangeError = validateRange("2026-10-02T00:00:00Z", "2026-10-01T00:00:00Z");
    test:assertTrue(rangeError is error);
}
