#!/usr/bin/env bash

REPS=1
DIR=$(dirname "$0")
DOCKER_USER=vitorenesduarte
IMAGE=${DOCKER_USER}/lsim-copy
DOCKERFILE=${DIR}/../Dockerfiles/lsim-copy

#"${DIR}"/g-cluster.sh start

if [ "$1" == "build" ]; then
  # build and push
  IMAGE=${IMAGE} \
    DOCKERFILE=${DOCKERFILE} "${DIR}"/image.sh

  # use the new image
  PULL_IMAGE=Always

elif [ "$1" == "local" ]; then
  # build locally
  eval $(minikube docker-env)
  docker build \
         --no-cache \
         -t "${IMAGE}" -f "${DOCKERFILE}" .

  # use the new image
  PULL_IMAGE=IfNotPresent

else
  # use the latest image
  PULL_IMAGE=IfNotPresent

fi

# start redis
"${DIR}"/redis-deploy.sh

# start dashboard
#"${DIR}"/lsim-dash-deploy.sh

CPU=30

# lsim configuration
SIMULATION_=(gcounter gset awset)
NODE_EVENT_NUMBER=200
KEEP_ALIVE=false
# overlay nodes
EXP_=(
#   "tree 14"
   "chord 16"
)

# ldb configuration
LDB_STATE_SYNC_INTERVAL=1000
# mode driven_mode bp rr break_link
LDB_=(
   "delta_based digest_driven true      true      true"
   "delta_based state_driven  true      true      true"
   "delta_based none          true      true      true"
   "delta_based none          true      true      false"
   "delta_based none          true      false     false"
   "delta_based none          false     true      false"
   "delta_based none          false     false     false"
   "state_based none          undefined undefined false"
)

# shellcheck disable=SC2034
for REP in $(seq 1 $REPS); do
  for EXP in "${EXP_[@]}"; do
    EXP=($(echo ${EXP} | tr ' ' '\n'))
    OVERLAY=${EXP[0]}
    NODE_NUMBER=${EXP[1]}

    for SIMULATION in "${SIMULATION_[@]}"; do
      for LDB in "${LDB_[@]}"; do
        LDB=($(echo ${LDB} | tr ' ' '\n'))
        LDB_MODE=${LDB[0]}
        LDB_DRIVEN_MODE=${LDB[1]}
        LDB_DGROUP_BACK_PROPAGATION=${LDB[2]}
        LDB_REDUNDANT_DGROUPS=${LDB[3]}
        BREAK_LINK=${LDB[4]}

        if [[ "$LDB_DRIVEN_MODE" = digest_driven ]] && [[ "$SIMULATION" = gset || "$SIMULATION" = gcounter ]]; then
          echo "Skipping..."
        else

          BRANCH=${BRANCH} \
            IMAGE=${IMAGE} \
            PULL_IMAGE=${PULL_IMAGE} \
            LDB_MODE=${LDB_MODE} \
            LDB_DRIVEN_MODE=${LDB_DRIVEN_MODE} \
            LDB_STATE_SYNC_INTERVAL=${LDB_STATE_SYNC_INTERVAL} \
            LDB_DGROUP_BACK_PROPAGATION=${LDB_DGROUP_BACK_PROPAGATION} \
            LDB_REDUNDANT_DGROUPS=${LDB_REDUNDANT_DGROUPS} \
            OVERLAY=${OVERLAY} \
            SIMULATION=${SIMULATION} \
            NODE_NUMBER=${NODE_NUMBER} \
            NODE_EVENT_NUMBER=${NODE_EVENT_NUMBER} \
            BREAK_LINK=${BREAK_LINK} \
            KEEP_ALIVE=${KEEP_ALIVE} \
            CPU=${CPU} "${DIR}"/lsim-deploy.sh

        fi
      done
    done
  done
done

#"${DIR}"/start-redis-sync.sh

#"${DIR}"/g-cluster.sh stop
