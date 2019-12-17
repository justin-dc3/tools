#!/bin/bash

while (true); do
   echo "$(date +%Y-%m-%d-%H:%M:%S) - Bouncing..."
      kubectl --namespace kafka-saas scale deployments/leadoff-traffic-cache --replicas 0
      kubectl --namespace kafka-saas scale deployments/leadoff-threat-cache --replicas 0
      kubectl --namespace kafka-saas scale deployments/leadoff-threat-cache --replicas 2
      kubectl --namespace kafka-saas scale deployments/leadoff-traffic-cache --replicas 2
   sleep 1800
done
