#!/bin/bash
# Setup Nexus Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Nexus in project $GUID-nexus"

# Code to set up the Nexus. It will need to
# * Create Nexus
# * Set the right options for the Nexus Deployment Config
# * Load Nexus with the right repos
# * Configure Nexus as a docker registry

# Ideally just calls a template
# oc new-app -f ../templates/nexus.yaml --param .....

# To be Implemented by Student
oc new-app docker.io/sonatype/nexus3:latest -n ${GUID}-nexus

oc expose svc nexus3 -n ${GUID}-nexus

oc rollout pause dc nexus3 -n ${GUID}-nexus

# Configuring deployment strategy
oc patch dc nexus3 --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-nexus

# Configuring resoruces
oc set resources dc nexus3 --limits=memory=2Gi,cpu=2 --requests=memory=1Gi,cpu=500m -n ${GUID}-nexus

# Configuring and creating Persistent Volume Claim
echo "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nexus-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 4Gi" | oc create -f - -n ${GUID}-nexus

# Configuring the volumes associated
oc set volume dc/nexus3 --add --overwrite --name=nexus3-volume-1 --mount-path=/nexus-data/ --type persistentVolumeClaim --claim-name=nexus-pvc -n ${GUID}-nexus

# Setting readiness & liveliness probes for nexus
oc set probe dc/nexus3 -n ${GUID}-nexus --liveness --failure-threshold 3 --initial-delay-seconds 60 -- echo ok
oc set probe dc/nexus3 -n ${GUID}-nexus --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8081/repository/maven-public/

oc rollout resume dc nexus3 -n ${GUID}-nexus

# Hint: Make sure to wait until Nexus if fully up and running
#       before configuring nexus with repositories.
#       You could use the following code:



while : ; do
  echo "Checking if Nexus is Ready..."
  oc get pod -n ${GUID}-nexus|grep '\-2\-'|grep -v deploy|grep "1/1"
  [[ "$?" == "1" ]] || break
  echo "...no. Sleeping 10 seconds."
  sleep 10
done

# * Configure Nexus as a docker registry
curl -o setup_nexus3.sh -s https://raw.githubusercontent.com/redhat-gpte-devopsautomation/ocp_advanced_development_resources/master/nexus/setup_nexus3.sh
chmod +x setup_nexus3.sh
./setup_nexus3.sh admin admin123 http://$(oc get route nexus3 --template='{{ .spec.host }}' -n ${GUID}-nexus)
rm setup_nexus3.sh

# Create a Service called nexus-registry
oc expose dc nexus3 --port=5000 --name=nexus-registry -n ${GUID}-nexus

# Create an OpenShift route called nexus-registry
oc create route edge nexus-registry --service=nexus-registry --port=5000 -n ${GUID}-nexus

oc get routes -n $GUID-nexus



