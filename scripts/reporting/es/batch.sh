#!/bin/bash

while read -u3 uuid; do
   bash run.sh $uuid
done 3<list.1
