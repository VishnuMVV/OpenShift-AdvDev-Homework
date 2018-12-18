#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/wkulhanek/ParksMap na39.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Code to set up the Jenkins project to execute the
# three pipelines.
# This will need to also build the custom Maven Slave Pod
# Image to be used in the pipelines.
# Finally the script needs to create three OpenShift Build
# Configurations in the Jenkins Project to build the
# three micro services. Expected name of the build configs:
# * mlbparks-pipeline
# * nationalparks-pipeline
# * parksmap-pipeline
# The build configurations need to have two environment variables to be passed to the Pipeline:
# * GUID: the GUID used in all the projects
# * CLUSTER: the base url of the cluster used (e.g. na39.openshift.opentlc.com)

# To be Implemented by Student
# Set up Jenkins with sufficient resources
oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=2Gi --param VOLUME_CAPACITY=4Gi -n ${GUID}-jenkins
oc set resources dc/jenkins --limits=memory=2Gi,cpu=1 --requests=memory=2Gi,cpu=1 -n ${GUID}-jenkins

oc set probe dc/jenkins --readiness --failure-threshold=3 --initial-delay-seconds=120 --get-url=http://:8080/login --period-seconds=10 --success-threshold=1 --timeout-seconds=600 -n ${GUID}-jenkins
oc set probe dc/jenkins --liveness --failure-threshold=3 --initial-delay-seconds=120 --get-url=http://:8080/login --period-seconds=10 --success-threshold=1 --timeout-seconds=600 -n ${GUID}-jenkins

# Create custom agent container image with skopeo
oc new-build  -D $'FROM docker.io/openshift/jenkins-slave-maven-centos7:v3.9\n
      USER root\nRUN yum -y install skopeo && yum clean all\n
      USER 1001' --name=jenkins-slave-appdev -n ${GUID}-jenkins

# Create pipeline build config pointing to the ${REPO} with contextDir `MLBParks`
echo "apiVersion: "v1"
kind: "BuildConfig"
metadata:
  name: "mlbparks-pipeline"
spec:
  source:
    type: "Git"
    git:
      uri: "${REPO}"
    contextDir: "MLBParks"
  strategy:
    type: "JenkinsPipeline"
    jenkinsPipelineStrategy:
      env:
      - name: GUID
        value: ${GUID}
      - name: CLUSTER
	value: ${CLUSTER}
      - name: REPO
	value: ${REPO}
      jenkinsfilePath: Jenkinsfile" | oc create -f - -n ${GUID}-jenkins

echo "apiVersion: "v1"
kind: "BuildConfig"
metadata:
  name: "nationalparks-pipeline"
spec:
  source:
    type: "Git"
    git:
      uri: "${REPO}"
    contextDir: "NationalParks"
  strategy:
    type: "JenkinsPipeline"
    jenkinsPipelineStrategy:
      env:
      - name: GUID
        value: ${GUID}
      - name: CLUSTER
        value: ${CLUSTER}
      - name: REPO
        value: ${REPO}
      jenkinsfilePath: Jenkinsfile" | oc create -f - -n ${GUID}-jenkins

echo "apiVersion: "v1"
kind: "BuildConfig"
metadata:
  name: "parksmap-pipeline"
spec:
  source:
    type: "Git"
    git:
      uri: "${REPO}"
    contextDir: "ParksMap"
  strategy:
    type: "JenkinsPipeline"
    jenkinsPipelineStrategy:
      env:
      - name: GUID
        value: ${GUID}
      - name: CLUSTER
        value: ${CLUSTER}
      - name: REPO
        value: ${REPO}
      jenkinsfilePath: Jenkinsfile" | oc create -f - -n ${GUID}-jenkins
