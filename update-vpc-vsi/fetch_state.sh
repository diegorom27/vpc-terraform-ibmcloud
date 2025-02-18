#!/bin/bash

# Iniciar sesión en IBM Cloud
ibmcloud login --apikey $APIKEY -r $REGION

# Obtener el token IAM
iam_token=$(ibmcloud iam oauth-tokens)

# Extraer el token de la salida
token=$(echo "$iam_token" | awk -F"Bearer " '{print $2}')

RESOURCE_GROUP_NAME="vpc-demo-rg"
VPC_API_ENDPOINT="https://us-south.iaas.cloud.ibm.com/v1"
ENABLE_HIGH_PERFORMANCE="true"  

machine_configs='[
  {"name": "test-machine-1", "hProfile": "mx2-2x16", "lProfile": "cx2-2x4"},
  {"name": "test-machine-2", "hProfile": "mx2-4x16", "lProfile": "cx2-4x8"}
]'

machine_ids=$(ibmcloud is instances --resource-group-name $RESOURCE_GROUP_NAME --output json | jq 'map({(.name): .id}) | add')

# Combinar el diccionario con la lista de machine_configs
result=$(echo "$machine_configs" | jq --argjson ids "$machine_ids" '
  map(
    if .name and $ids[.name] then
      . + {"id": $ids[.name]}
    else
      .
    end
  )
')

check_instance_status() {
  local instance_id=$1
  local status="pending"

  while [ "$status" != "available" ]; do
    # Verificar el estado de la instancia
    instance_status=$(curl -s -X GET "$VPC_API_ENDPOINT/v1/instances/$instance_id?version=2021-02-01" \
      -H "Authorization: Bearer $token" | jq -r '.status')
    
    if [ "$instance_status" == "available" ]; then
      echo "La instancia $instance_id está lista (status: available)"
    else
      echo "Esperando que la instancia $instance_id cambie a 'available' (estado actual: $instance_status)..."
      sleep 30  # Esperar 30 segundos antes de volver a verificar
    fi
  done
}

update_instance() {
  instance=$1
  instance_id=$(echo "$instance" | jq -r '.id')
  instance_name=$(echo "$instance" | jq -r '.name')
  hProfile=$(echo "$instance" | jq -r '.hProfile')
  lProfile=$(echo "$instance" | jq -r '.lProfile')

  if [ "$ENABLE_HIGH_PERFORMANCE" == "true" ]; then
    profile=$hProfile
  else
    profile=$lProfile
  fi

  curl -sS -X POST "$VPC_API_ENDPOINT/instances/$instance_id/actions?version=2021-06-22&generation=2" \
    -H "Authorization: $token" \
    -d '{"type": "stop"}'

  while true; do
    state=$(curl -sS "$VPC_API_ENDPOINT/instances/$instance_id?version=2021-06-22&generation=2" \
      -H "Authorization: $token" | jq -r '.status')
    if [ "$state" == "stopped" ]; then
      break
    fi
    echo "Esperando a que la máquina $instance_name ($instance_id) se detenga..."
    sleep 10
  done

  curl -k -sS -X PATCH "$VPC_API_ENDPOINT/instances/$instance_id?generation=2&version=2021-02-01" \
    -H "Authorization: Bearer $token" \
    -d "{
      \"profile\": {
         \"name\": \"$profile\"
      }
    }"

  echo "Esperando unos segundos para aplicar el cambio de perfil..."
  sleep 15

  curl -sS -X POST "$VPC_API_ENDPOINT/instances/$instance_id/actions?version=2021-06-22&generation=2" \
    -H "Authorization: $token" \
    -d '{"type": "start"}'

  echo "Perfil actualizado y máquina $instance_name ($instance_id) reiniciada con el perfil $profile."
}

echo "$result" | jq -c '.[] | select(.id != null)' | while read instance; do


  instance_id=$(echo "$instance" | jq -r '.id')
  instance_name=$(echo "$instance" | jq -r '.name')
  hProfile=$(echo "$instance" | jq -r '.hProfile')
  lProfile=$(echo "$instance" | jq -r '.lProfile')

  if [ "$ENABLE_HIGH_PERFORMANCE" == "true" ]; then
    profile=$hProfile 
  else
    profile=$lProfile 
  fi
  
  curl -sS -X  POST "$VPC_API_ENDPOINT/instances/$instance_id/actions?version=2021-06-22&generation=2" -H "Authorization: $token" -d '{"type": "stop"}'
  
    while true; do
        state=$(curl -sS "$VPC_API_ENDPOINT/instances/$instance_id?version=2021-06-22&generation=2" \
        -H "Authorization: $token" | jq -r '.status')
        if [ "$state" == "stopped" ]; then
        break
        fi
        echo "Esperando a que la máquina $instance_name ($instance_id) se detenga..."
        sleep 
    done

  curl -k -sS -X PATCH "$VPC_API_ENDPOINT/instances/$instance_id?generation=2&version=2021-02-01" \
    -H "Authorization: Bearer $token" \
    -d "{
      \"profile\": {
         \"name\": \"$profile\"
      }
    }"

    wait $!
    echo "Esperando unos segundos para aplicar el cambio de perfil..."
    sleep 15 

    curl -sS -X  POST "$VPC_API_ENDPOINT/instances/$instance_id/actions?version=2021-06-22&generation=2" -H "Authorization: $token" -d '{"type": "start"}'

  echo "Perfil actualizado para la instancia: $instance_name ($instance_id) con perfil $profile"
done

