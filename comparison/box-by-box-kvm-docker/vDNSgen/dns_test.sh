#! /bin/bash

test_duration=15 # Test duration in seconds
drop_limit=90 # Percent of packets that must return for test to suceed

run_test() {
  while IFS= read -r line; do
    if [ "$(echo $line | awk '{print $1}')" == "tx" ]; then
        tx_count=$(echo $line | awk '{print $4}' | tr -d '\r')
    elif [ "$(echo $line | awk '{print $1}')" == "rx" ]; then
        rx_count=$(echo $line | awk '{print $4}' | tr -d '\r')
    else
        echo "Unknown output: $line"
        exit 1
    fi
  done < <(sudo vppctl clear hard && sleep $test_duration && sudo vppctl show hard | grep "frames ok")
}

start_stream() {
  sudo vppctl packet-gen enable-stream dns${1}
  sleep 5
}

sudo vppctl packet-gen disable

if [ ! -z "$1" ] ; then
  echo "DNS PACKET RATE passed to test script $1"
  DNS_PACKET_RATE=$1
fi

if [ -n "$DNS_PACKET_RATE" ] ; then
  ./vDNSgen/set_dns_packet_rate.sh $DNS_PACKET_RATE
fi

increments=$(cat /opt/dns_streams/stream_dns1 | grep rate | awk '{print $2}')

echo ""
echo "Starting vDNS tests"
echo "  Increments: $increments packets per second"
echo "  Duration of tests: $test_duration seconds"
echo "  Drop Limit: ${drop_limit}% of packets must return"
echo ""

for iteration in {1..10}; do
  echo "## Iteration $iteration, $(( $iteration * $increments )) packets per second ##"
  start_stream $iteration
  tx_count=0
  rx_count=0
  echo "Running test iteration..."
  run_test
  output=$(( ($rx_count * 100) / $tx_count ))
  echo "Iteration completed"
  echo "  Expected $(( $tx_count / $test_duration )) Packets per second"
  echo "  Received $(( $rx_count / $test_duration )) Packets per second"
  echo "  = ${output}% of packets"
  echo ""
  if [ "$output" -ge "$drop_limit" ]; then
    echo "Increasing load"
  else
    echo "Limit reached"
    echo ""
    echo "################################"
    echo "vDNS Throughput: $(( $rx_count / $test_duration )) Packets per second"
    echo "################################"
    echo ""
    sudo vppctl packet-gen disable
    exit 0
  fi
done

echo "ERROR - Unable to find throughput limit of vDNS"
echo "Exiting..."
sudo vppctl packet-gen disable
exit 1
