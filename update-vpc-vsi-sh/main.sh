#!/bin/bash

source ./env.sh

ibmcloud login --apikey $APIKEY -r $REGION

ibmcloud target -g $RESOURCE_GROUP_NAME

if ! ibmcloud plugin list | grep -q "vpc-infrastructure"; then
    ibmcloud plugin install is
else
    echo "El plugin 'vpc-infrastructure' ya está instalado. Omitiendo instalación."
fi

iam_token=$(ibmcloud iam oauth-tokens)

token=$(echo "$iam_token" | awk -F"Bearer " '{print $2}')

machine_ids=$(ibmcloud is instances --resource-group-name $RESOURCE_GROUP_NAME --output json | jq 'map({(.name): .id}) | add')

result=$(echo "$machine_configs" | jq --argjson ids "$machine_ids" '
  map(
    if .name and $ids[.name] then
      . + {"id": $ids[.name]}
    else
      .
    end
  )
')

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
        sleep 10
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

