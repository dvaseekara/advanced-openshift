
#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/redhat-gpte-devopsautomation/advdev_homework_template.git na311.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo https://github.com/p-ebot/advdev-homework.git for Cluster https://master.na311.openshift.opentlc.com"

# Set up Jenkins with sufficient resources

//echo "oc new-project"
//oc new-project ${GUID}-jenkins --description "${GUID} Homework Grading Jenkins"

echo "oc new-app"
oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=4Gi --param VOLUME_CAPACITY=10Gi --param DISABLE_ADMINISTRATIVE_MONITORS=true --env JENKINS_JAVA_OVERRIDES="-Dhudson.slaves.NodeProvisioner.initialDelay=0 -Dhudson.slaves.NodeProvisioner.MARGIN=50 -Dhudson.slaves.NodeProvisioner.MARGIN0=0.85 -Dorg.jenkinsci.plugins.durabletask.BourneShellScript.HEARTBEAT_CHECK_INTERVAL=300" -n ${GUID}-jenkin

echo "oc set"
oc set resources dc/jenkins --limits=memory=4Gi,cpu=4 --requests=memory=2Gi,cpu=2 -n ${GUID}-jenkins

# Create custom agent container image with skopeo
echo "oc new-build"
oc new-build  -D $'FROM docker.io/openshift/jenkins-agent-maven-35-centos7:v3.11\n
      USER root\nRUN yum -y install skopeo && yum clean all\n
      USER 1001' --name=jenkins-agent-appdev

# Create pipeline build config pointing to the ${REPO} with contextDir `openshift-tasks`
echo "oc create"
echo "apiVersion: v1
items:
- kind: "BuildConfig"
  apiVersion: "v1"
  metadata:
    name: "tasks-pipeline"
  spec:
    source:
      type: "Git"
      git:
        uri: "https://github.com/p-ebot/advdev-homework.git"
    strategy:
      type: "JenkinsPipeline"
      jenkinsPipelineStrategy:
        jenkinsfilePath: openshift-tasks/Jenkinsfile
kind: List
metadata: []" | oc create -f - -n ${GUID}-jenkins

# Make sure that Jenkins is fully up and running before proceeding!
while : ; do
  echo "Checking if Jenkins is Ready..."
  AVAILABLE_REPLICAS=$(oc get dc jenkins -n ${GUID}-jenkins -o=jsonpath='{.status.availableReplicas}')
  if [[ "$AVAILABLE_REPLICAS" == "1" ]]; then
    echo "...Yes. Jenkins is ready."
    break
  fi
  echo "...no. Sleeping 10 seconds."
  sleep 10
done
