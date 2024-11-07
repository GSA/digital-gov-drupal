nginx-waf-with-modsecurity: Dockerfile
	docker build --platform linux/amd64 --tag nginx-modsecurity --build-arg=modsecurity_nginx_version=${modsecurity_nginx_version} --build-arg=nginx_version=${new_nginx_version} --build-arg=ubuntu_version=${ubuntu_version} .
	docker create --name nginx-vol nginx-modsecurity
	mkdir -p ../modules
	docker cp nginx-vol:/ngx_http_modsecurity_module.so ../modules
	docker rm -f nginx-vol
	docker rmi -f nginx-modsecurity
