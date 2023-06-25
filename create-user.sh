#!/bin/sh
set -ef

usage() {
	cat >&2 <<-EOF
	usage: ${0##*/} user pass
	EOF
	exit 1
}

[ $# -eq 2 ] || usage
[ -n "$1" ]  || usage
[ -n "$2" ]  || usage

missing() {
	cat >&2 <<-EOF
	missing: $1
	install: $2
	EOF
	exit 1
}

command -V htpasswd >/dev/null || missing htpasswd apache2-utils

# https://unix.stackexchange.com/a/419855
pass_hash=$(htpasswd -bnBC 10 "" "$2" | tr -d ':\n' | sed 's/$2y/$2a/')

while [ -z "${via}" ] ; do
	for t in 'podman' 'docker' 'sudo docker' ; do
		set +e
		c=$($t ps -q -f 'name=^quay-pgsql$' -f 'status=running')
		set -e
		if [ -n "$c" ] ; then
			via="$t"
			break 2
		fi
	done

	cat >&2 <<-EOF
	unable to determine container exec method.
	tried: podman, docker, sudo docker.
	EOF
	exit 1
done

do_psql() { ${via} exec -u postgres quay-pgsql psql -nS -d quay -c "$*" ; }

do_psql "INSERT INTO \"user\" (username, email, password_hash, uuid, verified, organization, robot, invoice_email, last_invalid_login) VALUES ('$1', '$1@localhost', '${pass_hash}', gen_random_uuid(), true, false, false, false, now());"
