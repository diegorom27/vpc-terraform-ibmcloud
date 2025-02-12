#!/bin/bash
echo "Iniciando el script setup-satellite.sh" >> /home/setup-satellite-debug.log
#!/usr/bin/env bash

subscription-manager refresh
subscription-manager repos --enable rhel-8-for-x86_64-appstream-rpms
subscription-manager repos --enable rhel-8-for-x86_64-baseos-rpms

echo "Fin del script setup-satellite-location.sh" >> /home/setup-satellite-debug.log
