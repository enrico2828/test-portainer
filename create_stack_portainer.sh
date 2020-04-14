# test1, test2 or test3
PROJECT=$1
# gitcompose, gitswarm, or compose
MODE=$2
BASE_URL="http://localhost:9000"

getstackid()
{
  idresult=$(curl "${BASE_URL}/api/stacks" \
  -H "Authorization: Bearer ${jwtToken}" \
  -H "accept: application/json" \
  -H "Content-Type:application/json" | jq ".[] | select(.Name==\"${PROJECT}snapshot\") | .Id"  )
  echo $idresult
}

retrievetoken()
{
  jwtToken=$(curl -s -X POST -d "{ \"username\" : \"admin\", \"password\" : \"admin123\" }" "${BASE_URL}/api/auth" --header "Content-Type:application/json" | jq -r '.jwt' )
}

createstackgitcompose()
{

  echo "Creating stack from GIT with name ${PROJECT} and git URL ${GIT_URL}"
  curl -X POST "${BASE_URL}/api/stacks?type=2&method=repository&endpointId=1" \
    -H "Authorization: Bearer ${jwtToken}" \
    -H "accept: application/json" \
    -H "Content-Type:application/json" \
    --data-raw "
    {
    \"Name\": \"${PROJECT}snapshot\",
    \"RepositoryURL\": \"${GIT_URL}\",
    \"RepositoryReferenceName\": \"refs/heads/master\",
    \"ComposeFilePathInRepository\": \"compose/${PROJECT}/snapshot/docker-compose.yml\",
    \"RepositoryAuthentication\": false,
    \"Env\": []
     }
     "
}

createstackgitswarm()
{
  echo "Creating stack from GIT with name ${PROJECT} and git URL ${GIT_URL}"
  curl -X POST "${BASE_URL}/api/stacks?type=1&method=repository&endpointId=1" \
    -H "Authorization: Bearer ${jwtToken}" \
    -H "accept: application/json" \
    -H "Content-Type:application/json" \
    --data-raw "
    {
    \"Name\": \"${PROJECT}snapshot\",
    \"SwarmID\": \"lriv6yox3s5ea6i28ryd85u5r\",
    \"RepositoryURL\": \"${GIT_URL}\",
    \"RepositoryReferenceName\": \"refs/heads/master\",
    \"ComposeFilePathInRepository\": \"swarm/${PROJECT}/snapshot/docker-compose.yml\",
    \"RepositoryAuthentication\": false,
    \"Env\": []
     }
     "
}

createstackcompose()
{
  echo "Creating stack from COMPOSE with name ${PROJECT}"
  curl -X POST "${BASE_URL}/api/stacks?type=2&method=file&endpointId=1" \
    -H "Authorization: Bearer ${jwtToken}" \
    -H "accept: application/json" \
    -H "Content-Type: multipart/form-data" \
    -F "Name=${PROJECT}snapshot" \
    -F "EndpointID=1" \
    -F "file=@docker-compose.yml.template"
}


deletestack()
{
  local deleteid=$1
  echo "Deleting project $PROJECT with id $deleteid"
  curl -X DELETE "${BASE_URL}/api/stacks/$deleteid" \
    -H "Authorization: Bearer ${jwtToken}" \
    -H "accept: application/json" \
    -H "Content-Type:application/json"
}

isvalidid()
{
  local testid=$1
  re='^[0-9]+$'
  if ! [[ $testid =~ $re ]] ; then
     echo "Testing string $testid for being valid ID"
     echo "error: Something went wrong determining the project ID" >&2; exit 1
  fi
}

isemptyid()
{
  local testid=$1
  if [ -n "$testid" ]; then
    echo "Expected no stackid but got $testid"
    exit 1
  fi
}

# MAIN

# delete docker network
docker network rm "${PROJECT}snapshot_network"
docker network rm "${PROJECT}snapshot_network_compose"

# create docker network
docker network create -d overlay "${PROJECT}snapshot_network"
docker network create --attachable "${PROJECT}snapshot_network_compose"

PROJECT_NR=${PROJECT: -1}
GIT_URL="https://github.com/enrico2828/test-portainer${PROJECT_NR}.git"

for i in {1..50}
do
  echo "###### BATCH RUN $i ########"
  retrievetoken
  isemptyid $stackid
  if [ "$MODE" == "gitcompose" ]; then
     createstackgitcompose
  elif [ "$MODE" == "gitswarm" ]; then
     createstackgitswarm
  elif [ "$MODE" == "compose" ]; then
     createstackcompose
  else
    echo "Mode must be \'gitcompose, \'gitswarm\' or \'compose\', exiting"
    exit 1
  fi
  stackid=$(getstackid)
  isvalidid "$stackid"
  deletestack "$stackid"
  stackid=$(getstackid)
  isemptyid "$stackid"
done

# delete docker network
docker network rm "${PROJECT}snapshot_network"
docker network rm "${PROJECT}snapshot_network_compose"