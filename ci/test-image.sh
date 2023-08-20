#!/bin/bash

image_name=${1:-freebsd-testing}

if [[ -c /dev/kvm ]]; then
	HAVE_KVM=1
	echo "Have /dev/kvm"
fi

container_id=$(docker run ${HAVE_KVM:+--device /dev/kvm:/dev/kvm} \
	-d --rm \
	--health-cmd "curl -sSf localhost:7267/healthz" \
	--health-interval=1m \
	"${image_name}")

trap "docker stop $container_id > /dev/null" EXIT

while :; do
	health="$(docker inspect "$container_id" -f '{{ .State.Health.Status }}')"
	[[ $health == "healthy" ]] && break
	sleep 1
done

exit 0
