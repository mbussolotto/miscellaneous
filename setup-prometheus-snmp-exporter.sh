#!/bin/bash
#########################################################
# STEPS
# 1) Check if the system is cleaned, otherwise clean it
# 2) Run Prometheus with ad-hoc configuration file
# 3) create prometheus-snmp-exporter RPM
# 4) Install, configure and run prometheus-snmp-exporter
#########################################################

#Kill Prometheus if it is running
PID=$(lsof -i:9090 | tail -n1 | awk '{ print $2 }')
if [ -n "${PID}" ]; then
  sudo kill ${PID}
fi

#Kill Prometheus SNMP Exporter if it is running
PID=$(lsof -i:9116 | tail -n1 | awk '{ print $2 }')
if [ -n "${PID}" ]; then
  sudo kill ${PID}
fi

#Uninstall prometheus-snmp-exporter (just in case)
sudo rpm -e prometheus-snmp-exporter

#check if prometheus-snmp-exporter.service is still present in the system. If yes, exit
sudo systemctl stop prometheus-snmp-exporter.service
RET=$?
if [ $RET -eq 0 ]
then
  echo "Prometheus-snmp-exporter service should not be present"
  exit 1
fi

cat > ~/snmp_demo.yml <<EOF
# my global config
global:
  scrape_interval:     15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

# Alertmanager configuration
alerting:
  alertmanagers:
  - static_configs:
    - targets:
      # - alertmanager:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label "job=<job_name>" to any timeseries scraped from this config.
  - job_name: 'prometheus'

    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.

    static_configs:
    - targets: ['localhost:9090']

  - job_name: 'snmp'
    metrics_path: /snmp
    params:
      module: [if_mib]
    static_configs:
      - targets:
        - 127.0.0.1  # SNMP device - add your IPs here
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 127.0.0.1:9116  # SNMP exporter.
EOF

#Start Prometheus
/home/bisi-suse/Workspace/prometheus/prometheus --config.file=/home/bisi-suse/snmp_demo.yml &
PROMETHEUS_PID=$!

echo "Waiting prometheus ..."
sleep 3

#Check prometheus-snmp-exporter is running
lsof -i:9090
RET=$?
if [ $RET -ne 0 ]
then
  echo "Prometheus should be running"
  exit 1
fi

#Check prometheus-snmp-exporter is STILL not running
lsof -i:9116
RET=$?
if [ $RET -eq 0 ]
then
  echo "Prometheus-snmp-exporter should not be running"
  exit 1
fi

#build RPM
cd /home/bisi-suse/Workspace/osc/home:mbussolotto/prometheus-snmp-exporter
osc build

#install RPM
sudo rpm -i /var/tmp/build-root/openSUSE_Tumbleweed-x86_64/home/abuild/rpmbuild/RPMS/x86_64/prometheus-snmp-exporter-0.20.0-0.x86_64.rpm

#add ARGS
sudo sed -i 's/ARGS=\"\"/ARGS=\"--config.file=\/etc\/prometheus\/snmp.yml\"/' /etc/default/prometheus-snmp-exporter

#set correct USER
sudo sed -i "s/User=prometheus/User=${USER}/" /usr/lib/systemd/system/prometheus-snmp-exporter.service

#reload daemon
sudo systemctl daemon-reload

#start the daemon
sudo systemctl start prometheus-snmp-exporter.service 

echo "Waiting prometheus-snmp-exporter ..."
sleep 3

#Check prometheus is STILL running
lsof -i:9090
RET=$?
if [ $RET -ne 0 ]
then
  echo "Prometheus should be running"
  exit 1
fi

#Check prometheus-snmp-exporter is running
lsof -i:9116
RET=$?
if [ $RET -ne 0 ]
then
  echo "Prometheus-snmp-exporter should be running"
  exit 1
fi

read -p "Press enter to continue"
sudo kill $PROMETHEUS_PID
sudo systemctl stop prometheus-snmp-exporter.service 
