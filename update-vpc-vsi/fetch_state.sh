#!/bin/bash

# Exit if any of the intermediate steps fail
set -e

# Ejecuta el comando y formatea la salida en JSON
output=$(ibmcloud schematics state list --id us-south.workspace.vpc-test.643cd01d --output json)

# Si la salida está vacía, asignar un mapa vacío
if [[ "$output" == "[]" ]]; then
  json_output="{}"
else
  # Procesa los recursos para crear un mapa clave-valor con resource_id como clave
  json_output=$(echo "$output" | jq 'map({(.resource_id): {resource_type: .resource_type, resource_name: .resource_name, resource_group_name: .resource_group_name}}) | add')
fi

# Genera un JSON de salida
jq -n --argjson state "$json_output" '{"state": $state}'
