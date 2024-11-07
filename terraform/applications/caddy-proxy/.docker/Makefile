caddy-v2-with-forwardproxy: Dockerfile
	docker build --platform linux/amd64 --tag caddy .
	docker create --name caddy-vol caddy
	docker cp caddy-vol:/caddy ../caddy
	docker rm -f caddy-vol
	docker rmi -f caddy
	