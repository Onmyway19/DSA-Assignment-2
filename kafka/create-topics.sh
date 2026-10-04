
B=${1:-kafka:9092}
BIN=/opt/kafka/bin/kafka-topics.sh
mk() { $BIN --bootstrap-server $B --create --if-not-exists --topic "$1" --partitions "$2" --replication-factor 1 --config retention.ms="$3"; }
D7=604800000
mk orders.created           6 $D7
mk orders.status-changed    6 $D7
mk orders.cancelled         3 $D7
mk payments.completed       6 $D7
mk payments.failed          3 $D7
mk restaurant.order.status  6 $D7
mk delivery.assigned        3 $D7
mk delivery.picked-up       3 $D7
mk delivery.completed       3 $D7
mk notifications.requests   6 86400000
mk orders.dlq               1 2592000000
$BIN --bootstrap-server $B --list
