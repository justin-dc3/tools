#!/bin/bash

while (true); do
   echo "$(date +%Y-%m-%d-%H:%M:%S) - Bouncing..."
   for deployment in leadoff-threat-cache leadoff-threat-db leadoff-traffic-cache leadoff-traffic-db; do
      replicas=$(kubectl --namespace kafka-saas get deployments/${deployment} | tail -1 | awk '{ print $2 }')
      kubectl --namespace kafka-saas scale deployments/${deployment} --replicas 0
      kubectl --namespace kafka-saas scale deployments/${deployment} --replicas ${replicas}
   done
   sleep 900
done
