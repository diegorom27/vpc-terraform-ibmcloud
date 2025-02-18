#!/bin/bash

# Ejecuta el comando y formatea la salida en JSON
ibmcloud schematics state list --id us-south.workspace.vpc-test.643cd01d --output json | jq '[.[] | select(.resources != null) | .resources[] | {resource_type, resource_name, resource_id, resource_group_name}]'
