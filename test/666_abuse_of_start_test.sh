#! /bin/bash

. ./config.sh

start_suite "Abuse of 'start' operation"

weave_on $HOST1 launch
docker_bridge_ip=$(weave_on $HOST1 docker-bridge-ip)
proxy_start_container $HOST1 --name=c1

check_hostconfig() {
    docker_on $HOST1 attach $1 >/dev/null 2>&1 || true # Wait for container to exit
    assert "docker_on $HOST1 inspect -f '{{.HostConfig.Dns}} {{.HostConfig.NetworkMode}} {{.State.Running}} {{.State.ExitCode}}' $1" "[$3] $2 false 0"
}

# Start c2 with a sneaky HostConfig
proxy docker_on $HOST1 create --name=c2 $SMALL_IMAGE $CHECK_ETHWE_UP
proxy docker_api_on $HOST1 POST /containers/c2/start '{"NetworkMode": "container:c1"}'
check_hostconfig c2 container:c1

# Start c5 with a differently sneaky HostConfig
proxy docker_on $HOST1 create --name=c5 $SMALL_IMAGE $CHECK_ETHWE_UP
proxy docker_api_on $HOST1 POST /containers/c5/start '{"HostConfig": {"NetworkMode": "container:c1"}}'
check_hostconfig c5 container:c1

# Start c3 with HostConfig having empty binds and null dns/networking settings
proxy docker_on $HOST1 create --name=c3 -v /tmp:/hosttmp $SMALL_IMAGE $CHECK_ETHWE_UP
proxy docker_api_on $HOST1 POST /containers/c3/start '{"Binds":[],"Dns":null,"DnsSearch":null,"ExtraHosts":null,"VolumesFrom":null,"Devices":null,"NetworkMode":""}'
check_hostconfig c3 default $docker_bridge_ip

# Start c4 with an 'null' HostConfig and check this doesn't remove previous parameters
proxy docker_on $HOST1 create --name=c4 --memory-swap -1 $SMALL_IMAGE echo foo
assert_raises "proxy docker_api_on $HOST1 POST /containers/c4/start 'null'"
assert "docker_on $HOST1 inspect -f '{{.HostConfig.MemorySwap}}' c4" "-1"

# Start c4b with an empty HostConfig (generated by Docker 1.11.0-rc2)
proxy docker_on $HOST1 create --name=c4b --memory-swap -1 $SMALL_IMAGE echo foo
assert_raises "proxy docker_api_on $HOST1 POST /containers/c4b/start ''"
assert "docker_on $HOST1 inspect -f '{{.HostConfig.MemorySwap}}' c4b" "-1"

# Start c6 with both named and unnamed HostConfig
proxy docker_on $HOST1 create --name=c6 $SMALL_IMAGE $CHECK_ETHWE_UP
proxy docker_api_on $HOST1 POST /containers/c6/start '{"NetworkMode": "container:c2", "HostConfig": {"NetworkMode": "container:c1"}}'
check_hostconfig c6 container:c1

# Start c7 with an empty HostConfig and check this removes previous parameters, but still attaches to weave
proxy docker_on $HOST1 create --name=c7 --memory-swap -1 $SMALL_IMAGE $CHECK_ETHWE_UP
proxy docker_api_on $HOST1 POST /containers/c7/start '{"HostConfig":{}}'
assert "docker_on $HOST1 inspect -f '{{.HostConfig.MemorySwap}}' c7" "0"
check_hostconfig c7 default $docker_bridge_ip

# Start c8 in host network mode
proxy docker_on $HOST1 create --name=c8 $SMALL_IMAGE $CHECK_ETHWE_MISSING
proxy docker_api_on $HOST1 POST /containers/c8/start '{"HostConfig": {"NetworkMode": "host"}}'
check_hostconfig c8 host

# Start c10 in network of host container
proxy_start_container $HOST1 --name=c9 --net=host
proxy docker_on $HOST1 create --name=c10 $SMALL_IMAGE $CHECK_ETHWE_MISSING
proxy docker_api_on $HOST1 POST /containers/c10/start '{"HostConfig": {"NetworkMode": "container:c9"}}'
check_hostconfig c10 container:c9

end_suite
