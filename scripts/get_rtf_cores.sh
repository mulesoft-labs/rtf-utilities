#!/bin/bash

set +e

Help()
{
   # Display Help
   echo "Show RTF CPU cores used throughout your organization"
   echo
   echo "Syntax: ./get_rtf_cores.sh [-b|f]"
   echo "options:"
   echo "b     Bearer token (by default it will use your Anypoint username / password credentials specified in the file) [optional]"
   echo "f     Filename [optional]"
   echo "h     Display Help"
   echo "                    "
   echo "Example 1: ./get_rtf_cores.sh -b 1234-5345-2342-142 -f my-csv.csv"
}

GLOBAL_CPU_REQ=0
GLOBAL_CPU_LIM=0
PROD_CPU_REQ=0
PROD_CPU_LIM=0
SANDBOX_CPU_REQ=0
SANDBOX_CPU_LIM=0


getCoreFromBGENV() {
	ORG_ID=$1
	ENV_ID=$3
	ENV_TYPE=$7
	DEPLOYMENTS=$(curl -sS "https://anypoint.mulesoft.com/amc/application-manager/api/v2/organizations/${ORG_ID}/environments/${ENV_ID}/deployments" \
   -H "Authorization: Bearer $TOKEN")
	IDS=($(echo $DEPLOYMENTS | jq -r --arg APP_NAME "$APP_NAME" '.items | .[]? | select((.target.provider == "MC" and .application.status == "RUNNING")) | .id '))
	RTF_IDS=($(echo $DEPLOYMENTS | jq -r --arg APP_NAME "$APP_NAME" '.items | .[]? | select((.target.provider == "MC" and .application.status == "RUNNING")) | .target.targetId'))

	CPU_REQ_SUM=0
	CPU_LIM_SUM=0

	echo "Org: $2 ($1)"
	echo "Env ID: $4 ($3)"

	for indexA in ${!IDS[@]};
	do
		APP_DEPLOYMENT=$(curl -sS "https://anypoint.mulesoft.com/amc/application-manager/api/v2/organizations/${ORG_ID}/environments/${ENV_ID}/deployments/${IDS[$indexA]}" \
	  			-H "Authorization: Bearer $TOKEN")
		TOTAL=$(echo $APP_DEPLOYMENT | jq -r '.total')
		if [ $TOTAL == "0" ];
		then
			break
		fi
		APP_NAME=$(echo $APP_DEPLOYMENT | jq -r '.name')
		APP_REQ_CPU=$(echo $APP_DEPLOYMENT | jq -r '.target.deploymentSettings.resources.cpu.reserved')
		APP_LIM_CPU=$(echo $APP_DEPLOYMENT | jq -r '.target.deploymentSettings.resources.cpu.limit')
		REPLICAS=$(echo $APP_DEPLOYMENT | jq -r '.target.replicas')

		cpu_req_digits=${APP_REQ_CPU//[!0-9]/}*$REPLICAS
		cpu_lim_digits=${APP_LIM_CPU//[!0-9]/}*$REPLICAS

		CPU_REQ_SUM=$(( $CPU_REQ_SUM + $cpu_req_digits))
		CPU_LIM_SUM=$(( $CPU_LIM_SUM + $cpu_lim_digits))

		GLOBAL_CPU_REQ=$(($GLOBAL_CPU_REQ + $CPU_REQ_SUM))
		GLOBAL_CPU_LIM=$(($GLOBAL_CPU_LIM + $CPU_LIM_SUM))

		if [ $ENV_TYPE == "production" ];
		then
			PROD_CPU_REQ=$(($PROD_CPU_REQ + $CPU_REQ_SUM))
			PROD_CPU_LIM=$(($PROD_CPU_LIM + $CPU_LIM_SUM))
		else
			SANDBOX_CPU_REQ=$(($SANDBOX_CPU_REQ + $CPU_REQ_SUM))
			SANDBOX_CPU_LIM=$(($SANDBOX_CPU_LIM + $CPU_LIM_SUM))
		fi

		a=`echo "scale=2 ; $CPU_REQ_SUM / 1000" | bc` && b=`echo "scale=2; $CPU_LIM_SUM/1000" | bc` && echo "App name: $APP_NAME, CPU Limit: $b, CPU Requests: $a" 
		if [ -z "$FILENAME" ]
		then
			:		
		else
			a=`echo "scale=2 ; $CPU_REQ_SUM / 1000" | bc` && b=`echo "scale=2; $CPU_LIM_SUM/1000" | bc` && echo "$2,$1,$6,$5,$4,$3,$7,$APP_NAME,$b,$a,${RTF_IDS[$indexA]}" >> "$FILENAME"			
		fi

	done
	
	a=`echo "scale=2 ; $CPU_REQ_SUM / 1000" | bc` && b=`echo "scale=2; $CPU_LIM_SUM/1000" | bc` && echo "Total Request CPU: $a, Total Limit CPU: $b"
	echo ""
}

while getopts ":b:f:" option; do
    case $option in
        b)
          BEARER_TOKEN=$OPTARG;;
        f)
          FILENAME=$OPTARG;;
        h)
          Help;;
        \?) # Invalid option
         Help
         exit 1
         ;;
    esac
done

# Update with your own values
USERNAME=""
PASSWORD=""

if [[ ! -z "$BEARER_TOKEN" ]]
then 
	TOKEN=$BEARER_TOKEN
else
	TOKEN=$(curl -sS -X POST https://anypoint.mulesoft.com/accounts/login -H 'Content-Type: application/json' \
  -d '{"username": "'$USERNAME'","password": "'$PASSWORD'"}' | jq -r '.access_token')
fi

if [ -z "$FILENAME" ]
  then
  	echo "No CSV file specified"
  else
  	echo "Writing to $FILENAME"
    echo "Org name, Org ID, Parent Org name, Parent Org ID, Environment name, Environment ID, Environment type, App name, CPU Limit, Reserved CPU, RTF ID" > $FILENAME
fi 

ORG_INFO=$(curl -sS -X GET https://anypoint.mulesoft.com/accounts/api/me -H "Authorization: Bearer $TOKEN")

ORG_IDS=($(echo $ORG_INFO | jq -r '.user.memberOfOrganizations[].id'))

ORG_NAMES=($(echo $ORG_INFO | jq -r '.user.memberOfOrganizations[].name'))

PARENT_IDS=($(echo $ORG_INFO | jq -r '.user.memberOfOrganizations[].parentId'))

PARENT_NAMES=($(echo $ORG_INFO | jq -r '.user.memberOfOrganizations[].parentName'))


for index in ${!ORG_IDS[@]};
do 
	ENV_INFO=$(curl -sS -X GET "https://anypoint.mulesoft.com/accounts/api/organizations/${ORG_IDS[$index]}/environments" -H "Authorization: Bearer $TOKEN")
	
	ENV_IDS=($(echo $ENV_INFO | jq -r '.data[].id'))
	ENV_NAMES=($(echo $ENV_INFO | jq -r '.data[].name'))
	ENV_TYPES=($(echo $ENV_INFO | jq -r '.data[].type'))
	
	for index2 in ${!ENV_IDS[@]}; 
	do
		getCoreFromBGENV ${ORG_IDS[$index]} ${ORG_NAMES[$index]} ${ENV_IDS[$index2]} ${ENV_NAMES[$index2]} ${PARENT_IDS[$index]} ${PARENT_NAMES[$index]} ${ENV_TYPES[$index2]};
	done
done

echo -n "Production CPU requests: "
echo "scale = 2 ; ${PROD_CPU_REQ} / 1000" | bc
echo -n "Production CPU limit: "
echo "scale = 2 ; ${PROD_CPU_LIM} / 1000" | bc
echo -n "Sandbox CPU requests: "
echo "scale = 2 ; ${SANDBOX_CPU_REQ} / 1000" | bc
echo -n "Sandbox CPU limit: "
echo "scale = 2 ; ${SANDBOX_CPU_LIM} / 1000" | bc
