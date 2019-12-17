#!/bin/bash

while (true); do
   echo "$(date +%Y-%m-%d-%H:%M:%S) - Bouncing..."
      kubectl --namespace kafka-saas scale deployments/leadoff-traffic-db --replicas 0
      kubectl --namespace kafka-saas scale deployments/leadoff-threat-db --replicas 0
      kubectl --namespace kafka-saas scale deployments/leadoff-threat-db --replicas 5
      sleep 180
      kubectl --namespace kafka-saas scale deployments/leadoff-traffic-db --replicas 1
   sleep 1800
done
