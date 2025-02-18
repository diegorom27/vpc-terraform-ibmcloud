#!/bin/bash

# Ejecuta el comando y formatea la salida en JSON
output=$(ibmcloud schematics state list --id us-south.workspace.vpc-test.643cd01d --output json | jq '[.[] | select(.resources != null) | .resources[] | {resource_type, resource_name, resource_id, resource_group_name}]')
# Si la salida está vacía, asignar un mapa vacío
if [[ "$output" == "[]" ]]; then
  json_output="{}"
else
  # Convertir la salida en un mapa clave-valor adecuado para Terraform
  json_output=$(echo "$output" | jq 'map({(.resource_id): .resource_name}) | add')
fi

# Imprime la salida como un objeto JSON
echo "{\"state\": $json_output}"