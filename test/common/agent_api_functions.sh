#!/bin/bash

#  ============LICENSE_START===============================================
#  Copyright (C) 2020 Nordix Foundation. All rights reserved.
#  ========================================================================
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#  ============LICENSE_END=================================================
#

# This is a script that contains specific test functions for Policy Agent API

### API functiond towards the Policy Agent

. ../common/api_curl.sh

#########################################################
#### Test case functions A1 Policy management service
#########################################################

# This function compare the size, towards a target value, of a json array returned from <url> of the Policy Agent.
# This is done immediately by setting PASS or FAIL or wait up to and optional timeout before setting PASS or FAIL
# args: json:<url> <target-value> [<timeout-in-seconds]
# (Function for test scripts)
api_equal() {
    echo "(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	if [ $# -eq 2 ] || [ $# -eq 3 ]; then
		if [[ $1 == "json:"* ]]; then
			__var_test "Policy Agent" $LOCALHOST$POLICY_AGENT_EXTERNAL_PORT"/" $1 "=" $2 $3
			return 0
		fi
	fi

	((RES_CONF_FAIL++))
	__print_err "needs two or three args: json:<json-array-param> <target-value> [ timeout ]" $@
	return 1
}

# API Test function: GET /policies
# args: <response-code> <ric-id>|NORIC <service-id>|NOSERVICE <policy-ype-id>|NOTYPE [ NOID | [<policy-id> <ric-id> <service-id> EMPTY|<policy-type-id> <template-file>]*]
# (Function for test scripts)
api_get_policies() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))
	paramError=0
	if [ $# -lt 4 ]; then
		paramError=1
	elif [ $# -eq 5 ] && [ $5 != "NOID" ]; then
		paramError=1
	elif [ $# -gt 4 ] && [ $(($#%5)) -ne 4 ]; then
		paramError=1
	fi

    if [ $paramError -ne 0 ]; then
        __print_err "<response-code> <ric-id>|NORIC <service-id>|NOSERVICE <policy-type-id>|NOTYPE [ NOID | [<policy-id> <ric-id> <service-id> EMPTY|<policy-type-id> <template-file>]*]" $@
        return 1
    fi
	queryparams=""
	if [ $2 != "NORIC" ]; then
		queryparams="?ric="$2
	fi
	if [ $3 != "NOSERVICE" ]; then
		if [ -z $queryparams ]; then
			queryparams="?service="$3
		else
			queryparams=$queryparams"&service="$3
		fi
	fi
	if [ $4 != "NOTYPE" ]; then
		if [ -z $queryparams ]; then
			queryparams="?type="$4
		else
			queryparams=$queryparams"&type="$4
		fi
	fi

	query="/policies"$queryparams
    res="$(__do_curl_to_api PA GET $query)"
    status=${res:${#res}-3}

	if [ $status -ne $1 ]; then
		echo -e $RED" FAIL. Exepected status "$1", got "$status $ERED
		((RES_FAIL++))
		__check_stop_at_error
		return 1
	fi

	if [ $# -gt 4 ]; then
		if [ $# -eq 5 ] && [ $5 == "NOID" ]; then
			targetJson="["
		else
			body=${res:0:${#res}-3}
			targetJson="["
			arr=(${@:5})

			for ((i=0; i<$(($#-4)); i=i+5)); do

				if [ "$targetJson" != "[" ]; then
					targetJson=$targetJson","
				fi
				targetJson=$targetJson"{\"id\":\"$UUID${arr[$i]}\",\"lastModified\":\"????\",\"ric\":\"${arr[$i+1]}\",\"service\":\"${arr[$i+2]}\",\"type\":"
				if [ "${arr[$i+3]}" == "EMPTY" ]; then
					targetJson=$targetJson"\"\","
				else
					targetJson=$targetJson"\"${arr[$i+3]}\","
				fi
				file=".p.json"
				sed 's/XXX/'${arr[$i]}'/g' ${arr[$i+4]} > $file
				json=$(cat $file)
				targetJson=$targetJson"\"json\":"$json"}"
			done
		fi

		targetJson=$targetJson"]"
		echo "TARGET JSON: $targetJson" >> $HTTPLOG
		res=$(python3 ../common/compare_json.py "$targetJson" "$body")

		if [ $res -ne 0 ]; then
			echo -e $RED" FAIL, returned body not correct"$ERED
			((RES_FAIL++))
			__check_stop_at_error
			return 1
		fi
	fi

	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	return 0

}

# API Test function: GET /policy
#args: <response-code>  <policy-id> [<template-file>]
# (Function for test scripts)
api_get_policy() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))

    if [ $# -lt 2 ] || [ $# -gt 3 ]; then
        __print_err "<response-code>  <policy-id> [<template-file>] " $@
        return 1
    fi

	query="/policy?id=$UUID$2"
	res="$(__do_curl_to_api PA GET $query)"
	status=${res:${#res}-3}

	if [ $status -ne $1 ]; then
		echo -e $RED" FAIL. Exepected status "$1", got "$status $ERED
		((RES_FAIL++))
		__check_stop_at_error
		return 1
	fi

	if [ $# -eq 3 ]; then
		#Create a policy json to compare with
		body=${res:0:${#res}-3}
		file=".p.json"
		sed 's/XXX/'${2}'/g' $3 > $file
		targetJson=$(< $file)
		echo "TARGET JSON: $targetJson" >> $HTTPLOG
		res=$(python3 ../common/compare_json.py "$targetJson" "$body")
		if [ $res -ne 0 ]; then
			echo -e $RED" FAIL, returned body not correct"$ERED
			((RES_FAIL++))
			__check_stop_at_error
			return 1
		fi
	fi

	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	return 0
}

# API Test function: PUT /policy
# args: <response-code> <service-name> <ric-id> <policytype-id> <policy-id> <transient> <template-file> [<count>]
# (Function for test scripts)
api_put_policy() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))

    if [ $# -lt 7 ] || [ $# -gt 8 ]; then
        __print_err "<response-code> <service-name> <ric-id> <policytype-id> <policy-id> <transient>|NOTRANSIENT <template-file> [<count>]" $@
        return 1
    fi

	ric=$3
	count=0
	max=1

	if [ $# -eq 8 ]; then
		max=$8
	fi

	pid=$5
	file=$7

	while [ $count -lt $max ]; do
		query="/policy?id=$UUID$pid&ric=$ric&service=$2"

		if [ $4 != "NOTYPE" ]; then
			query=$query"&type=$4"
		fi

		if [ $6 != NOTRANSIENT ]; then
			query=$query"&transient=$6"
		fi

		file=".p.json"
		sed 's/XXX/'${pid}'/g' $7 > $file
    	res="$(__do_curl_to_api PA PUT $query $file)"
    	status=${res:${#res}-3}
		echo -ne " Executing "$count"("$max")${SAMELINE}"
		if [ $status -ne $1 ]; then
			echo " Executed "$count"?("$max")"
			echo -e $RED" FAIL. Exepected status "$1", got "$status $ERED
			((RES_FAIL++))
			__check_stop_at_error
			return 1
		fi

		let pid=$pid+1
		let count=$count+1
		echo -ne " Executed  "$count"("$max")${SAMELINE}"
	done
	echo ""

	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	return 0
}

# API Test function: PUT /policy to run in batch
# args: <response-code> <service-name> <ric-id> <policytype-id> <policy-id> <transient> <template-file> [<count>]
# (Function for test scripts)
api_put_policy_batch() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))

    if [ $# -lt 7 ] || [ $# -gt 8 ]; then
        __print_err "<response-code> <service-name> <ric-id> <policytype-id> <policy-id> <transient> <template-file> [<count>]" $@
        return 1
    fi

	ric=$3
	count=0
	max=1

	if [ $# -eq 8 ]; then
		max=$8
	fi

	pid=$5
	file=$7
	ARR=""
	while [ $count -lt $max ]; do
		query="/policy?id=$UUID$pid&ric=$ric&service=$2"

		if [ $4 != "NOTYPE" ]; then
			query=$query"&type=$4"
		fi

		if [ $6 != NOTRANSIENT ]; then
			query=$query"&transient=$6"
		fi

		file=".p.json"
		sed 's/XXX/'${pid}'/g' $7 > $file
    	res="$(__do_curl_to_api PA PUT_BATCH $query $file)"
    	status=${res:${#res}-3}
		echo -ne " Requesting(batch) "$count"("$max")${SAMELINE}"

		if [ $status -ne 200 ]; then
			echo " Requested(batch) "$count"?("$max")"
			echo -e $RED" FAIL. Exepected status 200 (in request), got "$status $ERED
			((RES_FAIL++))
			__check_stop_at_error
			return 1
		fi
		cid=${res:0:${#res}-3}
		ARR=$ARR" "$cid
		let pid=$pid+1
		let count=$count+1
		echo -ne " Requested(batch)  "$count"("$max")${SAMELINE}"
	done

	echo ""
	count=0
	for cid in $ARR; do

    	res="$(__do_curl_to_api PA RESPONSE $cid)"
    	status=${res:${#res}-3}
		echo -ne " Requesting(batch) "$count"("$max")${SAMELINE}"

		if [ $status -ne $1 ]; then
			echo " Requested(batch) "$count"?("$max")"
			echo -e $RED" FAIL. Exepected status "$1", got "$status $ERED
			((RES_FAIL++))
			__check_stop_at_error
			return 1
		fi

		let count=$count+1
		echo -ne " Requested(batch)  "$count"("$max")${SAMELINE}"
	done

	echo ""

	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	return 0
}

# API Test function: PUT /policy to run in i parallel for a number of rics
# args: <response-code> <service-name> <ric-id-base> <number-of-rics> <policytype-id> <policy-start-id> <transient> <template-file> <count-per-ric> <number-of-threads>
# (Function for test scripts)
api_put_policy_parallel() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))

    if [ $# -ne 10 ]; then
        __print_err " <response-code> <service-name> <ric-id-base> <number-of-rics> <policytype-id> <policy-start-id> <transient> <template-file> <count-per-ric> <number-of-threads>" $@
        return 1
    fi
	resp_code=$1; shift;
	serv=$1; shift
	ric_base=$1; shift;
	num_rics=$1; shift;
	type=$1; shift;
	start_id=$1; shift;
	transient=$1; shift;
	template=$1; shift;
	count=$1; shift;
	pids=$1; shift;

	if [ $ADAPTER != $RESTBASE ] && [ $ADAPTER != $RESTBASE_SECURE ]; then
		echo " Info - api_put_policy_parallel uses only the agent REST interface - create over dmaap in parallel is not supported"
		echo " Info - will execute over agent REST"
	fi

	if [ $serv == "NOSERVICE" ]; then
		serv=""
	fi
	query="/policy?service=$serv"

	if [ $type != "NOTYPE" ]; then
		query=$query"&type=$type"
	fi

	if [ $transient != NOTRANSIENT ]; then
	 	query=$query"&transient=$transient"
	fi

	urlbase=${ADAPTER}${query}

	for ((i=1; i<=$pids; i++))
	do
		uuid=$UUID
		if [ -z "$uuid" ]; then
			uuid="NOUUID"
		fi
		echo "" > ".pid${i}.res.txt"
		echo $resp_code $urlbase $ric_base $num_rics $uuid $start_id $template $count $pids $i > ".pid${i}.txt"
		echo $i
	done  | xargs -n 1 -I{} -P $pids bash -c '{
		arg=$(echo {})
		echo " Parallel process $arg started"
		tmp=$(< ".pid${arg}.txt")
		python3 ../common/create_policies_process.py $tmp > .pid${arg}.res.txt
	}'
	msg=""
	for ((i=1; i<=$pids; i++))
	do
		file=".pid${i}.res.txt"
		tmp=$(< $file)
		if [ -z "$tmp" ]; then
			echo " Process $i : unknown result (result file empty"
			msg="failed"
		else
			res=${tmp:0:1}
			if [ $res == "0" ]; then
				echo " Process $i : OK"
			else
				echo " Process $i : failed - "${tmp:1}
				msg="failed"
			fi
		fi
	done
	if [ -z $msg ]; then
		echo " $(($count*$num_rics)) policy request(s) executed"
		((RES_PASS++))
		echo -e $GREEN" PASS"$EGREEN
		return 0
	fi

	echo -e $RED" FAIL. One of more processes failed to execute" $ERED
	((RES_FAIL++))
	__check_stop_at_error
	return 1
}

# API Test function: DELETE /policy
# args: <response-code> <policy-id> [count]
# (Function for test scripts)
api_delete_policy() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))

    if [ $# -lt 2 ] || [ $# -gt 3 ]; then
        __print_err "<response-code> <policy-id> [count]" $@
        return 1
    fi

	count=0
	max=1

	if [ $# -eq 3 ]; then
		max=$3
	fi

	pid=$2

	while [ $count -lt $max ]; do
		query="/policy?id="$UUID$pid
		res="$(__do_curl_to_api PA DELETE $query)"
		status=${res:${#res}-3}
		echo -ne " Executing "$count"("$max")${SAMELINE}"

		if [ $status -ne $1 ]; then
			echo " Executed "$count"?("$max")"
			echo -e $RED" FAIL. Exepected status "$1", got "$status $ERED
			((RES_FAIL++))
			__check_stop_at_error
			return 1
		fi
		let pid=$pid+1
		let count=$count+1
		echo -ne " Executed  "$count"("$max")${SAMELINE}"
	done
	echo ""

	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	return 0
}

# API Test function: DELETE /policy to run in batch
# args: <response-code> <policy-id> [count]
# (Function for test scripts)
api_delete_policy_batch() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))

    if [ $# -lt 2 ] || [ $# -gt 3 ]; then
        __print_err "<response-code> <policy-id> [count]" $@
        return 1
    fi

	count=0
	max=1

	if [ $# -eq 3 ]; then
		max=$3
	fi

	pid=$2
	ARR=""
	while [ $count -lt $max ]; do
		query="/policy?id="$UUID$pid
		res="$(__do_curl_to_api PA DELETE_BATCH $query)"
		status=${res:${#res}-3}
		echo -ne " Requesting(batch) "$count"("$max")${SAMELINE}"

		if [ $status -ne 200 ]; then
			echo " Requested(batch) "$count"?("$max")"
			echo -e $RED" FAIL. Exepected status 200 (in request), got "$status $ERED
			((RES_FAIL++))
			__check_stop_at_error
			return 1
		fi
		cid=${res:0:${#res}-3}
		ARR=$ARR" "$cid
		let pid=$pid+1
		let count=$count+1
		echo -ne " Requested(batch)  "$count"("$max")${SAMELINE}"
	done

	echo ""

	count=0
	for cid in $ARR; do

    	res="$(__do_curl_to_api PA RESPONSE $cid)"
    	status=${res:${#res}-3}
		echo -ne " Deleted(batch) "$count"("$max")${SAMELINE}"

		if [ $status -ne $1 ]; then
			echo " Deleted(batch) "$count"?("$max")"
			echo -e $RED" FAIL. Exepected status "$1", got "$status $ERED
			((RES_FAIL++))
			__check_stop_at_error
			return 1
		fi

		let count=$count+1
		echo -ne " Deleted(batch)  "$count"("$max")${SAMELINE}"
	done

	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	return 0
}

# API Test function: DELETE /policy to run in i parallel for a number of rics
# args: <response-code> <number-of-rics> <policy-start-id> <count-per-ric> <number-of-threads>
# (Function for test scripts)
api_delete_policy_parallel() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))

    if [ $# -ne 5 ]; then
        __print_err " <response-code> <ric-id-base> <number-of-rics> <policy-start-id> <count-per-ric> <number-of-threads>" $@
        return 1
    fi
	resp_code=$1; shift;
	num_rics=$1; shift;
	start_id=$1; shift;
	count=$1; shift;
	pids=$1; shift;

	if [ $ADAPTER != $RESTBASE ] && [ $ADAPTER != $RESTBASE_SECURE ]; then
		echo " Info - api_delete_policy_parallel uses only the agent REST interface - create over dmaap in parallel is not supported"
		echo " Info - will execute over agent REST"
	fi

	query="/policy"

	urlbase=${ADAPTER}${query}

	for ((i=1; i<=$pids; i++))
	do
		uuid=$UUID
		if [ -z "$uuid" ]; then
			uuid="NOUUID"
		fi
		echo "" > ".pid${i}.del.res.txt"
		echo $resp_code $urlbase $num_rics $uuid $start_id $count $pids $i > ".pid${i}.del.txt"
		echo $i
	done  | xargs -n 1 -I{} -P $pids bash -c '{
		arg=$(echo {})
		echo " Parallel process $arg started"
		tmp=$(< ".pid${arg}.del.txt")
		python3 ../common/delete_policies_process.py $tmp > .pid${arg}.del.res.txt
	}'
	msg=""
	for ((i=1; i<=$pids; i++))
	do
		file=".pid${i}.del.res.txt"
		tmp=$(< $file)
		if [ -z "$tmp" ]; then
			echo " Process $i : unknown result (result file empty"
			msg="failed"
		else
			res=${tmp:0:1}
			if [ $res == "0" ]; then
				echo " Process $i : OK"
			else
				echo " Process $i : failed - "${tmp:1}
				msg="failed"
			fi
		fi
	done
	if [ -z $msg ]; then
		echo " $(($count*$num_rics)) policy request(s) executed"
		((RES_PASS++))
		echo -e $GREEN" PASS"$EGREEN
		return 0
	fi

	echo -e $RED" FAIL. One of more processes failed to execute" $ERED
	((RES_FAIL++))
	__check_stop_at_error
	return 1
}

# API Test function: GET /policy_ids
# args: <response-code> <ric-id>|NORIC <service-id>|NOSERVICE <type-id>|NOTYPE ([<policy-instance-id]*|NOID)
# (Function for test scripts)
api_get_policy_ids() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))

    if [ $# -lt 4 ]; then
		__print_err "<response-code> <ric-id>|NORIC <service-id>|NOSERVICE <type-id>|NOTYPE ([<policy-instance-id]*|NOID)" $@
		return 1
	fi

	queryparams=""

	if [ $2 != "NORIC" ]; then
		queryparams="?ric="$2
	fi

	if [ $3 != "NOSERVICE" ]; then
		if [ -z $queryparams ]; then
			queryparams="?service="$3
		else
			queryparams=$queryparams"&service="$3
		fi
	fi
	if [ $4 != "NOTYPE" ]; then
		if [ -z $queryparams ]; then
			queryparams="?type="$4
		else
			queryparams=$queryparams"&type="$4
		fi
	fi

	query="/policy_ids"$queryparams
    res="$(__do_curl_to_api PA GET $query)"
    status=${res:${#res}-3}

	if [ $status -ne $1 ]; then
		echo -e $RED" FAIL. Exepected status "$1", got "$status $ERED
		((RES_FAIL++))
		__check_stop_at_error
		return 1
	fi

	if [ $# -gt 4 ]; then
		body=${res:0:${#res}-3}
		targetJson="["

		for pid in ${@:5} ; do
			if [ "$targetJson" != "[" ]; then
				targetJson=$targetJson","
			fi
			if [ $pid != "NOID" ]; then
				targetJson=$targetJson"\"$UUID$pid\""
			fi
		done

		targetJson=$targetJson"]"
		echo "TARGET JSON: $targetJson" >> $HTTPLOG
		res=$(python3 ../common/compare_json.py "$targetJson" "$body")

		if [ $res -ne 0 ]; then
			echo -e $RED" FAIL, returned body not correct"$ERED
			((RES_FAIL++))
			__check_stop_at_error
			return 1
		fi
	fi

	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	return 0
}

# API Test function: GET /policy_schema
# args: <response-code> <policy-type-id> [<schema-file>]
# (Function for test scripts)
api_get_policy_schema() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))

    if [ $# -lt 2 ] || [ $# -gt 3 ]; then
        __print_err "<response-code> <policy-type-id> [<schema-file>]" $@
        return 1
    fi

	query="/policy_schema?id=$2"
	res="$(__do_curl_to_api PA GET $query)"
	status=${res:${#res}-3}

	if [ $status -ne $1 ]; then
		echo -e $RED" FAIL. Exepected status "$1", got "$status $ERED
		((RES_FAIL++))
		__check_stop_at_error
		return 1
	fi

	if [ $# -eq 3 ]; then

		body=${res:0:${#res}-3}

		targetJson=$(< $3)
		echo "TARGET JSON: $targetJson" >> $HTTPLOG
		res=$(python3 ../common/compare_json.py "$targetJson" "$body")

		if [ $res -ne 0 ]; then
			echo -e $RED" FAIL, returned body not correct"$ERED
			((RES_FAIL++))
			__check_stop_at_error
			return 1
		fi
	fi

	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	return 0
}

# API Test function: GET /policy_schemas
# args: <response-code>  <ric-id>|NORIC [<schema-file>|NOFILE]*
# (Function for test scripts)
api_get_policy_schemas() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))

    if [ $# -lt 2 ]; then
        __print_err "<response-code> <ric-id>|NORIC [<schema-file>|NOFILE]*" $@
        return 1
    fi

	query="/policy_schemas"
	if [ $2 != "NORIC" ]; then
		query=$query"?ric="$2
	fi

	res="$(__do_curl_to_api PA GET $query)"
	status=${res:${#res}-3}

	if [ $status -ne $1 ]; then
		echo -e $RED" FAIL. Exepected status "$1", got "$status $ERED
		((RES_FAIL++))
		__check_stop_at_error
		return 1
	fi

	if [ $# -gt 2 ]; then
		body=${res:0:${#res}-3}
		targetJson="["

		for file in ${@:3} ; do
			if [ "$targetJson" != "[" ]; then
				targetJson=$targetJson","
			fi
			if [ $file == "NOFILE" ]; then
				targetJson=$targetJson"{}"
			else
				targetJson=$targetJson$(< $file)
			fi
		done

		targetJson=$targetJson"]"
		echo "TARGET JSON: $targetJson" >> $HTTPLOG
		res=$(python3 ../common/compare_json.py "$targetJson" "$body")

		if [ $res -ne 0 ]; then
			echo -e $RED" FAIL, returned body not correct"$ERED
			((RES_FAIL++))
			__check_stop_at_error
			return 1
		fi
	fi

	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	return 0
}

# API Test function: GET /policy_status
# arg: <response-code> <policy-id> (STD <enforce-status> [<reason>])|(OSC <instance-status> <has-been-deleted>)
# (Function for test scripts)
api_get_policy_status() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))
    if [ $# -lt 4 ] || [ $# -gt 5 ]; then
		__print_err "<response-code> <policy-id> (STD <enforce-status> [<reason>])|(OSC <instance-status> <has-been-deleted>)" $@
		return 1
	fi

	targetJson=""

	if [ $3 == "STD" ]; then
		targetJson="{\"enforceStatus\":\"$4\""
		if [ $# -eq 5 ]; then
			targetJson=$targetJson",\"reason\":\"$5\""
		fi
		targetJson=$targetJson"}"
	elif [ $3 == "OSC" ]; then
		targetJson="{\"instance_status\":\"$4\""
		if [ $# -eq 5 ]; then
			targetJson=$targetJson",\"has_been_deleted\":\"$5\""
		fi
		targetJson=$targetJson",\"created_at\":\"????\"}"
	else
		__print_err "<response-code> (STD <enforce-status> [<reason>])|(OSC <instance-status> <has-been-deleted>)" $@
		return 1
	fi

	query="/policy_status?id="$UUID$2

	res="$(__do_curl_to_api PA GET $query)"
    status=${res:${#res}-3}

	if [ $status -ne $1 ]; then
		echo -e $RED" FAIL. Exepected status "$1", got "$status $ERED
		((RES_FAIL++))
		__check_stop_at_error
		return 1
	fi

	echo "TARGET JSON: $targetJson" >> $HTTPLOG
	body=${res:0:${#res}-3}
	res=$(python3 ../common/compare_json.py "$targetJson" "$body")

	if [ $res -ne 0 ]; then
		echo -e $RED" FAIL, returned body not correct"$ERED
		((RES_FAIL++))
		__check_stop_at_error
		return 1
	fi

	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	return 0
}

# API Test function: GET /policy_types
# args: <response-code> [<ric-id>|NORIC [<policy-type-id>|EMPTY [<policy-type-id>]*]]
# (Function for test scripts)
api_get_policy_types() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))

    if [ $# -lt 1 ]; then
		__print_err "<response-code> [<ric-id>|NORIC [<policy-type-id>|EMPTY [<policy-type-id>]*]]" $@
		return 1
	fi

	if [ $# -eq 1 ]; then
		query="/policy_types"
	elif [ $2 == "NORIC" ]; then
		query="/policy_types"
	else
		query="/policy_types?ric=$2"
	fi

    res="$(__do_curl_to_api PA GET $query)"
    status=${res:${#res}-3}

	if [ $status -ne $1 ]; then
		echo -e $RED" FAIL. Exepected status "$1", got "$status $ERED
		((RES_FAIL++))
		__check_stop_at_error
		return 1
	fi

	if [ $# -gt 2 ]; then
		body=${res:0:${#res}-3}
		targetJson="["

		for pid in ${@:3} ; do
			if [ "$targetJson" != "[" ]; then
				targetJson=$targetJson","
			fi
			if [ $pid == "EMPTY" ]; then
				pid=""
			fi
			targetJson=$targetJson"\"$pid\""
		done

		targetJson=$targetJson"]"
		echo "TARGET JSON: $targetJson" >> $HTTPLOG
		res=$(python3 ../common/compare_json.py "$targetJson" "$body")

		if [ $res -ne 0 ]; then
			echo -e $RED" FAIL, returned body not correct"$ERED
			((RES_FAIL++))
			__check_stop_at_error
			return 1
		fi
	fi

	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	return 0
}

#########################################################
#### Test case functions Health check
#########################################################

# API Test function: GET /status
# args: <response-code>
# (Function for test scripts)
api_get_status() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))
    if [ $# -ne 1 ]; then
		__print_err "<response-code>" $@
		return 1
	fi
    query="/status"
    res="$(__do_curl_to_api PA GET $query)"
    status=${res:${#res}-3}

	if [ $status -ne $1 ]; then
		echo -e $RED" FAIL. Exepected status "$1", got "$status $ERED
		((RES_FAIL++))
		__check_stop_at_error
		return 1
	fi

	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	return 0
}

#########################################################
#### Test case functions RIC Repository
#########################################################

# API Test function: GET /ric
# args: <reponse-code> <management-element-id> [<ric-id>]
# (Function for test scripts)
api_get_ric() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))
    if [ $# -lt 2 ] || [ $# -gt 3 ]; then
		__print_err "<reponse-code> <management-element-id> [<ric-id>]" $@
		return 1
	fi

	query="/ric?managedElementId="$2

    res="$(__do_curl_to_api PA GET $query)"
    status=${res:${#res}-3}

	if [ $status -ne $1 ]; then
		echo -e $RED" FAIL. Exepected status "$1", got "$status $ERED
		((RES_FAIL++))
		__check_stop_at_error
		return 1
	fi

	if [ $# -eq 3 ]; then
		body=${res:0:${#res}-3}
		if [ "$body" != "$3" ]; then
			echo -e $RED" FAIL, returned body not correct"$ERED
			((RES_FAIL++))
			__check_stop_at_error
			return 1
		fi
	fi

	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	return 0
}

# API test function: GET /rics
# args: <reponse-code> <policy-type-id>|NOTYPE [<space-separate-string-of-ricinfo>]
# example of <space-separate-string-of-ricinfo> = "ricsim_g1_1:me1_ricsim_g1_1,me2_ricsim_g1_1:1,2,4 ricsim_g1_1:me2_........."
# format of ric-info:  <ric-id>:<list-of-mes>:<list-of-policy-type-ids>
# (Function for test scripts)
api_get_rics() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))

    if [ $# -lt 2 ]; then
		__print_err "<reponse-code> <policy-type-id>|NOTYPE [<space-separate-string-of-ricinfo>]" $@
		return 1
	fi

	query="/rics"
	if [ $2 != "NOTYPE" ]; then
    	query="/rics?policyType="$2
	fi

    res="$(__do_curl_to_api PA GET $query)"
    status=${res:${#res}-3}

	if [ $status -ne $1 ]; then
		echo -e $RED" FAIL. Exepected status "$1", got "$status $ERED
		((RES_FAIL++))
		__check_stop_at_error
		return 1
	fi

	if [ $# -gt 2 ]; then
		body=${res:0:${#res}-3}
		res=$(python3 ../common/create_rics_json.py ".tmp_rics.json" "$3" )
		if [ $res -ne 0 ]; then
			echo -e $RED" FAIL, could not create target ric info json"$ERED
			((RES_FAIL++))
			__check_stop_at_error
			return 1
		fi

		targetJson=$(<.tmp_rics.json)
    	echo "TARGET JSON: $targetJson" >> $HTTPLOG
		res=$(python3 ../common/compare_json.py "$targetJson" "$body")
		if [ $res -ne 0 ]; then
			echo -e $RED" FAIL, returned body not correct"$ERED
			((RES_FAIL++))
			__check_stop_at_error
			return 1
		fi
	fi

	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	return 0
}

##################################################################
#### API Test case functions Service registry and supervision ####
##################################################################

# API test function: PUT /service
# args: <response-code>  <service-name> <keepalive-timeout> <callbackurl>
# (Function for test scripts)
api_put_service() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))
    if [ $# -ne 4 ]; then
        __print_err "<response-code>  <service-name> <keepalive-timeout> <callbackurl>" $@
        return 1
    fi

    query="/service"
    json="{\"callbackUrl\": \""$4"\",\"keepAliveIntervalSeconds\": \""$3"\",\"serviceName\": \""$2"\"}"
    file=".tmp.json"
	echo "$json" > $file

    res="$(__do_curl_to_api PA PUT $query $file)"
    status=${res:${#res}-3}

	if [ $status -ne $1 ]; then
		echo -e $RED" FAIL. Exepected status "$1", got "$status $ERED
		((RES_FAIL++))
		__check_stop_at_error
		return 1
	fi

	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	return 0
}

# API test function: GET /services
#args: <response-code> [ (<query-service-name> <target-service-name> <keepalive-timeout> <callbackurl>) | (NOSERVICE <target-service-name> <keepalive-timeout> <callbackurl> [<target-service-name> <keepalive-timeout> <callbackurl>]* )]
# (Function for test scripts)
api_get_services() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))
	#Number of accepted parameters: 1, 2, 4, 7, 10, 13,...
	paramError=1
	if [ $# -eq 1 ]; then
		paramError=0
	elif [ $# -eq 2 ] && [ $2 != "NOSERVICE" ]; then
		paramError=0
	elif [ $# -eq 5 ]; then
		paramError=0
	elif [ $# -gt 5 ] && [ $2 == "NOSERVICE" ]; then
		argLen=$(($#-2))
		if [ $(($argLen%3)) -eq 0 ]; then
			paramError=0
		fi
	fi

    if [ $paramError -ne 0 ]; then
		__print_err "<response-code> [ (<query-service-name> <target-service-name> <keepalive-timeout> <callbackurl>) | (NOSERVICE <target-service-name> <keepalive-timeout> <callbackurl> [<target-service-name> <keepalive-timeout> <callbackurl>]* )]" $@
		return 1
	fi

    query="/services"

    if [ $# -gt 1 ] && [ $2 != "NOSERVICE" ]; then
    	query="/services?name="$2
	fi

    res="$(__do_curl_to_api PA GET $query)"
    status=${res:${#res}-3}

	if [ $status -ne $1 ]; then
		echo -e $RED" FAIL. Exepected status "$1", got "$status $ERED
		((RES_FAIL++))
		__check_stop_at_error
		return 1
	fi

	if [ $# -gt 2 ]; then
		variableArgCount=$(($#-2))
		body=${res:0:${#res}-3}
    	targetJson="["
		shift; shift;
		cntr=0
		while [ $cntr -lt $variableArgCount ]; do
			servicename=$1; shift;
			timeout=$1; shift;
			callback=$1; shift;
			if [ $cntr -gt 0 ]; then
				targetJson=$targetJson","
			fi
			# timeSinceLastActivitySeconds value cannot be checked since value varies
			targetJson=$targetJson"{\"serviceName\": \""$servicename"\",\"keepAliveIntervalSeconds\": "$timeout",\"timeSinceLastActivitySeconds\":\"????\",\"callbackUrl\": \""$callback"\"}"
			let cntr=cntr+3
		done
		targetJson=$targetJson"]"
		echo "TARGET JSON: $targetJson" >> $HTTPLOG
		res=$(python3 ../common/compare_json.py "$targetJson" "$body")
		if [ $res -ne 0 ]; then
			echo -e $RED" FAIL, returned body not correct"$ERED
			((RES_FAIL++))
			__check_stop_at_error
			return 1
		fi
	fi

	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	return 0
}

# API test function: GET /services  (only checking service names)
# args: <response-code> [<service-name>]*"
# (Function for test scripts)
api_get_service_ids() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))

    if [ $# -lt 1 ]; then
		__print_err "<response-code> [<service-name>]*" $@
		return 1
	fi

    query="/services"
    res="$(__do_curl_to_api PA GET $query)"
    status=${res:${#res}-3}

	if [ $status -ne $1 ]; then
		echo -e $RED" FAIL. Exepected status "$1", got "$status $ERED
		((RES_FAIL++))
		__check_stop_at_error
		return 1
	fi

	body=${res:0:${#res}-3}
	targetJson="["
	for rapp in ${@:2} ; do
		if [ "$targetJson" != "[" ]; then
			targetJson=$targetJson","
		fi
		targetJson=$targetJson"{\"callbackUrl\":\"????\",\"keepAliveIntervalSeconds\":\"????\",\"serviceName\":\""$rapp"\",\"timeSinceLastActivitySeconds\":\"????\"}"
	done

	targetJson=$targetJson"]"
	echo "TARGET JSON: $targetJson" >> $HTTPLOG
	res=$(python3 ../common/compare_json.py "$targetJson" "$body")

	if [ $res -ne 0 ]; then
		echo -e $RED" FAIL, returned body not correct"$ERED
		((RES_FAIL++))
		__check_stop_at_error
		return 1
	fi

	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	return 0
}

# API test function: DELETE /services
# args: <response-code> <service-name>
# (Function for test scripts)
api_delete_services() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))

    if [ $# -ne 2 ]; then
		__print_err "<response-code> <service-name>" $@
		return 1
	fi

    query="/services?name="$2
    res="$(__do_curl_to_api PA DELETE $query)"
    status=${res:${#res}-3}

	if [ $status -ne $1 ]; then
		echo -e $RED" FAIL. Exepected status "$1", got "$status $ERED
		((RES_FAIL++))
		__check_stop_at_error
		return 1
	fi

	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	return 0
}

# API test function: PUT /services/keepalive
# args: <response-code> <service-name>
# (Function for test scripts)
api_put_services_keepalive() {
	echo -e $BOLD"TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ $EBOLD
    echo "TEST(${BASH_LINENO[0]}): ${FUNCNAME[0]}" $@ >> $HTTPLOG
	((RES_TEST++))

    if [ $# -ne 2 ]; then
		__print_err "<response-code> <service-name>" $@
		return 1
	fi

    query="/services/keepalive?name="$2
    res="$(__do_curl_to_api PA PUT $query)"
    status=${res:${#res}-3}

	if [ $status -ne $1 ]; then
		echo -e $RED" FAIL. Exepected status "$1", got "$status $ERED
		((RES_FAIL++))
		__check_stop_at_error
		return 1
	fi

	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	return 0
}

